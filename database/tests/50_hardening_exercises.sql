-- Kiểm thử chặn sửa công thức đã bán (RECIPE_IN_USE, trong 002) và các hàm đóng/mở ca sau khi thêm khóa (003).
-- Chạy sau tests/00_supabase_stub.sql và 001..009. Đúng hết sẽ in "HARDENING: TAT CA DEU DUNG".
-- Test race 2 phiên song song: xem tests/51_concurrency.sh. KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
\set ON_ERROR_STOP on

truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts restart identity cascade;
delete from auth.users;
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán test');
insert into auth.users (id, email) values ('00000000-0000-0000-0000-0000000000a1', 'owner@test');
insert into staff (shop_id, auth_user_id, full_name, role) values ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner');
-- (đặt người đăng nhập mặc định = chủ để giá trị mặc định shop_id của các lệnh nạp dữ liệu bên dưới trỏ đúng quán)
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, unit, importance) values ('Sữa', 'ml', 'important'), ('Cà phê', 'g', 'important');
insert into menu_items (name) values ('Cà phê sữa'), ('Trà sữa');
insert into menu_sizes (item_id, size_name, price) select id, 'M', 29000 from menu_items;
insert into areas (name) values ('Tầng 1');
insert into dining_tables (area_id, name) select id, 'Bàn 1' from areas;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  sold uuid; unsold uuid; milk uuid; cafe uuid; s uuid; b uuid; b2 uuid; ln uuid; t1 uuid; msg text; n int;
begin
  select ms.id into sold   from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Cà phê sữa';
  select ms.id into unsold from menu_sizes ms join menu_items mi on mi.id = ms.item_id where mi.name = 'Trà sữa';
  select id into milk from ingredients where name = 'Sữa';
  select id into cafe from ingredients where name = 'Cà phê';
  select id into t1 from dining_tables;

  -- Chưa bán: sửa/xóa/thêm thoải mái
  insert into recipe_lines (size_id, ingredient_id, qty) values (sold, milk, 30), (unsold, milk, 50);
  update recipe_lines set qty = 35 where size_id = sold;
  update recipe_lines set qty = 30 where size_id = sold;
  insert into recipe_lines (size_id, ingredient_id, qty) values (unsold, cafe, 10);
  delete from recipe_lines where size_id = unsold and ingredient_id = cafe;

  -- Bán 1 ly của 'sold'
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  begin perform open_shift(null); raise exception 'LE RA PHAI LOI (open_shift NULL)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'OPENING_CASH_INVALID' then raise exception 'open_shift: mong OPENING_CASH_INVALID, nhan: %', msg; end if; end;
  s := open_shift(0);
  b := open_bill(t1, 'dine_in', 1); perform add_bill_line(b, sold, 1);
  begin perform pay_bill(b, null); raise exception 'LE RA PHAI LOI (pay_bill NULL)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'PAYMENT_METHOD_INVALID' then raise exception 'pay_bill: mong PAYMENT_METHOD_INVALID, nhan: %', msg; end if; end;
  perform pay_bill(b, 'cash');
  -- Giảm giá rồi hủy món: giảm giá vượt tạm tính thì pay_bill báo DISCOUNT_INVALID (không lỗi check constraint)
  b2 := open_bill(t1, 'dine_in', 1);
  ln := add_bill_line(b2, sold, 1); perform add_bill_line(b2, sold, 1);
  perform set_bill_discount(b2, 40000, 'Khách quen');
  perform void_bill_line(ln, 'Khách đổi ý');
  begin perform pay_bill(b2, 'cash'); raise exception 'LE RA PHAI LOI (giam gia vuot tam tinh)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'DISCOUNT_INVALID' then raise exception 'pay_bill: mong DISCOUNT_INVALID, nhan: %', msg; end if; end;
  perform cancel_open_bill(b2, 'Dọn bill thử');
  reset session authorization;

  -- Đã bán: sửa, xóa, thêm dòng, đổi size_id đều bị chặn với RECIPE_IN_USE
  begin update recipe_lines set qty = 99 where size_id = sold; raise exception 'LE RA PHAI LOI (update)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'RECIPE_IN_USE' then raise exception 'update: mong RECIPE_IN_USE, nhan: %', msg; end if; end;
  begin delete from recipe_lines where size_id = sold; raise exception 'LE RA PHAI LOI (delete)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'RECIPE_IN_USE' then raise exception 'delete: mong RECIPE_IN_USE, nhan: %', msg; end if; end;
  begin insert into recipe_lines (size_id, ingredient_id, qty) values (sold, cafe, 10); raise exception 'LE RA PHAI LOI (insert)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'RECIPE_IN_USE' then raise exception 'insert: mong RECIPE_IN_USE, nhan: %', msg; end if; end;
  begin update recipe_lines set size_id = unsold, ingredient_id = cafe where size_id = sold; raise exception 'LE RA PHAI LOI (doi size)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'RECIPE_IN_USE' then raise exception 'doi size: mong RECIPE_IN_USE, nhan: %', msg; end if; end;

  -- Đối chứng: công thức của size chưa bán vẫn sửa được, và công thức 'sold' còn nguyên
  update recipe_lines set qty = 60 where size_id = unsold;
  select count(*) into n from recipe_lines where size_id = sold and qty = 30;
  if n is distinct from 1 then raise exception 'Cong thuc size da ban bi thay doi (n=%)', n; end if;

  -- Cách đổi đúng: ẩn size cũ, tạo size mới
  update menu_sizes set active = false where id = sold;

  -- open_bill / close_shift sau khi thêm khóa vẫn chạy bình thường, và báo NO_OPEN_SHIFT khi chưa có ca
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  begin perform close_shift(0); raise exception 'LE RA PHAI LOI (close khi con bill? khong: phai thieu dem kho)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg not in ('MISSING_CLOSE_COUNTS') then raise exception 'close_shift: mong MISSING_CLOSE_COUNTS, nhan: %', msg; end if; end;
  perform submit_stock_count(milk, 'close', 0);
  perform submit_stock_count(cafe, 'close', 0);
  begin perform close_shift(null); raise exception 'LE RA PHAI LOI (close_shift NULL)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'CLOSING_CASH_INVALID' then raise exception 'close_shift: mong CLOSING_CASH_INVALID, nhan: %', msg; end if; end;
  perform close_shift(29000);
  begin perform open_bill(t1, 'dine_in', 1); raise exception 'LE RA PHAI LOI (open_bill khi khong co ca)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'NO_OPEN_SHIFT' then raise exception 'open_bill: mong NO_OPEN_SHIFT, nhan: %', msg; end if; end;
  begin perform close_shift(0); raise exception 'LE RA PHAI LOI (close khi khong co ca)';
  exception when others then get stacked diagnostics msg = message_text;
    if msg <> 'NO_OPEN_SHIFT' then raise exception 'close_shift: mong NO_OPEN_SHIFT, nhan: %', msg; end if; end;
  reset session authorization;

  -- Ràng buộc ở bảng phải giữ invariant ngay cả khi không đi qua RPC.
  begin update bills set payment_method = null where id = b;
    raise exception 'LE RA PHAI LOI (paid bill thieu payment_method)';
  exception when check_violation then null; end;
  begin update shifts set closing_cash = null where id = s;
    raise exception 'LE RA PHAI LOI (closed shift thieu closing_cash)';
  exception when check_violation then null; end;

  raise notice 'HARDENING: TAT CA DEU DUNG';
end $test$;
