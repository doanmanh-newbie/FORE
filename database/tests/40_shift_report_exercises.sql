-- Kiểm thử shift_report (009), cờ xu hướng nhiều ca liên tiếp và min_abs_qty (004).
-- Chạy sau tests/00_supabase_stub.sql và 001..009: psql -d fore_test -v ON_ERROR_STOP=1 -f tests/40_shift_report_exercises.sql
-- (pgAdmin: xóa dòng \set ON_ERROR_STOP on). Đúng hết sẽ in "SHIFT REPORT: TAT CA DEU DUNG".
-- KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
--
-- Kịch bản (Sữa 'important', cà phê sữa dùng 30 ml, giá 29.000, bán 1 ly mỗi ca, trả tiền mặt):
--   Ca A: thực dùng nhiều hơn lý thuyết 5 ml (lệch +5)            -> 5/30 = 16,7% -> đỏ
--   Ca B: lệch +5 (cùng chiều)
--   Ca C: lệch +5, có hao hụt đổ bỏ 2 ml, có chi mua đá 20.000    -> chuỗi dài 3 ca cùng chiều => cờ xu hướng
--   Ca D: lệch -5 (ĐỔI CHIỀU)                                       -> chuỗi bị đứt, về 1
\set ON_ERROR_STOP on

truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts restart identity cascade;
delete from auth.users;
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán test');
-- đặt lại TOÀN BỘ cấu hình về mặc định (các test khác có đổi cấu hình, không để ảnh hưởng nhau)
update app_settings set value_int = case key
  when 'important_warn_pct' then 3   when 'important_alert_pct' then 5
  when 'normal_warn_pct' then 10     when 'normal_alert_pct' then 15
  when 'waste_warn_pct' then 10      when 'cash_warn_vnd' then 20000
  when 'cash_alert_vnd' then 50000   when 'opening_diff_warn_vnd' then 1000
  when 'recount_flag_after' then 2   when 'pin_max_attempts' then 3
  when 'pin_lock_minutes' then 15    when 'streak_shifts' then 3
  else value_int end;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff');
-- (đặt người đăng nhập mặc định = chủ để giá trị mặc định shop_id của các lệnh nạp dữ liệu bên dưới trỏ đúng quán)
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, unit, importance) values ('Sữa', 'ml', 'important');
insert into menu_items (name) values ('Cà phê sữa');
insert into menu_sizes (item_id, size_name, price) select id, 'M', 29000 from menu_items;
insert into recipe_lines (size_id, ingredient_id, qty) select (select id from menu_sizes), (select id from ingredients), 30;
insert into areas (name) values ('Tầng 1');
insert into dining_tables (area_id, name) select id, 'Bàn 1' from areas;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  milk uuid; cf uuid; t1 uuid; b uuid;
  sa uuid; sb uuid; sc uuid; sd uuid; s uuid;
  i int; delta int; wst int; cash_close int; oc int; j jsonb; e jsonb; msg text; k text;
begin
  select id into milk from ingredients where name = 'Sữa';
  select id into cf from menu_sizes;
  select id into t1 from dining_tables;

  -- 4 ca liên tiếp (i = 1..4): lệch +5, +5, +5 (kèm hao hụt 2 và chi 20.000), -5
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  for i in 1..4 loop
    delta := case i when 4 then -5 else 5 end;
    wst   := case i when 3 then 2 else 0 end;
    s := open_shift(case when i = 1 then 0 else cash_close end);   -- mở ca bằng đúng tiền cuối ca trước
    oc := case when i = 1 then 0 else cash_close end;
    perform submit_stock_count(milk, 'open', 1000);
    b := open_bill(t1, 'dine_in', 1); perform add_bill_line(b, cf, 1); perform pay_bill(b, 'cash');
    if wst > 0 then perform add_waste(milk, wst, 'expired', null); end if;
    cash_close := oc + 29000;
    if i = 3 then perform add_cash_movement('out', 20000, 'mua đá'); cash_close := cash_close - 20000; end if;
    perform submit_stock_count(milk, 'close', 1000 - 30 - wst - delta);
    perform close_shift(cash_close);
    if i = 1 then sa := s; elsif i = 2 then sb := s; elsif i = 3 then sc := s; else sd := s; end if;
  end loop;

  -- nhân viên không gọi được báo cáo
  begin perform shift_report(sc); raise exception 'LE RA PHAI LOI OWNER_ONLY';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'OWNER_ONLY' then raise exception 'Mong OWNER_ONLY, nhan: %', msg; end if; end;
  reset session authorization;

  -- cả bài test chạy trong 1 giao dịch nên now() giống nhau; lùi giờ các ca về quá khứ cho giống đời thật
  alter table shifts disable trigger user;
  update shifts set opened_at = opened_at - interval '30 hours', closed_at = closed_at - interval '29 hours' where id = sa;
  update shifts set opened_at = opened_at - interval '20 hours', closed_at = closed_at - interval '19 hours' where id = sb;
  update shifts set opened_at = opened_at - interval '10 hours', closed_at = closed_at - interval '9 hours'  where id = sc;
  alter table shifts enable trigger user;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;

  -- cấu trúc JSON
  j := shift_report(sc);
  foreach k in array array['shift', 'summary', 'ingredients', 'cash', 'waste', 'cash_movements', 'warnings'] loop
    if not (j ? k) then raise exception 'shift_report thieu khoa %', k; end if;
  end loop;
  begin perform shift_report(gen_random_uuid()); raise exception 'LE RA PHAI LOI NOT_FOUND';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'NOT_FOUND' then raise exception 'Mong NOT_FOUND, nhan: %', msg; end if; end;

  -- Ca C (ca thứ 3 cùng chiều): đỏ, chuỗi 3 => cờ xu hướng; tiền khớp; hao hụt 2 ml nhưng chưa vượt ngưỡng
  e := j -> 'ingredients' -> 0;
  if e ->> 'status' is distinct from 'alert' then raise exception 'Ca C Sua mong alert, nhan %', e ->> 'status'; end if;
  if (e ->> 'adjusted_variance')::int is distinct from 5 then raise exception 'Ca C chenh sau dieu chinh mong 5, nhan %', e ->> 'adjusted_variance'; end if;
  if (e ->> 'streak_count')::int is distinct from 3 or (e ->> 'streak_flag')::boolean is distinct from true then
    raise exception 'Ca C mong streak 3 / co true, nhan % / %', e ->> 'streak_count', e ->> 'streak_flag'; end if;
  if j -> 'summary' ->> 'overall' is distinct from 'alert' then raise exception 'Ca C overall mong alert, nhan %', j -> 'summary' ->> 'overall'; end if;
  if (j -> 'summary' ->> 'streak_flags')::int is distinct from 1 then raise exception 'Ca C streak_flags mong 1, nhan %', j -> 'summary' ->> 'streak_flags'; end if;
  if j -> 'summary' ->> 'cash_status' is distinct from 'ok' then raise exception 'Ca C tien mong ok, nhan %', j -> 'summary' ->> 'cash_status'; end if;
  if jsonb_array_length(j -> 'waste') is distinct from 1 or (j -> 'waste' -> 0 ->> 'qty')::int is distinct from 2 then
    raise exception 'Ca C hao hut mong 1 dong qty 2, nhan %', j -> 'waste'; end if;
  if j -> 'waste' -> 0 ->> 'flag' is distinct from 'ok' then raise exception 'Hao hut 2/30 = 6,7%% chua vuot 10%%, mong ok, nhan %', j -> 'waste' -> 0 ->> 'flag'; end if;
  if jsonb_array_length(j -> 'cash_movements') is distinct from 1
     or (j -> 'cash_movements' -> 0 ->> 'note') is distinct from 'mua đá'
     or (j -> 'cash_movements' -> 0 ->> 'entered_by_name') is distinct from 'NV1' then
    raise exception 'Ca C cash_movements sai: %', j -> 'cash_movements'; end if;

  -- Ca B: chuỗi 2 (chưa tới ngưỡng 3); Ca A: chuỗi 1
  j := shift_report(sb); e := j -> 'ingredients' -> 0;
  if (e ->> 'streak_count')::int is distinct from 2 or (e ->> 'streak_flag')::boolean is distinct from false then
    raise exception 'Ca B mong streak 2 / co false, nhan % / %', e ->> 'streak_count', e ->> 'streak_flag'; end if;
  j := shift_report(sa); e := j -> 'ingredients' -> 0;
  if (e ->> 'streak_count')::int is distinct from 1 then raise exception 'Ca A mong streak 1, nhan %', e ->> 'streak_count'; end if;

  -- Ca D đổi chiều (-5): vẫn đỏ nhưng chuỗi bị ngắt về 1, không có cờ xu hướng
  j := shift_report(sd); e := j -> 'ingredients' -> 0;
  if e ->> 'status' is distinct from 'alert' then raise exception 'Ca D mong alert, nhan %', e ->> 'status'; end if;
  if (e ->> 'adjusted_variance')::int is distinct from -5 then raise exception 'Ca D chenh mong -5, nhan %', e ->> 'adjusted_variance'; end if;
  if (e ->> 'streak_count')::int is distinct from 1 or (e ->> 'streak_flag')::boolean is distinct from false then
    raise exception 'Ca D (doi chieu) mong streak 1 / co false, nhan % / %', e ->> 'streak_count', e ->> 'streak_flag'; end if;
  if (j -> 'summary' ->> 'streak_flags')::int is distinct from 0 then raise exception 'Ca D streak_flags mong 0'; end if;

  -- streak_shifts là con số cấu hình: hạ xuống 2 thì ca B có cờ; nâng lên 4 thì ca C hết cờ; đặt 1 vẫn tính tối thiểu 2
  update app_settings set value_int = 2 where key = 'streak_shifts';
  if ((shift_report(sb) -> 'ingredients' -> 0 ->> 'streak_flag')::boolean) is distinct from true then
    raise exception 'streak_shifts=2: ca B phai co co'; end if;
  update app_settings set value_int = 1 where key = 'streak_shifts';
  if ((shift_report(sb) -> 'ingredients' -> 0 ->> 'streak_flag')::boolean) is distinct from true then
    raise exception 'streak_shifts=1 phai tinh la 2: ca B phai co co'; end if;
  if (shift_report(sa) -> 'ingredients' -> 0 ->> 'streak_flag')::boolean is distinct from false then
    raise exception 'streak_shifts toi thieu 2: ca A (chuoi 1) khong duoc co co'; end if;
  update app_settings set value_int = 4 where key = 'streak_shifts';
  if ((shift_report(sc) -> 'ingredients' -> 0 ->> 'streak_flag')::boolean) is distinct from false then
    raise exception 'streak_shifts=4: ca C (chuoi 3) khong duoc co co'; end if;
  update app_settings set value_int = 3 where key = 'streak_shifts';

  -- min_abs_qty: lệch 5 ml nhỏ hơn mức tối thiểu 10 ml thì KHÔNG cảnh báo, chuỗi cũng không có, tổng thể ok
  update ingredients set min_abs_qty = 10 where id = milk;
  j := shift_report(sc); e := j -> 'ingredients' -> 0;
  if e ->> 'status' is distinct from 'ok' then raise exception 'min_abs_qty=10: lech 5 phai ok, nhan %', e ->> 'status'; end if;
  if (e ->> 'streak_count')::int is distinct from 0 then raise exception 'min_abs_qty=10: chuoi phai 0, nhan %', e ->> 'streak_count'; end if;
  if j -> 'summary' ->> 'overall' is distinct from 'ok' then raise exception 'min_abs_qty=10: overall mong ok, nhan %', j -> 'summary' ->> 'overall'; end if;
  -- đặt mức tối thiểu 5 thì lệch đúng 5 vẫn bị cảnh báo (>= mức tối thiểu)
  update ingredients set min_abs_qty = 5 where id = milk;
  if shift_report(sc) -> 'ingredients' -> 0 ->> 'status' is distinct from 'alert' then
    raise exception 'min_abs_qty=5: lech dung 5 van phai bi canh bao'; end if;
  update ingredients set min_abs_qty = 0 where id = milk;
  reset session authorization;

  raise notice 'SHIFT REPORT: TAT CA DEU DUNG';
end
$test$;
