#!/bin/bash
# Test race: máy A mở bill (giữ giao dịch chưa commit) trong lúc máy B đóng ca.
# Mong đợi: close_shift CHỜ máy A; sau khi A commit thì thấy bill đang mở và báo OPEN_BILLS_REMAIN
# (không có bill mở nằm trong ca đã đóng). Chạy sau khi cài các nhóm SQL 01–04 và tests/50.
# Lệnh: bash tests/51_concurrency.sh
# Dùng biến PGHOST/PGUSER/PGDATABASE như psql thường. KHÔNG chạy trên Supabase thật.
set -u
DB=${PGDATABASE:-fore_test}
OWNER=00000000-0000-0000-0000-0000000000a1
psql -q -d $DB -v ON_ERROR_STOP=1 <<SQL >/dev/null
truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts restart identity cascade;
delete from auth.users;
insert into auth.users (id, email) values ('$OWNER', 'owner@test');
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán test');
insert into staff (shop_id, auth_user_id, full_name, role) values ('00000000-0000-0000-0000-0000000000f1', '$OWNER', 'Chủ', 'owner');
select set_config('request.jwt.claim.sub', '$OWNER', false);
insert into ingredients (name, unit, importance) values ('Sữa', 'ml', 'important');
insert into areas (name) values ('Tầng 1');
insert into dining_tables (area_id, name) select id, 'Bàn 1' from areas;
set session authorization authenticated; select set_config('request.jwt.claim.sub','$OWNER',false);
select open_shift(0);
select submit_stock_count(id,'open',0) from ingredients where active;
SQL
# Máy A: mở bill rồi giữ giao dịch 4 giây
( psql -q -d $DB <<SQL
begin; set local session authorization authenticated; select set_config('request.jwt.claim.sub','$OWNER',true);
select open_bill((select id from dining_tables limit 1),'dine_in',1) is not null as a_opened;
select pg_sleep(4);
commit;
SQL
) > /tmp/race_a.txt 2>&1 &
sleep 1
START=$(date +%s)
psql -q -d $DB <<SQL > /tmp/race_b.txt 2>&1
set session authorization authenticated; select set_config('request.jwt.claim.sub','$OWNER',false);
select submit_stock_count(id,'close',0) from ingredients where active;
select close_shift(0);
SQL
END=$(date +%s); wait
WAITED=$((END-START))
BILLS=$(psql -t -A -d $DB -c "select count(*) from bills b join shifts s on s.id=b.shift_id where b.status='open' and s.status='closed'")
echo "B cho $WAITED giay; bill mo nam trong ca da dong: $BILLS"
if grep -q OPEN_BILLS_REMAIN /tmp/race_b.txt && [ "$WAITED" -ge 2 ] && [ "$BILLS" = "0" ]; then
  echo "CONCURRENCY: DUNG (close_shift cho, roi tu choi vi con bill mo)"
else echo "CONCURRENCY: SAI"; cat /tmp/race_a.txt /tmp/race_b.txt; exit 1; fi
