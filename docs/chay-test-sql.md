# Chạy test SQL (database/tests) không cần psql/Docker

Máy dev không có `psql` và Docker không chạy, nên test SQL chạy trên **PGlite** (Postgres 17 biên dịch
sang WASM, chạy trong Node, có `pgcrypto`). Không kết nối tới Supabase hay Postgres nào: database nằm
hoàn toàn trong bộ nhớ và mất khi lệnh chạy xong.

```powershell
cd tool/sql_tests; npm install
```

```powershell
node tool/sql_tests/run.mjs
```

- `node tool/sql_tests/run.mjs 91 92`: chỉ chạy các file có tên bắt đầu bằng `91`, `92`.
- `--verbose`: in thêm mọi NOTICE và đoạn SQL bị lỗi.
- `--shared`: chạy nối tiếp mọi file trên **cùng một** database, giống lệnh psql lần lượt trên `fore_test`.
  Mặc định mỗi file chạy trên một bản sao mới của database vừa cài schema.

Runner cài `database/tests/00_supabase_stub.sql` rồi tới `database/dev/rebuild_test_database.sql`
(file gộp từ `database/0*.sql` qua `tool/build_install.sh`; sau khi sửa module SQL thì chạy lại script đó).
Sau đó runner chạy từng file `database/tests/*.sql` và dừng ở lỗi đầu tiên của mỗi file, như
`psql -v ON_ERROR_STOP=1`. Lệnh thoát với mã khác 0 nếu có file lỗi.

## Runner khác psql ở đâu

- Runner tự tách từng câu lệnh (hiểu `$tag$`, chuỗi, comment) và bỏ các dòng lệnh meta của psql (`\set ...`).
- PGlite không trả được `session authorization` về như cũ. Vì vậy `set local session authorization X` được đổi
  thành `set local role X`, còn `reset session authorization` thành `reset role`. GRANT và RLS của role vẫn
  được kiểm tra như thường.
- Do đổi sang `set role`, `session_user` không còn đổi theo. Các hàm đối soát trong `02_operations_reconciliation.sql`
  cho quản trị database đi tắt khi `session_user in ('postgres','supabase_admin')`. Vì thế mỗi kết nối test
  chạy `set session authorization fore_tester` (một superuser không tên `postgres`) một lần từ đầu. Nếu thiếu
  bước này, mọi kiểm tra `OWNER_ONLY` của các hàm đó đều bị bỏ qua. Đây chính là lý do test 10, 20, 30, 40
  từng bị coi là hỏng.
- `51_concurrency.sh` bị bỏ qua, vì nó cần psql và hai kết nối song song. PGlite chỉ có một kết nối.
  Muốn chạy test này thì phải dùng một Postgres TEST thật.
