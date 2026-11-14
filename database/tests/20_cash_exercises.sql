-- Kiểm thử đối soát TIỀN MẶT trên Postgres thường (sau tests/00_supabase_stub.sql và 001..008).
-- Chạy: psql -d fore_test -v ON_ERROR_STOP=1 -f tests/20_cash_exercises.sql
-- (Nếu chạy bằng pgAdmin: xóa dòng \set ON_ERROR_STOP on)
-- Đúng hết sẽ in "TIEN MAT: TAT CA DEU DUNG". KHÔNG chạy trên Supabase thật.
--
-- Kịch bản ca 1: đầu ca 500.000
--   bill A: 2 cà phê sữa = 58.000, tiền mặt          -> tính
--   bill B: 1 trà sữa    = 35.000, chuyển khoản      -> KHÔNG tính vào két
--   bill C: 1 trà sữa    = 35.000, tiền mặt, rồi hủy -> KHÔNG tính (đã hoàn tiền khách)
--   chi mua đá 20.000, chủ rút 100.000, đổi tiền lẻ bỏ thêm 50.000
--   đổi tiền lẻ 50.000; thêm 2 khoản bỏ vào 1.000 không lý do (cho phép)
--   đáng ra có = 500.000 + 58.000 + 52.000 - 20.000 - 100.000 = 490.000
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
  else value_int end;          -- khóa nào không có trong danh sách thì giữ nguyên, không làm trống
-- đặt lại ngưỡng mặc định (bài test này có đổi ngưỡng, không để lần chạy trước ảnh hưởng lần sau)
update app_settings set value_int = 20000 where key = 'cash_warn_vnd';
update app_settings set value_int = 50000 where key = 'cash_alert_vnd';

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff');
-- (đặt người đăng nhập mặc định = chủ để giá trị mặc định shop_id của các lệnh nạp dữ liệu bên dưới trỏ đúng quán)
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, unit, importance) values ('Sữa', 'ml', 'important');
insert into menu_items (name) values ('Cà phê sữa'), ('Trà sữa');
insert into menu_sizes (item_id, size_name, price)
  select id, 'M', case name when 'Cà phê sữa' then 29000 else 35000 end from menu_items;
insert into recipe_lines (size_id, ingredient_id, qty)
  select ms.id, (select id from ingredients), case mi.name when 'Cà phê sữa' then 30 else 50 end
    from menu_sizes ms join menu_items mi on mi.id = ms.item_id;
insert into areas (name) values ('Tầng 1');
insert into dining_tables (area_id, name) select id, 'Bàn ' || g from areas, generate_series(1, 3) g;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  ing uuid; cf uuid; ts uuid; t1 uuid; t2 uuid; t3 uuid;
  s1 uuid; s2 uuid; ba uuid; bb uuid; bc uuid; r record; n int; msg text; res text; mv uuid;
begin
  select id into ing from ingredients;
  select ms.id into cf from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Cà phê sữa';
  select ms.id into ts from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Trà sữa';
  select id into t1 from dining_tables where name = 'Bàn 1';
  select id into t2 from dining_tables where name = 'Bàn 2';
  select id into t3 from dining_tables where name = 'Bàn 3';

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform set_staff_pin((select id from staff where role = 'owner'), '1234');
  reset session authorization;

  ----------------------------------------------------------------
  -- Ca 1 (nhân viên thao tác)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;

  -- chưa mở ca thì không ghi được thu/chi
  begin
    perform add_cash_movement('out', 20000, 'mua đá');
    raise exception 'LE RA PHAI LOI NO_OPEN_SHIFT';
  exception when others then
    get stacked diagnostics msg = message_text;
    if msg <> 'NO_OPEN_SHIFT' then raise exception 'Mong NO_OPEN_SHIFT, nhan: %', msg; end if;
  end;

  s1 := open_shift(500000);
  perform submit_stock_count(ing, 'open', 10000);

  ba := open_bill(t1, 'dine_in', 2); perform add_bill_line(ba, cf, 2); perform pay_bill(ba, 'cash');
  bb := open_bill(t2, 'dine_in', 1); perform add_bill_line(bb, ts, 1); perform pay_bill(bb, 'transfer');
  bc := open_bill(t3, 'dine_in', 1); perform add_bill_line(bc, ts, 1); perform pay_bill(bc, 'cash');
  res := cancel_paid_bill(bc, '1234', 'khach doi y');
  if res <> 'OK' then raise exception 'Huy bill C: mong OK, nhan %', res; end if;

  mv := add_cash_movement('out', 20000, 'mua đá');
  perform add_cash_movement('out', 100000, 'chủ rút gửi ngân hàng');
  perform add_cash_movement('in', 50000, 'đổi tiền lẻ');

  -- các lỗi đầu vào
  begin perform add_cash_movement('out', 0, 'x x x'); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'AMOUNT_INVALID' then raise exception 'Mong AMOUNT_INVALID, nhan: %', msg; end if; end;
  begin perform add_cash_movement('out', -5000, 'x x x'); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'AMOUNT_INVALID' then raise exception 'Mong AMOUNT_INVALID (so am), nhan: %', msg; end if; end;
  begin perform add_cash_movement('out', 1000, '   '); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'NOTE_REQUIRED' then raise exception 'Mong NOTE_REQUIRED, nhan: %', msg; end if; end;
  begin perform add_cash_movement('out', 1000, null); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'NOTE_REQUIRED' then raise exception 'Lay tien ra khong ghi chu: mong NOTE_REQUIRED, nhan: %', msg; end if; end;
  -- bỏ tiền vào thì không cần lý do
  perform add_cash_movement('in', 1000, null);
  perform add_cash_movement('in', 1000, '');
  begin perform add_cash_movement('bay_ba', 1000, 'xxxx'); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'DIRECTION_INVALID' then raise exception 'Mong DIRECTION_INVALID, nhan: %', msg; end if; end;

  -- nhân viên không đọc được thu/chi, không gọi được đối soát
  select count(*) into n from cash_movements;
  if n <> 0 then raise exception 'Nhan vien doc duoc cash_movements (% dong)', n; end if;
  begin perform * from reconcile_cash(s1); raise exception 'LE RA PHAI LOI OWNER_ONLY';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'OWNER_ONLY' then raise exception 'Mong OWNER_ONLY, nhan: %', msg; end if; end;

  perform submit_stock_count(ing, 'close', 9000);
  perform close_shift(490000);            -- đếm đúng bằng đáng ra có
  reset session authorization;

  -- Cả bài test chạy trong 1 giao dịch nên now() giống nhau; lùi giờ ca 1 về quá khứ cho giống đời thật
  -- (tắt trigger tạm thời, chỉ dùng trong test với quyền quản trị).
  alter table shifts disable trigger user;
  update shifts set opened_at = opened_at - interval '10 hours', closed_at = closed_at - interval '9 hours' where id = s1;
  alter table shifts enable trigger user;

  ----------------------------------------------------------------
  -- Chủ xem ca 1: phải khớp (variance 0, ok)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  select * into r from reconcile_cash(s1);
  if r.opening_cash is distinct from 500000 then raise exception 'opening_cash %', r.opening_cash; end if;
  if r.cash_sales is distinct from 58000 then raise exception 'cash_sales mong 58000, nhan % (bill huy phai bi loai)', r.cash_sales; end if;
  if r.transfer_sales is distinct from 35000 then raise exception 'transfer_sales mong 35000, nhan %', r.transfer_sales; end if;
  if r.cash_in is distinct from 52000 then raise exception 'cash_in mong 52000, nhan %', r.cash_in; end if;
  if r.cash_out is distinct from 120000 then raise exception 'cash_out mong 120000, nhan %', r.cash_out; end if;
  if r.expected_cash is distinct from 490000 then raise exception 'expected_cash mong 490000, nhan %', r.expected_cash; end if;
  if r.variance is distinct from 0 or r.status is distinct from 'ok' then raise exception 'ca 1 mong lech 0/ok, nhan %/%', r.variance, r.status; end if;
  if r.prev_closing_cash is not null then raise exception 'ca dau tien khong co ca truoc'; end if;
  if r.cancelled_after_paid_count is distinct from 1 or r.cancelled_after_paid_amount is distinct from 35000 then
    raise exception 'bill thu roi huy mong 1/35000, nhan %/%', r.cancelled_after_paid_count, r.cancelled_after_paid_amount; end if;

  -- v_cash_movements hiện tên người nhập, chủ đọc được
  select count(*) into n from v_cash_movements where shift_id = s1 and entered_by_name = 'NV1';
  if n <> 5 then raise exception 'v_cash_movements mong 5 dong cua NV1, nhan %', n; end if;
  reset session authorization;

  ----------------------------------------------------------------
  -- Ca 2: đầu ca 480.000 (lệch -10.000 so với cuối ca trước 490.000), cuối ca đếm 450.000 (thiếu 30.000)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  s2 := open_shift(480000);
  perform submit_stock_count(ing, 'open', 9000);
  perform submit_stock_count(ing, 'close', 9000);
  perform close_shift(450000);
  reset session authorization;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  select * into r from reconcile_cash(s2);
  if r.prev_closing_cash is distinct from 490000 then raise exception 'prev_closing_cash mong 490000, nhan %', r.prev_closing_cash; end if;
  if r.opening_diff is distinct from -10000 then raise exception 'opening_diff mong -10000, nhan %', r.opening_diff; end if;
  if r.expected_cash is distinct from 480000 then raise exception 'expected ca 2 mong 480000, nhan %', r.expected_cash; end if;
  if r.variance is distinct from -30000 or r.status is distinct from 'warn' then raise exception 'ca 2 mong -30000/warn, nhan %/%', r.variance, r.status; end if;
  if r.variance_pct is not null then raise exception 'khong co doanh thu tien mat thi % phai null', 'variance_pct'; end if;

  -- đổi ngưỡng: chỉ chủ đổi được, và đổi xong trạng thái đổi theo
  update app_settings set value_int = 30000 where key = 'cash_alert_vnd';
  select * into r from reconcile_cash(s2);
  if r.status is distinct from 'alert' then raise exception 'Sau khi ha nguong alert xuong 30000, mong alert, nhan %', r.status; end if;
  reset session authorization;

  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  update app_settings set value_int = 999999 where key = 'cash_alert_vnd';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Nhan vien sua duoc app_settings (% dong)', n; end if;
  reset session authorization;

  ----------------------------------------------------------------
  -- Chống sửa/xóa (kể cả vai trò quản trị qua trigger)
  ----------------------------------------------------------------
  begin update cash_movements set amount = 1 where id = mv; raise exception 'LE RA PHAI LOI (update)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg like 'LE RA%' then raise; end if; end;
  begin delete from cash_movements where id = mv; raise exception 'LE RA PHAI LOI (delete)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg like 'LE RA%' then raise; end if; end;

  raise notice 'TIEN MAT: TAT CA DEU DUNG';
end
$test$;
