-- Kiểm thử báo cáo đối soát cho màn chủ quán: tên người đóng ca, bill đã thu rồi hủy, người ghi hao hụt,
-- cờ tiền đầu ca lệch và owner_shift_list (chọn ngày, lọc, phân trang, quyền).
-- Chạy sau tests/00_supabase_stub.sql và 01..04: psql -d fore_test -v ON_ERROR_STOP=1 -f tests/88_reconcile_list.sql
-- Đúng hết sẽ in "RECONCILE LIST: TAT CA DEU DUNG". KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
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
  milk uuid; cf uuid; t1 uuid; b uuid; b2 uuid; owner_id uuid;
  s1 uuid; s2 uuid; s3 uuid; s uuid;
  i int; oc int; j jsonb; l jsonb; d jsonb; msg text; wid uuid; pid uuid;
begin
  select id into milk from ingredients where name = 'Sữa';
  select id into cf from menu_sizes;
  select id into t1 from dining_tables;
  select id into owner_id from staff where role = 'owner';

  -- 3 ca đóng: ca 1 khớp; ca 2 mở lệch 2.000 so với cuối ca 1, có bill thu rồi hủy + hao hụt; ca 3 khớp
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  for i in 1..3 loop
    oc := case i when 1 then 0 when 2 then 31000 else 60000 end;   -- cuối ca 1 = 29.000; ca 2 mở 31.000 (lệch +2.000)
    s := open_shift(oc);
    perform submit_stock_count(milk, 'open', 1000);
    b := open_bill(t1, 'dine_in', 1); perform add_bill_line(b, cf, 1); perform pay_bill(b, 'cash');
    if i = 2 then
      b2 := open_bill(t1, 'take_away'); perform add_bill_line(b2, cf, 1); perform pay_bill(b2, 'cash');
      perform add_purchase(milk, 500, false, 'nhập thêm giữa ca');
      perform add_waste(milk, 40, 'expired', 'sữa hết hạn');
    end if;
    perform submit_stock_count(milk, 'close', case i when 2 then 1000 + 500 - 60 - 40 else 970 end);
    perform close_shift(oc + case i when 2 then 58000 else 29000 end);
    if i = 1 then s1 := s; elsif i = 2 then s2 := s; else s3 := s; end if;
  end loop;
  reset session authorization;

  -- bill b2 đã thu rồi bị hủy (có chủ duyệt) trong ca 2; trừ tiền mặt tương ứng trong két
  alter table bills disable trigger user;
  update bills set status = 'cancelled', cancelled_by = (select id from staff where role = 'staff'),
         cancelled_at = now(), cancel_reason = 'khách đổi ý', approved_by = owner_id where id = b2;
  alter table bills enable trigger user;
  update shifts set closing_cash = closing_cash - 29000 where id = s2;   -- bill hủy được hoàn tiền

  alter table shifts disable trigger user;
  update shifts set opened_at = opened_at - interval '30 hours', closed_at = closed_at - interval '29 hours' where id = s1;
  update shifts set opened_at = opened_at - interval '20 hours', closed_at = closed_at - interval '19 hours' where id = s2;
  update shifts set opened_at = opened_at - interval '10 hours', closed_at = closed_at - interval '9 hours'  where id = s3;
  alter table shifts enable trigger user;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;

  -- (1) shift_report: tên người mở/đóng ca
  j := shift_report(s2);
  if j -> 'shift' ->> 'opened_by_name' is distinct from 'NV1' or j -> 'shift' ->> 'closed_by_name' is distinct from 'NV1' then
    raise exception 'shift_report thieu ten nguoi mo/dong ca: %', j -> 'shift'; end if;

  -- (2) bill đã thu rồi hủy
  if jsonb_array_length(j -> 'cancelled_bills') is distinct from 1 then
    raise exception 'ca 2 mong 1 bill huy, nhan %', j -> 'cancelled_bills'; end if;
  if (j -> 'cancelled_bills' -> 0 ->> 'amount')::int is distinct from 29000
     or j -> 'cancelled_bills' -> 0 ->> 'reason' is distinct from 'khách đổi ý'
     or j -> 'cancelled_bills' -> 0 ->> 'cancelled_by_name' is distinct from 'NV1'
     or j -> 'cancelled_bills' -> 0 ->> 'approved_by_name' is distinct from 'Chủ' then
    raise exception 'bill huy sai noi dung: %', j -> 'cancelled_bills'; end if;
  if jsonb_array_length(shift_report(s1) -> 'cancelled_bills') is distinct from 0 then
    raise exception 'ca 1 khong co bill huy'; end if;

  -- (3) hao hụt: ai ghi, lúc nào, loại gì
  if jsonb_array_length(j -> 'waste_entries') is distinct from 1
     or (j -> 'waste_entries' -> 0 ->> 'qty')::int is distinct from 40
     or j -> 'waste_entries' -> 0 ->> 'entered_by_name' is distinct from 'NV1'
     or j -> 'waste_entries' -> 0 ->> 'ingredient_name' is distinct from 'Sữa'
     or j -> 'waste_entries' -> 0 ->> 'entered_at' is null then
    raise exception 'waste_entries sai: %', j -> 'waste_entries'; end if;

  if (j -> 'waste_entries' -> 0 ->> 'id') is null then raise exception 'waste_entries thieu id'; end if;
  if jsonb_array_length(j -> 'purchases') is distinct from 1
     or (j -> 'purchases' -> 0 ->> 'qty')::int is distinct from 500
     or j -> 'purchases' -> 0 ->> 'entered_by_name' is distinct from 'NV1'
     or j -> 'purchases' -> 0 ->> 'id' is null then
    raise exception 'purchases sai: %', j -> 'purchases'; end if;
  if jsonb_array_length(shift_report(s1) -> 'purchases') is distinct from 0 then
    raise exception 'ca 1 khong co phieu nhap'; end if;

  -- (4) tiền đầu ca lệch so với cuối ca trước
  if (j -> 'cash' ->> 'opening_diff')::int is distinct from 2000 then
    raise exception 'ca 2 opening_diff mong 2000, nhan %', j -> 'cash' ->> 'opening_diff'; end if;
  if (j -> 'summary' ->> 'opening_diff_flag')::boolean is distinct from true
     or (j -> 'cash' ->> 'opening_diff_flag')::boolean is distinct from true then
    raise exception 'ca 2 phai co co opening_diff_flag'; end if;
  if (shift_report(s1) -> 'summary' ->> 'opening_diff_flag')::boolean is distinct from false then
    raise exception 'ca 1 (ca dau tien) khong co co opening_diff'; end if;
  if (shift_report(s3) -> 'summary' ->> 'opening_diff_flag')::boolean is distinct from false then
    raise exception 'ca 3 mo dung tien cuoi ca 2: khong co co'; end if;
  if shift_report(s2) -> 'summary' ->> 'overall' = 'ok' then
    raise exception 'opening_diff_flag phai dua tong the ca 2 len it nhat warn'; end if;
  -- tăng ngưỡng lên 5.000 thì lệch 2.000 không còn là đáng chú ý
  update app_settings set value_int = 5000 where key = 'opening_diff_warn_vnd';
  if (shift_report(s2) -> 'summary' ->> 'opening_diff_flag')::boolean is distinct from false then
    raise exception 'nguong 5000: lech 2000 khong duoc co co'; end if;
  update app_settings set value_int = 1000 where key = 'opening_diff_warn_vnd';

  -- (5) owner_shift_list: tất cả, mới nhất trước, có tên người đóng ca và báo cáo
  l := owner_shift_list(now() - interval '3 days', now() + interval '1 day');
  if jsonb_array_length(l -> 'items') is distinct from 3 or (l ->> 'has_more')::boolean then
    raise exception 'list all mong 3 ca, nhan %', jsonb_array_length(l -> 'items'); end if;
  if (l -> 'items' -> 0 -> 'shift' ->> 'id')::uuid is distinct from s3
     or (l -> 'items' -> 2 -> 'shift' ->> 'id')::uuid is distinct from s1 then
    raise exception 'list phai xep ca moi nhat truoc'; end if;
  if l -> 'items' -> 1 -> 'shift' ->> 'closed_by_name' is distinct from 'NV1'
     or l -> 'items' -> 1 -> 'report' -> 'summary' is null then
    raise exception 'item thieu closed_by_name hoac report'; end if;
  if l -> 'open_shift' is not null and l -> 'open_shift' <> 'null'::jsonb then
    raise exception 'khong co ca dang mo'; end if;

  -- phân trang: limit 2 -> 2 ca + has_more, rồi lấy tiếp bằng next_before
  l := owner_shift_list(now() - interval '3 days', now() + interval '1 day', 'all', 2);
  if jsonb_array_length(l -> 'items') is distinct from 2 or not (l ->> 'has_more')::boolean then
    raise exception 'phan trang trang 1 sai'; end if;
  l := owner_shift_list(now() - interval '3 days', now() + interval '1 day', 'all', 2, (l ->> 'next_before')::timestamptz);
  if jsonb_array_length(l -> 'items') is distinct from 1 or (l ->> 'has_more')::boolean
     or (l -> 'items' -> 0 -> 'shift' ->> 'id')::uuid is distinct from s1 then
    raise exception 'phan trang trang 2 sai'; end if;

  -- chọn ngày: chỉ lấy ca mở trong khoảng (ca 1 mở 30 giờ trước, ca 2 mở 20 giờ trước)
  l := owner_shift_list(now() - interval '25 hours', now() - interval '15 hours');
  if jsonb_array_length(l -> 'items') is distinct from 1 or (l -> 'items' -> 0 -> 'shift' ->> 'id')::uuid is distinct from s2 then
    raise exception 'loc theo ngay sai'; end if;

  -- lọc "cần xem": ca 2 (tiền đầu ca lệch / hao hụt) có mặt; ca khớp thì không
  l := owner_shift_list(now() - interval '3 days', now() + interval '1 day', 'attention');
  if not exists (select 1 from jsonb_array_elements(l -> 'items') x where (x -> 'shift' ->> 'id')::uuid = s2) then
    raise exception 'loc attention phai co ca 2'; end if;
  if exists (select 1 from jsonb_array_elements(l -> 'items') x where (x -> 'shift' ->> 'id')::uuid = s3) then
    raise exception 'loc attention khong duoc co ca 3 (khop)'; end if;

  -- lọc "pending" = vàng/đỏ VÀ chưa xử lý; dashboard đếm ca chờ xử lý trong 7 ngày
  l := owner_shift_list(now() - interval '3 days', now() + interval '1 day', 'pending');
  if jsonb_array_length(l -> 'items') is distinct from 1 or (l -> 'items' -> 0 -> 'shift' ->> 'id')::uuid is distinct from s2 then
    raise exception 'loc pending mong dung ca 2, nhan %', l; end if;
  d := owner_dashboard(now() - interval '24 hours', now() + interval '1 hour');
  if (d ->> 'pending_review_count')::int is distinct from 1 then
    raise exception 'pending_review_count mong 1, nhan %', d ->> 'pending_review_count'; end if;
  if jsonb_array_length(d -> 'missing_recipe_sizes') is distinct from 0 then
    raise exception 'missing_recipe_sizes mong rong'; end if;
  if d -> 'yesterday_sales' is null then raise exception 'thieu yesterday_sales'; end if;

  -- chủ sửa số lượng bằng dòng điều chỉnh: báo cáo hiện số hiệu lực, giữ số gốc
  wid := (j -> 'waste_entries' -> 0 ->> 'id')::uuid;
  pid := (j -> 'purchases' -> 0 ->> 'id')::uuid;
  perform correct_waste(wid, 30, 'đếm lại ly đổ');
  perform correct_purchase(pid, 450, 'nhập nhầm số');
  j := shift_report(s2);
  if (j -> 'waste_entries' -> 0 ->> 'qty')::int is distinct from 30 or (j -> 'waste_entries' -> 0 ->> 'original_qty')::int is distinct from 40 then
    raise exception 'waste sau sua sai: %', j -> 'waste_entries'; end if;
  if (j -> 'purchases' -> 0 ->> 'qty')::int is distinct from 450 or (j -> 'purchases' -> 0 ->> 'original_qty')::int is distinct from 500 then
    raise exception 'purchase sau sua sai: %', j -> 'purchases'; end if;

  -- lọc "chưa xử lý": sau khi đánh dấu đã xử lý ca 2 thì biến mất khỏi danh sách chưa xử lý, review hiện ở danh sách tất cả
  perform set_shift_review(s2, true, 'đã hỏi nhân viên');
  l := owner_shift_list(now() - interval '3 days', now() + interval '1 day', 'unhandled');
  if jsonb_array_length(l -> 'items') is distinct from 2 then raise exception 'unhandled mong 2 ca, nhan %', jsonb_array_length(l -> 'items'); end if;
  d := owner_dashboard(now() - interval '24 hours', now() + interval '1 hour');
  if (d ->> 'pending_review_count')::int is distinct from 0 then
    raise exception 'sau khi xu ly pending_review_count mong 0, nhan %', d ->> 'pending_review_count'; end if;
  l := owner_shift_list(now() - interval '3 days', now() + interval '1 day');
  if (l -> 'items' -> 1 -> 'review' ->> 'handled')::boolean is distinct from true
     or l -> 'items' -> 1 -> 'review' ->> 'note' is distinct from 'đã hỏi nhân viên' then
    raise exception 'review cua ca 2 sai: %', l -> 'items' -> 1 -> 'review'; end if;

  -- tham số sai
  begin perform owner_shift_list(now(), now() - interval '1 day'); raise exception 'LE RA PHAI LOI DATE_RANGE_INVALID';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'DATE_RANGE_INVALID' then raise exception 'Mong DATE_RANGE_INVALID, nhan: %', msg; end if; end;
  begin perform owner_shift_list(now() - interval '100 days', now()); raise exception 'LE RA PHAI LOI DATE_RANGE_INVALID';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'DATE_RANGE_INVALID' then raise exception 'Mong DATE_RANGE_INVALID (>62 ngay), nhan: %', msg; end if; end;
  begin perform owner_shift_list(now() - interval '1 day', now(), 'bogus'); raise exception 'LE RA PHAI LOI FILTER_INVALID';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'FILTER_INVALID' then raise exception 'Mong FILTER_INVALID, nhan: %', msg; end if; end;

  -- nhân viên không gọi được
  perform set_config('request.jwt.claim.sub', nv1, true);
  begin perform owner_shift_list(now() - interval '1 day', now()); raise exception 'LE RA PHAI LOI OWNER_ONLY';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'OWNER_ONLY' then raise exception 'Mong OWNER_ONLY, nhan: %', msg; end if; end;
  reset session authorization;

  raise notice 'RECONCILE LIST: TAT CA DEU DUNG';
end
$test$;
