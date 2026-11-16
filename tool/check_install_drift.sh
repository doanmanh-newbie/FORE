#!/usr/bin/env bash
set -euo pipefail

ROOT="${FORE_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DB="$ROOT/database"
SUFFIX="$$"
SRC_DB="fore_src_${SUFFIX}"
REB_DB="fore_reb_${SUFFIX}"
TMP="$(mktemp -d "$ROOT/.sql-module-drift.XXXXXX")"
CREATED=()

cleanup() {
  for name in "${CREATED[@]}"; do dropdb --if-exists "$name" >/dev/null 2>&1 || true; done
  case "$TMP" in
    "$ROOT"/.sql-module-drift.*) rm -rf -- "$TMP" ;;
    *) echo "Refusing to remove unexpected temporary path: $TMP" >&2 ;;
  esac
}
trap cleanup EXIT

for command in psql createdb dropdb pg_dump diff; do
  command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 2; }
done

make_db() {
  local name="$1"
  createdb "$name"
  CREATED+=("$name")
  psql -X -v ON_ERROR_STOP=1 -d "$name" -f "$DB/tests/00_supabase_stub.sql" >/dev/null
}

apply() { psql -X -v ON_ERROR_STOP=1 -d "$1" -f "$2" >/dev/null; }

modules=(01_foundation.sql 02_operations_reconciliation.sql \
  03_read_apis.sql 04_membership_sessions.sql \
  05_menu_management.sql 06_menu_options.sql \
  07_inventory.sql 08_settings.sql)

make_db "$SRC_DB"
for source in "${modules[@]}"; do
  apply "$SRC_DB" "$DB/$source"
done

make_db "$REB_DB"
apply "$REB_DB" "$DB/dev/rebuild_test_database.sql"

dump_schema() {
  local name="$1" out="$2"
  pg_dump --schema-only --no-owner \
    --schema=public --schema=auth --schema=extensions \
    --dbname="$name" > "$out"
  # Newer pg_dump versions emit a random psql guard token per output.
  sed -i '/^\\restrict /d; /^\\unrestrict /d' "$out"
}

dump_schema "$SRC_DB" "$TMP/modules"
dump_schema "$REB_DB" "$TMP/rebuild"

diff -u "$TMP/modules" "$TMP/rebuild"
echo 'SQL MODULE DRIFT: PASS (tables, columns, constraints, indexes, RLS/policies, grants, triggers and functions match across the eight source modules and generated test rebuild)'
