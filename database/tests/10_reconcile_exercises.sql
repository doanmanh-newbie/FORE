-- Kiểm thử trên Postgres thường (sau tests/00_supabase_stub.sql và 001..004).
-- Chạy: psql -d fore_test -v ON_ERROR_STOP=1 -f tests/10_reconcile_exercises.sql
-- Nếu mọi thứ đúng sẽ in "TẤT CẢ KIỂM THỬ ĐỀU ĐÚNG". Sai chỗ nào sẽ báo lỗi chỗ đó.
-- Kiểm tra: Bài 1 (+1.500 ml ≈ 21,4% ≈ 42,9 ly), Bài 2 (−200 ml ≈ −2,9%), chống thanh toán trùng,
-- chống mở trùng bàn, PIN khóa sau 3 lần sai, nhân viên không đọc được sổ kho, nhật ký không sửa được.
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

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test'),
  ('00000000-0000-0000-0000-0000000000b2', 'nv2@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b2', 'NV2', 'staff');
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
insert into dining_tables (area_id, name) select id, 'Bàn 1' from areas;
insert into dining_tables (area_id, name) select id, 'Bàn 2' from areas;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  nv2     constant text := '00000000-0000-0000-0000-0000000000b2';
  ing uuid; cf uuid; ts uuid; t1 uuid; t2 uuid;
  s1 uuid; s2 uuid; b uuid; b2 uuid; r record; n int; res text; msg text;
begin
  select id into ing from ingredients;
  select ms.id into cf from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Cà phê sữa';
  select ms.id into ts from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Trà sữa';
  select id into t1 from dining_tables where name = 'Bàn 1';
  select id into t2 from dining_tables where name = 'Bàn 2';

  -- PIN chủ = 1234
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform set_staff_pin((select id from staff where role = 'owner'), '1234');
  reset session authorization;

  ----------------------------------------------------------------
  -- BÀI 1
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  s1 := open_shift(500000);
  perform submit_stock_count(ing, 'open', 3000);
  perform add_purchase(ing, 5000);
  perform add_purchase(ing, 5000);
  b := open_bill(t1, 'dine_in', 2);
  perform add_bill_line(b, cf, 150);
  perform add_bill_line(b, ts, 50);
  assert pay_bill(b, 'cash') = 150*29000 + 50*35000, 'tổng tiền bill sai';

  -- Đếm mù: nhân viên không đọc được sổ kho / kiểm kê / nhật ký
  select count(*) into n from stock_ledger;  assert n = 0, 'nhân viên đọc được sổ kho';
  select count(*) into n from stock_counts;  assert n = 0, 'nhân viên đọc được kiểm kê';
  select count(*) into n from audit_log;     assert n = 0, 'nhân viên đọc được nhật ký';
  select count(*) into n from v_expected_stock where expected_qty is not null; assert n = 0, 'nhân viên thấy tồn dự kiến';

  -- Thanh toán lần 2 (máy khác) phải báo lỗi
  begin perform pay_bill(b, 'cash'); raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm <> 'BILL_NOT_OPEN' then raise; end if; end;

  -- Mở bill thứ 2 cho cùng 1 bàn khi bàn đang có bill mở
  b2 := open_bill(t2, 'dine_in', 1);
  begin perform open_bill(t2, 'dine_in', 1); raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm <> 'TABLE_HAS_OPEN_BILL' then raise; end if; end;
  -- Không đóng ca khi còn bill mở / chưa đếm
  begin perform close_shift(0); raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm <> 'OPEN_BILLS_REMAIN' then raise; end if; end;
  perform cancel_open_bill(b2, 'Khách đổi ý');
  begin perform close_shift(0); raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm <> 'MISSING_CLOSE_COUNTS' then raise; end if; end;

  perform submit_stock_count(ing, 'close', 4500);
  perform close_shift(6100000 + 500000);
  reset session authorization;

  -- Đối soát (chủ)
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  select * into r from reconcile_shift(s1);
  assert r.actual_used = 8500, format('thực dùng phải 8500, được %s', r.actual_used);
  assert r.theoretical_used = 7000, format('lý thuyết phải 7000, được %s', r.theoretical_used);
  assert r.variance = 1500, 'chênh lệch phải 1500';
  assert r.variance_pct = 21.4, format('% phải 21.4, được %s', r.variance_pct);
  assert r.equiv_cups = 42.9, format('quy ra ly phải 42.9, được %s', r.equiv_cups);
  assert r.equiv_revenue = 1307143, format('quy ra tiền phải 1307143, được %s', r.equiv_revenue);
  assert r.status = 'alert', 'phải báo đỏ';
  raise notice 'BÀI 1 ĐÚNG: thực dùng %, lý thuyết %, chênh % (% %%), ~% ly, ~% đ, trạng thái %',
    r.actual_used, r.theoretical_used, r.variance, r.variance_pct, r.equiv_cups, r.equiv_revenue, r.status;
  -- Nhân viên bị chặn khỏi hàm đối soát
  reset session authorization;
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  begin perform * from reconcile_shift(s1); raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm <> 'OWNER_ONLY' then raise; end if; end;
  reset session authorization;

  ----------------------------------------------------------------
  -- BÀI 2: tồn cuối 6200 -> thực dùng 6800 -> chênh -200 (-2,9%)
  ----------------------------------------------------------------
  perform set_config('request.jwt.claim.sub', nv2, true); set local session authorization authenticated;
  s2 := open_shift(0);
  perform submit_stock_count(ing, 'open', 3000);
  perform add_purchase(ing, 5000);
  perform add_purchase(ing, 5000);
  b := open_bill(t1, 'dine_in', 2);
  perform add_bill_line(b, cf, 150);
  perform add_bill_line(b, ts, 50);
  perform pay_bill(b, 'transfer');

  -- Hủy bill đã thu tiền: sai PIN 3 lần -> khóa; (đúng PIN lần 4 vẫn bị khóa)
  assert cancel_paid_bill(b, '0000', 'Thử') = 'WRONG_PIN';
  assert cancel_paid_bill(b, '1111', 'Thử') = 'WRONG_PIN';
  assert cancel_paid_bill(b, '2222', 'Thử') = 'WRONG_PIN';
  assert cancel_paid_bill(b, '1234', 'Thử') = 'PIN_LOCKED', 'phải khóa sau 3 lần sai';
  reset session authorization;

  -- NV1 (chưa sai lần nào) nhập đúng PIN chủ -> hủy được, sổ kho được hoàn lại
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  assert cancel_paid_bill(b, '1234', 'Khách trả lại') = 'OK', 'nhập đúng PIN phải hủy được';
  reset session authorization;
  select count(*) into n from bills where id = b and status = 'cancelled' and approved_by is not null;
  assert n = 1, 'bill phải ở trạng thái hủy và có người duyệt';
  select coalesce(sum(qty_delta), 0) into n from stock_ledger where shift_id = s2 and kind in ('sale','void_sale');
  assert n = 0, 'hủy bill phải hoàn sổ kho về 0';

  -- Bán lại đúng như Bài 1 để đối soát Bài 2
  perform set_config('request.jwt.claim.sub', nv2, true); set local session authorization authenticated;
  b := open_bill(t1, 'dine_in', 2);
  perform add_bill_line(b, cf, 150);
  perform add_bill_line(b, ts, 50);
  perform pay_bill(b, 'cash');
  perform submit_stock_count(ing, 'close', 6200);
  perform close_shift(0);
  reset session authorization;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  select * into r from reconcile_shift(s2);
  assert r.actual_used = 6800 and r.theoretical_used = 7000, 'bài 2: thực dùng/lý thuyết sai';
  assert r.variance = -200 and r.variance_pct = -2.9, format('bài 2: chênh phải -200 (-2.9%%), được %s (%s)', r.variance, r.variance_pct);
  assert r.status = 'ok', 'bài 2: phải xanh (dưới 3%)';
  raise notice 'BÀI 2 ĐÚNG: chênh % (% %%), trạng thái %', r.variance, r.variance_pct, r.status;
  reset session authorization;

  ----------------------------------------------------------------
  -- Nhật ký / sổ kho không sửa, không xóa được (kể cả quyền quản trị)
  ----------------------------------------------------------------
  begin update audit_log set action = 'x'; raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm not like 'Bảng audit_log chỉ được thêm%' then raise; end if; end;
  begin delete from stock_ledger; raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm not like 'Bảng stock_ledger chỉ được thêm%' then raise; end if; end;
  begin delete from bills; raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm not like 'Không xóa dữ liệu bảng bills%' then raise; end if; end;
  begin update bill_lines set qty = 1; raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm not like 'Dòng bill chỉ được đánh dấu hủy%' then raise; end if; end;

  -- Nhân viên không sửa được menu/giá, không ghi trực tiếp vào bills
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  update menu_sizes set price = 1; get diagnostics n = row_count;
  assert n = 0, 'nhân viên sửa được giá!';
  begin insert into bills (shift_id, bill_type, opened_by) values (s1, 'take_away', (select id from staff limit 1));
        raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm not like '%permission denied%' then raise; end if; end;
  begin select pin_hash from staff; raise exception 'LẼ RA PHẢI LỖI';
  exception when others then if sqlerrm not like '%permission denied%' then raise; end if; end;
  reset session authorization;

  raise notice 'TẤT CẢ KIỂM THỬ ĐỀU ĐÚNG';
end
$test$;
