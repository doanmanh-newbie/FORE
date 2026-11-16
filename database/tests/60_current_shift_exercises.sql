-- Kiểm thử current_shift() (010). Chạy sau tests/00_supabase_stub.sql và 001..010:
--   psql -d fore_test -v ON_ERROR_STOP=1 -f tests/60_current_shift_exercises.sql
-- Đúng hết sẽ in "CURRENT SHIFT: TAT CA DEU DUNG". KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
\set ON_ERROR_STOP on

truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts restart identity cascade;
delete from auth.users;
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán test');

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test'),
  ('00000000-0000-0000-0000-0000000000c1', 'nguoila@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'An', 'staff');
-- (đặt người đăng nhập mặc định = chủ để giá trị mặc định shop_id của các lệnh nạp dữ liệu bên dưới trỏ đúng quán)
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);

do $test$
declare
  owner_u text := '00000000-0000-0000-0000-0000000000a1';
  nv_u    text := '00000000-0000-0000-0000-0000000000b1';
  out_u   text := '00000000-0000-0000-0000-0000000000c1';
  n int; v_name text; msg text; v_shift uuid; v_cols int;
begin
  -- 1. Chưa có ca: nhân viên gọi được, trả 0 dòng
  perform set_config('request.jwt.claim.sub', nv_u, true); set local session authorization authenticated;
  select count(*) into n from current_shift();
  if n <> 0 then raise exception 'Chua co ca ma tra % dong', n; end if;
  reset session authorization;

  -- 2. Chủ mở ca; nhân viên (không phải chủ) thấy tên người mở
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  v_shift := open_shift(500000);
  reset session authorization;

  perform set_config('request.jwt.claim.sub', nv_u, true); set local session authorization authenticated;
  select count(*), max(opened_by_name) into n, v_name from current_shift();
  if n <> 1 or v_name <> 'Chủ' then raise exception 'Mong 1 dong, ten Chu; nhan n=%, ten=%', n, v_name; end if;
  if (select shift_id from current_shift()) <> v_shift then raise exception 'Sai ma ca'; end if;

  -- 3. Hàm không lộ số tiền đầu ca (đúng 5 cột: không có tiền)
  select count(*) into v_cols from information_schema.parameters
   where specific_name like 'current_shift%' and parameter_mode = 'OUT';
  if v_cols <> 5 then raise exception 'current_shift phai tra dung 5 cot, nhan %', v_cols; end if;

  -- 3b. nhân viên không phải người mở ca: opened_by_me = false; chưa có bill: 0
  if (select opened_by_me from current_shift()) is not false then raise exception 'NV khong phai nguoi mo ca ma opened_by_me <> false'; end if;
  if (select open_bills from current_shift()) <> 0 then raise exception 'Chua co bill ma open_bills <> 0'; end if;

  -- 3c. chủ (người mở ca) thấy opened_by_me = true
  reset session authorization;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  if (select opened_by_me from current_shift()) is not true then raise exception 'Nguoi mo ca ma opened_by_me <> true'; end if;
  reset session authorization;
  perform set_config('request.jwt.claim.sub', nv_u, true); set local session authorization authenticated;

  -- 4. Nhân viên cũng "vào ca" được: người mở thứ hai bị SHIFT_ALREADY_OPEN (app dùng current_shift để chuyển thành Vào ca)
  begin perform open_shift(0); raise exception 'LE RA PHAI LOI (mo ca lan 2)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'SHIFT_ALREADY_OPEN' then raise exception 'mong SHIFT_ALREADY_OPEN, nhan: %', msg; end if; end;
  reset session authorization;

  -- 5. Người không phải nhân viên: NOT_STAFF
  perform set_config('request.jwt.claim.sub', out_u, true); set local session authorization authenticated;
  begin perform * from current_shift(); raise exception 'LE RA PHAI LOI (khong phai nhan vien)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'NOT_STAFF' then raise exception 'mong NOT_STAFF, nhan: %', msg; end if; end;
  reset session authorization;

  -- 6. anon không gọi được
  set local session authorization anon;
  begin perform * from current_shift(); raise exception 'LE RA PHAI LOI (anon)';
  exception when insufficient_privilege then null; end;
  reset session authorization;

  raise notice 'CURRENT SHIFT: TAT CA DEU DUNG';
end $test$;
