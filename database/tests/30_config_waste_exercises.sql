-- Kiểm thử CẤU HÌNH (app_settings), LOẠI HAO HỤT (waste_types) và BÁO CÁO HAO HỤT (waste_report).
-- Chạy sau tests/00_supabase_stub.sql và 001..008. Chạy: psql -d fore_test -v ON_ERROR_STOP=1 -f tests/30_config_waste_exercises.sql
-- (pgAdmin: xóa dòng \set ON_ERROR_STOP on). Đúng hết sẽ in "CAU HINH + HAO HUT: TAT CA DEU DUNG".
-- KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
--
-- Kịch bản ca 1 (Sữa, important; Đường, normal):
--   mở kho Sữa 1000, bán 2 cà phê sữa (60 ml) + 1 trà sữa (50 ml) => lý thuyết 110 ml
--   hao hụt Sữa: đổ bỏ 8 + làm sai 3 = 11 ml (10% lý thuyết, đúng bằng ngưỡng 10% => cảnh báo)
--   cuối ca đếm Sữa 859 => thực dùng 141; chênh sau điều chỉnh = 141 - 110 - 11 = 20 ml (18,2%)
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
-- đặt lại cấu hình mặc định
update app_settings set value_int = 3  where key = 'important_warn_pct';
update app_settings set value_int = 5  where key = 'important_alert_pct';
update app_settings set value_int = 10 where key = 'waste_warn_pct';
update app_settings set value_int = 3  where key = 'pin_max_attempts';
alter table waste_types disable trigger user;     -- chỉ trong test: bảng này chặn xóa, cần dọn loại 'spill' của lần chạy trước
delete from waste_types where code not in ('expired', 'mistake', 'staff_meal', 'tasting', 'other');
alter table waste_types enable trigger user;
update waste_types set active = true;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff');
-- (đặt người đăng nhập mặc định = chủ để giá trị mặc định shop_id của các lệnh nạp dữ liệu bên dưới trỏ đúng quán)
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, unit, importance) values ('Sữa', 'ml', 'important'), ('Đường', 'g', 'normal');
insert into menu_items (name) values ('Cà phê sữa'), ('Trà sữa');
insert into menu_sizes (item_id, size_name, price)
  select id, 'M', case name when 'Cà phê sữa' then 29000 else 35000 end from menu_items;
insert into recipe_lines (size_id, ingredient_id, qty)
  select ms.id, (select id from ingredients where name = 'Sữa'), case mi.name when 'Cà phê sữa' then 30 else 50 end
    from menu_sizes ms join menu_items mi on mi.id = ms.item_id;
insert into areas (name) values ('Tầng 1');
insert into dining_tables (area_id, name) select id, 'Bàn ' || g from areas, generate_series(1, 2) g;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  milk uuid; sugar uuid; cf uuid; ts uuid; t1 uuid; t2 uuid;
  s1 uuid; s2 uuid; b1 uuid; b2 uuid; w_exp uuid; r record; n int; msg text; res text;
begin
  select id into milk  from ingredients where name = 'Sữa';
  select id into sugar from ingredients where name = 'Đường';
  select ms.id into cf from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Cà phê sữa';
  select ms.id into ts from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Trà sữa';
  select id into t1 from dining_tables where name = 'Bàn 1';
  select id into t2 from dining_tables where name = 'Bàn 2';

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform set_staff_pin((select id from staff where role = 'owner'), '1234');
  reset session authorization;

  ----------------------------------------------------------------
  -- Ca 1 (nhân viên)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  s1 := open_shift(0);
  perform submit_stock_count(milk, 'open', 1000);
  perform submit_stock_count(sugar, 'open', 500);
  b1 := open_bill(t1, 'dine_in', 2); perform add_bill_line(b1, cf, 2); perform add_bill_line(b1, ts, 1); perform pay_bill(b1, 'cash');

  -- loại hao hụt: sai loại / loại "khác" thiếu ghi chú đều bị từ chối
  begin perform add_waste(milk, 5, 'bay_ba', null); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'WASTE_TYPE_INVALID' then raise exception 'Mong WASTE_TYPE_INVALID, nhan: %', msg; end if; end;
  begin perform add_waste(sugar, 5, 'other', 'ngan'); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'NOTE_REQUIRED' then raise exception 'Mong NOTE_REQUIRED, nhan: %', msg; end if; end;

  w_exp := add_waste(milk, 8, 'expired', null);          -- không ghi chú: lấy tên loại làm ghi chú
  perform add_waste(milk, 3, 'mistake', 'pha nham vi');
  perform add_waste(sugar, 5, 'other', 'rơi vỡ bình');   -- không bán đường nhưng có hao hụt
  select reason into msg from waste_logs where id = w_exp;   -- nhân viên không đọc được: dòng này phải trả 0 dòng
  perform submit_stock_count(milk, 'close', 859);
  perform submit_stock_count(sugar, 'close', 495);
  perform close_shift(0);

  -- nhân viên không gọi được báo cáo hao hụt, không sửa được cấu hình / loại hao hụt
  begin perform * from waste_report(s1); raise exception 'LE RA PHAI LOI OWNER_ONLY';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'OWNER_ONLY' then raise exception 'Mong OWNER_ONLY, nhan: %', msg; end if; end;
  begin insert into waste_types (code, label_vi) values ('nv_tu_them', 'x'); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg like 'LE RA%' then raise exception 'Nhan vien them duoc waste_types'; end if; end;
  update waste_types set active = false where code = 'tasting';
  get diagnostics n = row_count;
  if n <> 0 then raise exception 'Nhan vien sua duoc waste_types (% dong)', n; end if;
  reset session authorization;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;

  -- ghi chú mặc định = tên loại
  select reason into msg from waste_logs where id = w_exp;
  if msg is distinct from 'Đổ bỏ (quá giờ/hết hạn)' then raise exception 'Ghi chu mac dinh sai: %', msg; end if;

  ----------------------------------------------------------------
  -- Cấu hình điều khiển trạng thái đối soát: chênh sau điều chỉnh = 20 ml (18,2%)
  ----------------------------------------------------------------
  select * into r from reconcile_shift(s1) x where x.ingredient_id = milk;
  if r.justified_waste is distinct from 11 or r.adjusted_variance is distinct from 20 then
    raise exception 'Sua: hao hut co ly do mong 11 / chenh sau dieu chinh mong 20, nhan %/%', r.justified_waste, r.adjusted_variance; end if;
  if r.status is distinct from 'alert' then raise exception 'Mac dinh (do 5%%) mong alert, nhan %', r.status; end if;

  update app_settings set value_int = 19 where key = 'important_warn_pct';
  update app_settings set value_int = 20 where key = 'important_alert_pct';
  select * into r from reconcile_shift(s1) x where x.ingredient_id = milk;
  if r.status is distinct from 'ok' then raise exception 'Nang nguong len 19/20, 18,2%% phai ok, nhan %', r.status; end if;

  update app_settings set value_int = 10 where key = 'important_warn_pct';
  update app_settings set value_int = 50 where key = 'important_alert_pct';
  select * into r from reconcile_shift(s1) x where x.ingredient_id = milk;
  if r.status is distinct from 'warn' then raise exception 'Nguong 10/50, 18,2%% phai warn, nhan %', r.status; end if;

  -- ngưỡng riêng của từng nguyên liệu ưu tiên hơn ngưỡng chung
  update ingredients set warn_pct = 1, alert_pct = 2 where id = milk;
  select * into r from reconcile_shift(s1) x where x.ingredient_id = milk;
  if r.status is distinct from 'alert' then raise exception 'Nguong rieng 1/2 phai alert, nhan %', r.status; end if;
  update ingredients set warn_pct = null, alert_pct = null where id = milk;

  ----------------------------------------------------------------
  -- Báo cáo hao hụt
  ----------------------------------------------------------------
  select count(*) into n from waste_report(s1) x where x.ingredient_id = milk;
  if n <> 2 then raise exception 'waste_report Sua mong 2 dong (expired, mistake), nhan %', n; end if;
  select * into r from waste_report(s1) x where x.ingredient_id = milk and x.reason_type = 'expired';
  if r.qty is distinct from 8 or r.waste_total is distinct from 11 or r.theoretical_used is distinct from 110 or r.waste_pct_total is distinct from 10.0 or r.flag is distinct from 'warn' then
    raise exception 'waste_report expired sai: qty %, tong %, ly thuyet %, pct %, flag %', r.qty, r.waste_total, r.theoretical_used, r.waste_pct_total, r.flag; end if;
  select * into r from waste_report(s1) x where x.ingredient_id = sugar;
  if r.flag is distinct from 'warn' or r.theoretical_used is distinct from 0 then
    raise exception 'Duong (khong ban gi ma van hao) phai warn, nhan flag % theo %', r.flag, r.theoretical_used; end if;

  -- chủ điều chỉnh 8 -> 2: báo cáo phải theo sổ kho (tổng 5 ml = 4,5%, hết cảnh báo)
  perform correct_waste(w_exp, 2, 'nhan vien ghi nham');
  select * into r from waste_report(s1) x where x.ingredient_id = milk and x.reason_type = 'expired';
  if r.qty is distinct from 2 or r.waste_total is distinct from 5 or r.waste_pct_total is distinct from 4.5 or r.flag is distinct from 'ok' then
    raise exception 'Sau dieu chinh: mong qty 2 / tong 5 / 4.5%% / ok, nhan %/%/%/%', r.qty, r.waste_total, r.waste_pct_total, r.flag; end if;

  -- ngưỡng cảnh báo hao hụt là con số cấu hình: hạ xuống 4% thì lại cảnh báo
  update app_settings set value_int = 4 where key = 'waste_warn_pct';
  select * into r from waste_report(s1) x where x.ingredient_id = milk and x.reason_type = 'mistake';
  if r.flag is distinct from 'warn' then raise exception 'Ha waste_warn_pct xuong 4, 4,5%% phai warn, nhan %', r.flag; end if;

  -- chi tiết từng lần ghi có tên người nhập
  select count(*) into n from v_waste_detail where shift_id = s1 and entered_by_name = 'NV1';
  if n <> 3 then raise exception 'v_waste_detail mong 3 dong cua NV1, nhan %', n; end if;

  ----------------------------------------------------------------
  -- Chủ thêm / ẩn loại hao hụt; không xóa được
  ----------------------------------------------------------------
  insert into waste_types (code, label_vi, sort_order) values ('spill', 'Làm đổ', 5);
  reset session authorization;

  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  s2 := open_shift(0);
  perform add_waste(sugar, 1, 'spill', null);              -- loại mới dùng được ngay, không cần sửa code
  reset session authorization;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  update waste_types set active = false where code = 'spill';
  reset session authorization;
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  begin perform add_waste(sugar, 1, 'spill', null); raise exception 'LE RA PHAI LOI';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'WASTE_TYPE_INVALID' then raise exception 'Loai da an: mong WASTE_TYPE_INVALID, nhan: %', msg; end if; end;
  reset session authorization;

  begin delete from waste_types where code = 'spill'; raise exception 'LE RA PHAI LOI (delete)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg like 'LE RA%' then raise; end if; end;

  ----------------------------------------------------------------
  -- Chính sách PIN là con số cấu hình: hạ pin_max_attempts xuống 2 thì sai 2 lần là khóa
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  update app_settings set value_int = 2 where key = 'pin_max_attempts';
  reset session authorization;

  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  b2 := open_bill(t2, 'dine_in', 1); perform add_bill_line(b2, ts, 1); perform pay_bill(b2, 'cash');
  res := cancel_paid_bill(b2, '0000', 'thu'); if res <> 'WRONG_PIN' then raise exception 'Lan 1 mong WRONG_PIN, nhan %', res; end if;
  res := cancel_paid_bill(b2, '0000', 'thu'); if res <> 'WRONG_PIN' then raise exception 'Lan 2 mong WRONG_PIN, nhan %', res; end if;
  res := cancel_paid_bill(b2, '1234', 'thu'); if res <> 'PIN_LOCKED' then raise exception 'Lan 3 (dung PIN) mong PIN_LOCKED vi max=2, nhan %', res; end if;
  reset session authorization;

  raise notice 'CAU HINH + HAO HUT: TAT CA DEU DUNG';
end
$test$;
