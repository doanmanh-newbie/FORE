-- Kiểm thử module KHO v2 (07_inventory.sql): phiếu nhập, giá bình quân, lô hàng, đếm mù + duyệt điều chỉnh,
-- hao hụt theo lô, gợi ý nhập, quyền chủ / nhân viên.
-- Chạy sau tests/00_supabase_stub.sql và 01..08 (hàm Kho đọc quyền theo vai trò từ 08): psql -d fore_test -v ON_ERROR_STOP=1 -f tests/91_inventory.sql
-- Đúng hết sẽ in "INVENTORY: TAT CA DEU DUNG". KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
\set ON_ERROR_STOP on

-- CHỐT CHẶN: file này xóa sạch dữ liệu (truncate + xóa auth.users). Tự dừng nếu thấy đây là Supabase.
do $guard$ begin
  if exists (select 1 from pg_roles where rolname in ('supabase_admin', 'supabase_auth_admin')) then
    raise exception 'DUNG LAI: day la Supabase. File test nay xoa sach du lieu, chi chay tren Postgres TEST rieng.';
  end if;
end $guard$;


truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts, menu_categories, recipe_versions,
         price_changes, menu_events restart identity cascade;
delete from auth.users;
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán A');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, group_name, unit, importance) values
  ('Sữa tươi', 'Sữa', 'ml', 'important'), ('Đường', 'Khác', 'g', 'normal');

create or replace function pg_temp.expect_err(p_sql text, p_code text) returns void language plpgsql as $f$
declare msg text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics msg = message_text;
    if msg <> p_code then raise exception 'cho loi %, nhan duoc % (lenh: %)', p_code, msg, p_sql; end if;
    return;
  end;
  raise exception 'cho loi %, nhung lenh chay thanh cong: %', p_code, p_sql;
end $f$;

create or replace function pg_temp.stk(p uuid) returns integer language sql as $f$
  select (inv_ingredient_profile(p)->>'stock')::int
$f$;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  milk uuid; sugar uuid; sup uuid; grp uuid; j jsonb; po jsonb; po2 jsonb; po3 jsonb; k jsonb; sh uuid;
  n numeric; cost numeric; stock integer; kid uuid; line_id uuid; w jsonb;
begin
  select id into milk from ingredients where name = 'Sữa tươi';
  select id into sugar from ingredients where name = 'Đường';

  -- ===== Quyền: nhân viên không vào các hàm của chủ =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  perform pg_temp.expect_err('select inv_overview()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err('select inv_catalog()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err('select sup_list()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err('select po_suggestions()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err('select st_list()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err($$select sup_save(null, '{"name":"X"}')$$, 'OWNER_ONLY');
  reset session authorization;

  -- ===== Chủ: nhà cung cấp, nhóm, nguyên liệu =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  sup := sup_save(null, '{"name":"Vinamilk","phone":"0901234567","lead_days":1,"order_cutoff":"16:00"}');
  perform pg_temp.expect_err($$select sup_save(null, '{"name":"vinamilk"}')$$, 'NAME_EXISTS');
  perform pg_temp.expect_err($$select sup_save(null, '{"name":"  "}')$$, 'NAME_REQUIRED');
  perform pg_temp.expect_err($$select sup_save(null, '{"name":"Y","email":"khong-hop-le"}')$$, 'EMAIL_INVALID');
  grp := inv_group_save(null, 'Đồ khô');
  perform pg_temp.expect_err($$select inv_group_save(null, 'đồ khô')$$, 'NAME_EXISTS');
  perform inv_ingredient_save(milk, jsonb_build_object('name', 'Sữa tươi', 'default_supplier_id', sup, 'min_stock_qty', 5000,
                                                       'importance', 'important'));
  perform pg_temp.expect_err(format($$select inv_ingredient_save(%L, '{"name":"Sữa tươi","unit":"g"}')$$, milk), 'UNIT_INVALID');

  -- ===== Phiếu nhập của chủ: giá bình quân gia quyền =====
  po := po_save(null, jsonb_build_object('supplier_id', sup, 'lines', jsonb_build_array(
          jsonb_build_object('ingredient_id', milk, 'qty', 30000, 'unit_price', 50, 'lot_code', 'ST-0511', 'expiry_date', '2030-01-01'))), false);
  if po->>'status' <> 'draft' or po->>'code' !~ '^PN-' then raise exception 'phieu nhap phai o dang nhap va co ma PN-'; end if;
  perform pg_temp.expect_err(format($$select po_save(%L, '{"supplier_id":"%s","lines":[{"ingredient_id":"%s","qty":1000}]}', true)$$, po->>'id', sup, milk), 'PRICE_REQUIRED');
  perform pg_temp.expect_err($$select po_save(null, '{"lines":[{"ingredient_id":"00000000-0000-0000-0000-000000000000","qty":1,"unit_price":1}]}', false)$$, 'NOT_FOUND');
  perform pg_temp.expect_err(format($$select po_save(null, '{"lines":[{"ingredient_id":"%s","qty":0,"unit_price":1}]}', false)$$, milk), 'QTY_INVALID');
  po := po_save((po->>'id')::uuid, jsonb_build_object('supplier_id', sup, 'lines', jsonb_build_array(
          jsonb_build_object('ingredient_id', milk, 'qty', 30000, 'unit_price', 50, 'lot_code', 'ST-0511', 'expiry_date', '2030-01-01'))), true);
  if po->>'status' <> 'confirmed' then raise exception 'phieu phai da xac nhan'; end if;
  select unit_cost into cost from ingredients where id = milk;
  if cost <> 50 then raise exception 'gia binh quan dau tien phai la 50, nhan %', cost; end if;
  stock := pg_temp.stk(milk);
  if stock <> 30000 then raise exception 'ton sau nhap phai la 30000, nhan %', stock; end if;
  perform pg_temp.expect_err(format($$select po_save(%L, '{"lines":[]}', false)$$, po->>'id'), 'ORDER_NOT_DRAFT');

  po2 := po_save(null, jsonb_build_object('supplier_id', sup, 'lines', jsonb_build_array(
          jsonb_build_object('ingredient_id', milk, 'qty', 10000, 'unit_price', 60, 'lot_code', 'ST-0611', 'expiry_date', '2030-02-01'))), false);
  k := po_impact((po2->>'id')::uuid);
  if (k->'items'->0->>'avg_after')::numeric <> 52.5 then raise exception 'tac dong gia: bình quân sau nhap phai la 52.5, nhan %', k->'items'->0->>'avg_after'; end if;
  if (k->'items'->0->>'stock_after')::int <> 40000 then raise exception 'ton sau nhap du bao phai la 40000'; end if;
  perform po_save((po2->>'id')::uuid, jsonb_build_object('supplier_id', sup, 'lines', jsonb_build_array(
          jsonb_build_object('ingredient_id', milk, 'qty', 10000, 'unit_price', 60, 'lot_code', 'ST-0611', 'expiry_date', '2030-02-01'))), true);
  select unit_cost into cost from ingredients where id = milk;
  if cost <> 52.5 then raise exception 'gia binh quan sau phieu 2 phai la 52.5, nhan %', cost; end if;
  select last_purchase_cost into cost from ingredients where id = milk;
  if cost <> 60 then raise exception 'gia nhap gan nhat phai la 60'; end if;
  if (select count(*) from ingredient_cost_events where ingredient_id = milk) <> 2 then raise exception 'phai co 2 su kien gia'; end if;

  reset session authorization;

  -- ===== Nhân viên: nhận hàng nhanh cần ca mở; không thấy giá =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  perform pg_temp.expect_err(format($$select po_save(null, '{"supplier_id":"%s","lines":[{"ingredient_id":"%s","qty":2000}]}', true)$$, sup, sugar), 'NO_OPEN_SHIFT');
  reset session authorization;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  sh := open_shift(0);
  -- Lô còn lại: hao hụt 5000 từ lô cũ (ghi bằng tên chủ, trong ca vừa mở)
  w := inv_waste_add(milk, 5000, 'expired', null, (select id from stock_lots where code = 'ST-0511'));
  reset session authorization;

  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  w := inv_waste_add(milk, 1000, 'spill', 'Rơi vãi khi pha', null);
  if w->>'code' !~ '^HH-' then raise exception 'hao hut phai co ma HH-'; end if;
  perform pg_temp.expect_err(format($$select inv_waste_add(%L, 0, 'spill')$$, milk), 'QTY_INVALID');
  perform pg_temp.expect_err(format($$select inv_waste_add(%L, 10, 'khong-co')$$, milk), 'WASTE_TYPE_INVALID');
  po3 := po_save(null, jsonb_build_object('supplier_id', sup, 'lines', jsonb_build_array(
           jsonb_build_object('ingredient_id', sugar, 'qty', 5000, 'unit_price', 999))), true);
  if po3->>'needs_pricing' <> 'true' then raise exception 'phieu nhan vien phai cho bo sung gia'; end if;
  if po3->'lines'->0->>'unit_price' is not null or po3->>'total_amount' is not null then raise exception 'nhan vien khong duoc thay gia'; end if;
  if (select unit_cost from ingredients where id = sugar) is not null then raise exception 'gia khong duoc doi khi nhan vien nhan hang'; end if;
  line_id := (po3->'lines'->0->>'id')::uuid;
  perform pg_temp.expect_err(format($$select po_set_prices(%L, '[]')$$, po3->>'id'), 'OWNER_ONLY');
  reset session authorization;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform po_set_prices((po3->>'id')::uuid, jsonb_build_array(jsonb_build_object('line_id', line_id, 'unit_price', 20)));
  if (select unit_cost from ingredients where id = sugar) <> 20 then raise exception 'sau khi bo sung gia, gia binh quan phai la 20'; end if;
  if (select needs_pricing from purchase_orders where id = (po3->>'id')::uuid) then raise exception 'het cho gia'; end if;
  j := inv_ingredient_profile(milk);
  if (j->>'stock')::int <> 34000 then raise exception 'ton sua phai la 34000 (40000 - 5000 - 1000), nhan %', j->>'stock'; end if;
  if (select (l->>'qty_remaining')::int from jsonb_array_elements(j->'lots') l where l->>'code' = 'ST-0611') <> 10000 then
    raise exception 'lo moi nhat phai con du 10000'; end if;
  if (select (l->>'qty_remaining')::int from jsonb_array_elements(j->'lots') l where l->>'code' = 'ST-0511') <> 24000 then
    raise exception 'lo cu phai con 24000'; end if;
  reset session authorization;

  -- ===== Kiểm kê mù: nhân viên không thấy số hệ thống; chủ duyệt điều chỉnh có lý do =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  k := st_start();
  kid := (k->>'id')::uuid;
  if (st_start()->>'resumed') <> 'true' then raise exception 'st_start lan hai phai tiep tuc phieu nhap'; end if;
  j := st_sheet(kid);
  if j::text like '%system_qty%' then raise exception 'phieu dem mu khong duoc lo so he thong'; end if;
  perform pg_temp.expect_err(format('select st_submit(%L)', kid), 'COUNT_INCOMPLETE');
  perform st_save(kid, jsonb_build_array(jsonb_build_object('ingredient_id', milk, 'counted_qty', 33000),
                                         jsonb_build_object('ingredient_id', sugar, 'counted_qty', 5000)));
  perform st_submit(kid);
  perform pg_temp.expect_err(format($$select st_save(%L, '[]')$$, kid), 'STOCKTAKE_LOCKED');
  reset session authorization;

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  j := st_detail(kid);
  if (select (l->>'variance')::int from jsonb_array_elements(j->'lines') l where l->>'name' = 'Sữa tươi') <> -1000 then
    raise exception 'chenh lech sua phai la -1000'; end if;
  perform pg_temp.expect_err(format($$select st_approve(%L, '[]', '')$$, kid), 'REASON_REQUIRED');
  k := st_approve(kid, jsonb_build_array(jsonb_build_object('ingredient_id', milk, 'decision', 'adjust')), 'Hao hụt chưa ghi', null);
  if (k->>'adjusted_lines')::int <> 1 then raise exception 'phai dieu chinh 1 dong'; end if;
  if pg_temp.stk(milk) <> 33000 then raise exception 'ton sua sau dieu chinh phai khop so dem 33000, nhan %', pg_temp.stk(milk); end if;
  if not exists (select 1 from stock_ledger where kind = 'adjust' and ref_id = kid and qty_delta = -1000 and shift_id is null) then
    raise exception 'phai co dong dieu chinh trong so kho'; end if;
  if exists (select 1 from waste_logs where code is null) then raise exception 'khong duoc tao hao hut khi dieu chinh'; end if;
  perform pg_temp.expect_err(format($$select st_approve(%L, '[]', 'lan hai')$$, kid), 'STOCKTAKE_LOCKED');

  -- ===== Gợi ý nhập: sữa còn 33000 > ngưỡng 5000 nên chưa gợi ý; hạ tồn xuống dưới ngưỡng thì có =====
  j := po_suggestions();
  if jsonb_array_length(j->'items') <> 0 then raise exception 'chua can goi y nhap luc ton con du'; end if;
  perform inv_ingredient_save(milk, jsonb_build_object('name', 'Sữa tươi', 'min_stock_qty', 40000, 'default_supplier_id', sup));
  j := po_suggestions();
  if jsonb_array_length(j->'items') <> 1 or (j->'items'->0->>'suggested_qty')::int <= 0 then raise exception 'phai goi y nhap sua'; end if;
  j := po_from_suggestions(jsonb_build_array(jsonb_build_object('ingredient_id', milk, 'qty', 20000, 'supplier_id', sup)));
  if jsonb_array_length(j) <> 1 then raise exception 'phai tao 1 phieu nhap tu goi y'; end if;
  if (select status from purchase_orders where id = (j->0->>'id')::uuid) <> 'draft' then raise exception 'phieu tu goi y phai la nhap'; end if;

  -- ===== Tổng quan, hao hụt, đổi quán: có số liệu và không lỗi =====
  j := inv_overview();
  if (j->>'stock_value')::bigint <= 0 then raise exception 'gia tri ton phai > 0'; end if;
  j := inv_waste_overview(current_date - 6, current_date + 1);
  if (j->>'total_value')::bigint <= 0 then raise exception 'hao hut phai > 0'; end if;
  j := inv_week_review(current_date - 6, current_date + 1);
  if (j->>'orders_confirmed')::int < 3 then raise exception 'tuan phai co it nhat 3 phieu nhap'; end if;
  if jsonb_array_length(inv_shops_snapshot()) <> 1 then raise exception 'chu co 1 quan'; end if;
  if jsonb_array_length(inv_catalog()) <> 2 then raise exception 'danh muc phai co 2 nguyen lieu'; end if;
  perform pg_temp.expect_err(format('select inv_ingredient_set_active(%L, false)', milk), 'STOCK_NOT_EMPTY');
  reset session authorization;

  raise notice 'INVENTORY: TAT CA DEU DUNG';
end $test$;
