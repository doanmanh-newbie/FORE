// Chạy các bài test SQL trong database/tests trên PGlite (Postgres chạy bằng WASM, không cần psql/Docker).
//
//   cd tool/sql_tests && npm install        (lần đầu)
//   node run.mjs                            (chạy mọi database/tests/*.sql)
//   node run.mjs 91 92                      (chỉ chạy file có tên bắt đầu bằng 91, 92)
//   node run.mjs --verbose 91               (in cả NOTICE của từng bài)
//   node run.mjs --shared                   (mọi file nối tiếp trên CÙNG một database, như psql trên fore_test)
//
// Mặc định mỗi file test chạy trên một bản sao MỚI của database đã cài schema (00_supabase_stub.sql rồi
// database/dev/rebuild_test_database.sql), nên thứ tự và dữ liệu của bài này không ảnh hưởng bài khác.
// Mô phỏng psql -v ON_ERROR_STOP=1: tách từng câu lệnh, dừng ở lỗi đầu tiên của file.
// Khác psql cần bù lại:
//   * bỏ các dòng lệnh meta của psql (\set ...);
//   * PGlite không trả được "session authorization" về như cũ, nên đổi
//     "set local session authorization X" -> "set local role X" và "reset session authorization" -> "reset role"
//     (vẫn kiểm tra đúng quyền GRANT/RLS của role X).
// Chỉ chạy trên PGlite trong bộ nhớ; không kết nối tới Supabase hay Postgres nào.
import { PGlite } from '@electric-sql/pglite';
import { pgcrypto } from '@electric-sql/pglite/contrib/pgcrypto';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..', '..');
const testsDir = join(repo, 'database', 'tests');
const stubFile = join(testsDir, '00_supabase_stub.sql');
const schemaFile = join(repo, 'database', 'dev', 'rebuild_test_database.sql');
// Vì đổi sang "set local role", session_user luôn là người đăng nhập ban đầu. Vài hàm đối soát (02) cho
// quản trị database đi tắt khi session_user in ('postgres', 'supabase_admin'); nếu chạy bằng postgres thì
// mọi kiểm tra OWNER_ONLY của các hàm đó đều bị bỏ qua. Nên test chạy bằng một superuser tên khác —
// giống psql thật, nơi "set session authorization authenticated" làm session_user = authenticated.
const TEST_USER = 'fore_tester';

// Tách script thành từng câu lệnh, tôn trọng chuỗi '...', E'...', "...", $tag$...$tag$ và comment.
export function splitSql(source) {
  // lệnh meta của psql (\set ON_ERROR_STOP on ...) đứng riêng một dòng: thay bằng dòng trống để giữ số dòng
  const text = source.replace(/^[ \t]*\\.*$/gm, '');
  const out = [];
  let start = 0;
  let i = 0;
  let line = 1;
  let startLine = 1;
  const n = text.length;
  const push = (end) => {
    const sql = text.slice(start, end).trim();
    const onlyComments = sql.split('\n').every((l) => l.trim() === '' || l.trim().startsWith('--'));
    if (sql && !onlyComments) out.push({ sql, line: startLine });
  };
  let atStmtStart = true;
  while (i < n) {
    const c = text[i];
    if (c === '\n') { line++; i++; continue; }
    if (atStmtStart && /\s/.test(c)) { i++; continue; }
    if (atStmtStart) { start = i; startLine = line; atStmtStart = false; }
    if (c === '-' && text[i + 1] === '-') {
      while (i < n && text[i] !== '\n') i++;
      continue;
    }
    if (c === '/' && text[i + 1] === '*') {
      let depth = 1; i += 2;
      while (i < n && depth > 0) {
        if (text[i] === '\n') line++;
        if (text[i] === '/' && text[i + 1] === '*') { depth++; i += 2; continue; }
        if (text[i] === '*' && text[i + 1] === '/') { depth--; i += 2; continue; }
        i++;
      }
      continue;
    }
    if (c === "'") {
      const escapes = (text[i - 1] === 'E' || text[i - 1] === 'e') && !/\w/.test(text[i - 2] ?? '');
      i++;
      while (i < n) {
        if (text[i] === '\n') line++;
        if (escapes && text[i] === '\\') { i += 2; continue; }
        if (text[i] === "'") { if (text[i + 1] === "'") { i += 2; continue; } break; }
        i++;
      }
      i++;
      continue;
    }
    if (c === '"') {
      i++;
      while (i < n && text[i] !== '"') { if (text[i] === '\n') line++; i++; }
      i++;
      continue;
    }
    if (c === '$' && !/\w/.test(text[i - 1] ?? '')) {
      const m = /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/.exec(text.slice(i, i + 64));
      if (m) {
        const tag = m[0];
        const end = text.indexOf(tag, i + tag.length);
        const stop = end < 0 ? n : end + tag.length;
        for (let k = i; k < stop; k++) if (text[k] === '\n') line++;
        i = stop;
        continue;
      }
    }
    if (c === ';') {
      push(i + 1);
      i++;
      atStmtStart = true;
      continue;
    }
    i++;
  }
  if (!atStmtStart) push(n);
  return out;
}

function adapt(sql) {
  return sql
    .replace(/\bset\s+local\s+session\s+authorization\b/gi, 'set local role')
    .replace(/\breset\s+session\s+authorization\b/gi, 'reset role')
    .replace(/\bset\s+session\s+authorization\b/gi, 'set role');
}

async function runScript(db, file, { verbose = false } = {}) {
  const notices = [];
  const onNotice = (msg) => notices.push(msg.message);
  const stmts = splitSql(readFileSync(file, 'utf8'));
  for (const { sql, line } of stmts) {
    try {
      await db.exec(adapt(sql), { onNotice });
    } catch (e) {
      // giống psql: lỗi trong giao dịch thì bỏ giao dịch đó đi
      try { await db.exec('rollback'); } catch { /* không có giao dịch */ }
      return { ok: false, line, sql, error: e.message, detail: e.detail, where: e.where, notices };
    }
  }
  if (verbose) for (const m of notices) console.log('    NOTICE: ' + m);
  return { ok: true, notices };
}

async function buildBase() {
  const db = await PGlite.create({ extensions: { pgcrypto } });
  for (const f of [stubFile, schemaFile]) {
    const r = await runScript(db, f);
    if (!r.ok) throw new Error(`Cài schema lỗi ở ${relative(repo, f)}:${r.line}: ${r.error}\n${r.sql.slice(0, 400)}`);
  }
  // Role chạy test: superuser nhưng KHÔNG tên postgres (xem ghi chú TEST_USER ở trên).
  await db.exec(`create role ${TEST_USER} superuser login`);
  const dump = await db.dumpDataDir('none');
  await db.close();
  return dump;
}

async function main() {
  const args = process.argv.slice(2);
  const verbose = args.includes('--verbose');
  const filters = args.filter((a) => !a.startsWith('--'));
  const files = readdirSync(testsDir)
    .filter((f) => f.endsWith('.sql') && f !== '00_supabase_stub.sql')
    .filter((f) => filters.length === 0 || filters.some((p) => f.startsWith(p)))
    .sort();
  const skipped = filters.length ? [] : readdirSync(testsDir).filter((f) => f.endsWith('.sh'));

  const t0 = Date.now();
  const base = await buildBase();
  console.log(`Đã cài schema trên PGlite (${((Date.now() - t0) / 1000).toFixed(1)}s).`);

  const open = async () => {
    const db = await PGlite.create({ loadDataDir: base, extensions: { pgcrypto } });
    // PGlite không trả session authorization về được, nên đặt MỘT LẦN cho cả kết nối: session_user = TEST_USER.
    await db.exec(`set session authorization ${TEST_USER}`);
    return db;
  };
  // --shared: chạy nối tiếp mọi file trên CÙNG một database như khi chạy psql lần lượt trên fore_test
  const shared = args.includes('--shared') ? await open() : null;

  let failed = 0;
  for (const f of files) {
    const t = Date.now();
    const db = shared ?? (await open());
    const r = await runScript(db, join(testsDir, f), { verbose });
    if (!shared) await db.close();
    const secs = ((Date.now() - t) / 1000).toFixed(1);
    if (r.ok) {
      const last = r.notices.at(-1);
      console.log(`PASS ${f} (${secs}s)${last ? ' — ' + last : ''}`);
    } else {
      failed++;
      console.log(`FAIL ${f}:${r.line} (${secs}s)\n  ${r.error}`);
      if (r.detail) console.log(`  DETAIL: ${r.detail}`);
      if (r.where) console.log(`  WHERE: ${r.where.split('\n').slice(0, 3).join(' | ')}`);
      if (verbose) console.log('  SQL: ' + r.sql.slice(0, 600).replace(/\n/g, '\n       '));
    }
  }
  if (shared) await shared.close();
  for (const f of skipped) console.log(`SKIP ${f} (cần 2 kết nối song song + psql; PGlite chỉ có 1 kết nối)`);
  console.log(`\n${files.length - failed}/${files.length} file qua.`);
  process.exit(failed ? 1 : 0);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  main().catch((e) => { console.error(e); process.exit(2); });
}
