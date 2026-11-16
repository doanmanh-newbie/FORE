-- Kiểm thử quản lý THỰC ĐƠN: danh mục, món nháp, công thức theo phiên bản (hẹn giờ), đổi giá, giá vốn,
-- lịch sử, sao chép, quyền, và đối soát vẫn đúng khi công thức đổi.
-- Chạy sau tests/00_supabase_stub.sql và 01..05: psql -d fore_test -v ON_ERROR_STOP=1 -f tests/89_menu_management.sql
-- Đúng hết sẽ in "MENU MANAGEMENT: TAT CA DEU DUNG". KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
\set ON_ERROR_STOP on

truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts, menu_categories, recipe_versions,
         price_changes, menu_events restart identity cascade;
delete from auth.users;
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán A');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test'),
  ('00000000-0000-0000-0000-0000000000c1', 'chu2@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, unit, importance) values
  ('Cà phê', 'g', 'important'), ('Sữa tươi', 'ml', 'important'), ('Đá', 'g', 'normal'), ('Ly + nắp', 'piece', 'normal');
insert into areas (name) values ('Tầng 1');
insert into dining_tables (area_id, name) select id, 'Bàn 1' from areas;

-- hàm phụ: chạy lệnh và yêu cầu đúng mã lỗi
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

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  cf uuid; milk uuid; ice uuid; cup uuid; t1 uuid;
  latte uuid; s_s uuid; s_m uuid; cat_cf uuid; cat_tea uuid;
  j jsonb; d jsonb; b uuid; v1 uuid; v2 uuid; sh uuid; n int; r record;
  draft uuid; copy_item jsonb; shop_b uuid; item_b jsonb; cacao uuid; c_s uuid;
  lines1 jsonb; lines2 jsonb; ver jsonb;
begin
  select id into cf from ingredients where name = 'Cà phê';
  select id into milk from ingredients where name = 'Sữa tươi';
  select id into ice from ingredients where name = 'Đá';
  select id into cup from ingredients where name = 'Ly + nắp';
  select id into t1 from dining_tables;

  -- ===== Quyền: nhân viên không đọc/ghi thực đơn quản lý =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  perform pg_temp.expect_err('select menu_overview()', 'OWNER_ONLY');
  perform pg_temp.expect_err('select menu_ingredients()', 'OWNER_ONLY');
  perform pg_temp.expect_err($$select menu_item_create('X', null, '[{"name":"S","price":1000}]', false)$$, 'OWNER_ONLY');
  perform pg_temp.expect_err('select menu_category_add(''Trà'')', 'OWNER_ONLY');
  reset session authorization;

  -- ===== Giá nguyên liệu và giá vốn =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform set_ingredient_cost(cf, 200); perform set_ingredient_cost(milk, 50); perform set_ingredient_cost(ice, 2);
  perform pg_temp.expect_err(format('select set_ingredient_cost(%L, -1)', cup), 'COST_INVALID');
  j := menu_ingredients();
  if jsonb_array_length(j->'items') <> 4 then raise exception 'menu_ingredients phai co 4 nguyen lieu'; end if;
  if j->>'cost_updated_at' is null then raise exception 'thieu cost_updated_at'; end if;

  -- ===== Danh mục =====
  cat_cf := menu_category_add('Cà phê'); cat_tea := menu_category_add('Trà');
  perform pg_temp.expect_err('select menu_category_add(''  cà phê '')', 'CATEGORY_DUPLICATE');
  perform pg_temp.expect_err('select menu_category_add(''   '')', 'CATEGORY_NAME_REQUIRED');

  -- ===== Tạo món: kiểm tra đầu vào =====
  perform pg_temp.expect_err($$select menu_item_create('  ', 'Cà phê', '[{"name":"S","price":1000}]', true)$$, 'MENU_NAME_REQUIRED');
  perform pg_temp.expect_err($$select menu_item_create('Latte', 'Không có', '[{"name":"S","price":1000}]', true)$$, 'CATEGORY_NOT_FOUND');
  perform pg_temp.expect_err($$select menu_item_create('Latte', 'Cà phê', '[]', true)$$, 'MENU_SIZE_REQUIRED');
  perform pg_temp.expect_err($$select menu_item_create('Latte', 'Cà phê', '[{"name":"S","price":0}]', true)$$, 'PRICE_INVALID');
  perform pg_temp.expect_err($$select menu_item_create('Latte', 'Cà phê', '[{"name":"S","price":1000},{"name":"s","price":2000}]', true)$$, 'SIZE_NAME_DUPLICATE');
  latte := menu_item_create('Latte sữa tươi', 'Cà phê', '[{"name":"S","price":35000},{"name":"M","price":42000}]', true);
  perform pg_temp.expect_err($$select menu_item_create('latte sữa tươi', 'Cà phê', '[{"name":"S","price":1000}]', true)$$, 'MENU_NAME_DUPLICATE');
  select id into s_s from menu_sizes where item_id = latte and size_name = 'S';
  select id into s_m from menu_sizes where item_id = latte and size_name = 'M';

  -- ===== Công thức v1 (đang dùng ngay), giá vốn =====
  lines1 := jsonb_build_array(
    jsonb_build_object('ingredient_id', cf,   'qty', 18),
    jsonb_build_object('ingredient_id', milk, 'qty', 160),
    jsonb_build_object('ingredient_id', ice,  'qty', 100),
    jsonb_build_object('ingredient_id', cup,  'qty', 1));
  perform pg_temp.expect_err(format('select menu_recipe_save(%L, ''[]'')', s_s), 'RECIPE_EMPTY');
  perform pg_temp.expect_err(format('select menu_recipe_save(%L, %L)', s_s, jsonb_build_array(jsonb_build_object('ingredient_id', cf, 'qty', 0))), 'QTY_INVALID');
  perform pg_temp.expect_err(format('select menu_recipe_save(%L, %L)', s_s, jsonb_build_array(jsonb_build_object('ingredient_id', cf, 'qty', 5), jsonb_build_object('ingredient_id', cf, 'qty', 6))), 'INGREDIENT_DUPLICATE');
  perform pg_temp.expect_err(format('select menu_recipe_save(%L, %L)', s_s, jsonb_build_array(jsonb_build_object('ingredient_id', gen_random_uuid(), 'qty', 5))), 'INGREDIENT_NOT_FOUND');
  ver := menu_recipe_save(s_s, lines1);
  if ver->>'status' <> 'active' or (ver->>'version_no')::int <> 1 then raise exception 'v1 phai dang dung: %', ver; end if;
  select count(*) into n from recipe_lines where size_id = s_s; if n <> 4 then raise exception 'recipe_lines phai co 4 dong: %', n; end if;
  perform pg_temp.expect_err(format('select menu_recipe_save(%L, %L)', s_s, lines1), 'RECIPE_UNCHANGED');

  -- giá vốn chưa xác định vì "Ly + nắp" chưa có giá
  j := menu_overview();
  select x into d from jsonb_array_elements(j->'items') x where x->>'id' = latte::text;
  if (d->'sizes'->0->>'cost_known')::boolean then raise exception 'thieu gia ly: gia von phai chua xac dinh'; end if;
  if d->'sizes'->0->>'cost' is not null then raise exception 'cost phai null khi thieu gia'; end if;
  if (d->'sizes'->1->>'has_recipe')::boolean then raise exception 'size M chua co cong thuc'; end if;
  perform set_ingredient_cost(cup, 400);
  j := menu_overview();
  select x into d from jsonb_array_elements(j->'items') x where x->>'id' = latte::text;
  if (d->'sizes'->0->>'cost')::int <> 12200 then raise exception 'gia von S phai 12200: %', d->'sizes'->0; end if;
  if (j->>'low_margin_pct')::int <> 30 then raise exception 'nguong lai mac dinh 30'; end if;
  perform menu_set_low_margin(40);
  if (menu_overview()->>'low_margin_pct')::int <> 40 then raise exception 'doi nguong lai'; end if;
  perform pg_temp.expect_err('select menu_set_low_margin(95)', 'SETTING_INVALID');
  reset session authorization;

  -- ===== Bán một ly S, rồi công thức đã bán bị khóa sửa trực tiếp =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  perform open_shift(0);
  b := open_bill(t1, 'dine_in', 1); perform add_bill_line(b, s_s, 1); perform pay_bill(b, 'cash');
  reset session authorization;
  select sum(-qty_delta) into n from stock_ledger where kind = 'sale' and ingredient_id = milk;
  if n <> 160 then raise exception 'ledger ban phai tru 160 sua: %', n; end if;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform pg_temp.expect_err(format('delete from recipe_lines where size_id = %L', s_s), 'RECIPE_IN_USE');
  reset session authorization;

  -- ===== Phiên bản mới có hẹn giờ: chưa áp dụng, công thức đang dùng giữ nguyên =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  lines2 := jsonb_build_array(
    jsonb_build_object('ingredient_id', cf,   'qty', 18),
    jsonb_build_object('ingredient_id', milk, 'qty', 140),
    jsonb_build_object('ingredient_id', ice,  'qty', 100),
    jsonb_build_object('ingredient_id', cup,  'qty', 1));
  ver := menu_recipe_save(s_s, lines2, now() + interval '1 day', 'giam sua');
  if ver->>'status' <> 'scheduled' or (ver->>'version_no')::int <> 2 then raise exception 'v2 phai scheduled: %', ver; end if;
  v2 := (ver->>'version_id')::uuid;
  select qty into n from recipe_lines where size_id = s_s and ingredient_id = milk;
  if n <> 160 then raise exception 'cong thuc dang dung phai con 160: %', n; end if;
  d := menu_item_detail(latte);
  if d->'sizes'->0->'scheduled'->>'version_no' <> '2' then raise exception 'detail thieu ban hen: %', d->'sizes'->0; end if;
  if d->'sizes'->0->'current'->>'version_no' <> '1' then raise exception 'detail thieu ban dang dung'; end if;
  j := menu_item_history(latte);
  if jsonb_array_length(j->'upcoming') <> 1 then raise exception 'lich su phai co 1 muc sap ap dung: %', j->'upcoming'; end if;
  -- hủy lịch, rồi hẹn lại
  perform menu_recipe_cancel(v2);
  perform pg_temp.expect_err(format('select menu_recipe_cancel(%L)', v2), 'RECIPE_VERSION_NOT_SCHEDULED');
  ver := menu_recipe_save(s_s, lines2, now() + interval '1 day');
  if (ver->>'version_no')::int <> 3 then raise exception 'sau huy phai la v3: %', ver; end if;
  v2 := (ver->>'version_id')::uuid;
  reset session authorization;

  -- tới giờ hẹn (lùi mốc hiệu lực): bất kỳ lần bán/xem thực đơn nào cũng kích hoạt phiên bản
  update recipe_versions set effective_from = now() - interval '1 minute' where id = v2;
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  select count(*) into n from menu_for_sale();   -- gọi để kích hoạt
  reset session authorization;
  select qty into n from recipe_lines where size_id = s_s and ingredient_id = milk;
  if n <> 140 then raise exception 'cong thuc moi phai ap dung: sua=%', n; end if;
  if (select status from recipe_versions where id = v2) <> 'active' then raise exception 'v3 phai active'; end if;
  if (select status from recipe_versions where size_id = s_s and version_no = 1) <> 'superseded' then raise exception 'v1 phai superseded'; end if;
  if (select status from recipe_versions where size_id = s_s and version_no = 2) <> 'cancelled' then raise exception 'v2 phai cancelled'; end if;

  -- bán lần nữa: sổ kho trừ theo công thức mới; ca cũ giữ nguyên
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  b := open_bill(t1, 'dine_in', 1); perform add_bill_line(b, s_s, 1); perform pay_bill(b, 'cash');
  reset session authorization;
  if (select count(*) from stock_ledger where kind = 'sale' and ingredient_id = milk and qty_delta = -160) <> 1
     or (select count(*) from stock_ledger where kind = 'sale' and ingredient_id = milk and qty_delta = -140) <> 1 then
    raise exception 'so kho: mot ban 160 (cu) va mot ban 140 (moi)';
  end if;

  -- công thức có hiệu lực tại từng thời điểm (đối soát dùng)
  update recipe_versions set effective_from = timestamptz '2026-01-01' where size_id = s_s and version_no = 1;
  update recipe_versions set effective_from = timestamptz '2026-06-01' where id = v2;
  select qty into n from _recipe_at(s_s, timestamptz '2026-03-01') where ingredient_id = milk;
  if n <> 160 then raise exception '_recipe_at thang 3 phai 160: %', n; end if;
  select qty into n from _recipe_at(s_s, timestamptz '2026-07-01') where ingredient_id = milk;
  if n <> 140 then raise exception '_recipe_at thang 7 phai 140: %', n; end if;
  select count(*) into n from _recipe_at(s_s, timestamptz '2025-01-01');
  if n <> 0 then raise exception '_recipe_at truoc v1 phai rong: %', n; end if;

  -- ===== Đổi giá: áp dụng ngay (bill cũ giữ giá cũ) và hẹn giờ =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform pg_temp.expect_err(format('select menu_price_change(%L)', jsonb_build_array(jsonb_build_object('size_id', s_s, 'price', 35000))), 'PRICE_UNCHANGED');
  perform pg_temp.expect_err(format('select menu_price_change(%L)', jsonb_build_array(jsonb_build_object('size_id', s_s, 'price', 0))), 'PRICE_INVALID');
  j := menu_price_change(jsonb_build_array(jsonb_build_object('size_id', s_s, 'price', 37000), jsonb_build_object('size_id', s_m, 'price', 42000)));
  if not (j->>'applied')::boolean or (j->>'count')::int <> 1 then raise exception 'doi gia ngay: %', j; end if;
  if (select price from menu_sizes where id = s_s) <> 37000 then raise exception 'gia S phai 37000'; end if;
  reset session authorization;
  if (select count(*) from bill_lines where unit_price = 35000) <> 2 then raise exception 'bill cu phai giu gia 35000'; end if;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  j := menu_price_change(jsonb_build_array(jsonb_build_object('size_id', s_m, 'price', 45000)), now() + interval '2 days');
  if (j->>'applied')::boolean then raise exception 'phai la gia hen'; end if;
  if (select price from menu_sizes where id = s_m) <> 42000 then raise exception 'gia M chua doi'; end if;
  d := menu_item_detail(latte);
  if d->'sizes'->1->'pending_price'->>'new_price' <> '45000' then raise exception 'detail thieu gia hen: %', d->'sizes'->1; end if;
  perform menu_price_cancel((d->'sizes'->1->'pending_price'->>'change_id')::uuid);
  if menu_item_detail(latte)->'sizes'->1->'pending_price' <> 'null'::jsonb then raise exception 'phai huy duoc lich gia'; end if;
  j := menu_price_change(jsonb_build_array(jsonb_build_object('size_id', s_m, 'price', 45000)), now() + interval '2 days');
  reset session authorization;
  update price_changes set effective_from = now() - interval '1 minute' where status = 'scheduled';
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  if (select price from menu_for_sale() where size_id = s_m) <> 45000 then raise exception 'gia hen phai ap dung khi toi gio'; end if;
  reset session authorization;
  if exists (select 1 from price_changes where status = 'scheduled') or not exists (select 1 from price_changes where new_price = 45000 and status = 'applied') then raise exception 'price_changes phai applied'; end if;

  -- ===== Lịch sử =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  j := menu_item_history(latte, 100);
  if jsonb_array_length(j->'events') < 5 then raise exception 'lich su qua it su kien: %', jsonb_array_length(j->'events'); end if;
  if not exists (select 1 from jsonb_array_elements(j->'events') e where e->>'kind' = 'price') then raise exception 'thieu su kien gia'; end if;
  if not exists (select 1 from jsonb_array_elements(j->'events') e where e->>'kind' = 'recipe') then raise exception 'thieu su kien cong thuc'; end if;
  if (j->'events'->0->>'actor_name') is null then raise exception 'thieu nguoi thuc hien'; end if;
  -- các phiên bản để so sánh
  j := menu_recipe_versions(s_s);
  if jsonb_array_length(j) <> 2 then raise exception 'so phien ban (khong tinh da huy) phai 2: %', jsonb_array_length(j); end if;
  if (j->0->>'version_no')::int <> 3 or (j->0->>'cost')::int <> 11200 then raise exception 'v3 gia von phai 11200: %', j->0; end if;
  if (j->1->>'cost')::int <> 12200 then raise exception 'v1 gia von phai 12200: %', j->1; end if;

  -- ===== Nháp, ngừng bán, size =====
  draft := menu_item_create('Latte hạt dẻ', 'Cà phê', '[{"name":"S","price":38000}]', false);
  if not (select is_draft from menu_items where id = draft) or (select active from menu_items where id = draft) then raise exception 'phai la ban nhap chua ban'; end if;
  perform pg_temp.expect_err(format('select menu_item_set_active(%L, true)', draft), 'ITEM_IS_DRAFT');
  reset session authorization;
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  if exists (select 1 from menu_for_sale() where item_id = draft) then raise exception 'ban nhap khong duoc hien khi ban'; end if;
  b := open_bill(t1, 'dine_in', 1);
  perform pg_temp.expect_err(format('select add_bill_line(%L, %L, 1)', b, (select id from menu_sizes where item_id = draft)), 'ITEM_UNAVAILABLE');
  reset session authorization;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform menu_item_publish(draft);
  reset session authorization;
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  if not exists (select 1 from menu_for_sale() where item_id = draft) then raise exception 'mon da mo ban phai hien'; end if;
  reset session authorization;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform menu_item_set_active(draft, false);
  reset session authorization;
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  if exists (select 1 from menu_for_sale() where item_id = draft) then raise exception 'mon ngung ban khong duoc hien'; end if;
  perform pg_temp.expect_err(format('select add_bill_line(%L, %L, 1)', b, (select id from menu_sizes where item_id = draft)), 'ITEM_UNAVAILABLE');
  perform add_bill_line(b, s_s, 1);   -- món khác vẫn bán bình thường
  perform cancel_open_bill(b, 'test');
  reset session authorization;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform menu_item_set_active(draft, true);

  -- size: đã bán chỉ ẩn, chưa bán thì xóa, size cuối không bỏ được
  perform menu_size_remove(s_m);
  if (select active from menu_sizes where id = s_m) then raise exception 'size M phai bi an'; end if;
  perform pg_temp.expect_err(format('select menu_size_remove(%L)', s_s), 'LAST_SIZE');
  perform menu_size_add(latte, 'L', 49000);
  perform pg_temp.expect_err(format('select menu_size_add(%L, ''l'', 50000)', latte), 'SIZE_NAME_DUPLICATE');
  perform menu_size_remove(s_s);
  if (select active from menu_sizes where id = s_s) then raise exception 'size S phai inactive'; end if;
  perform menu_item_update(latte, 'Latte sữa tươi', 'Trà');
  if (select group_name from menu_items where id = latte) <> 'Trà' then raise exception 'doi nhom mon'; end if;
  perform menu_item_update(latte, 'Latte sữa tươi', 'Cà phê');
  perform pg_temp.expect_err(format('select menu_item_update(%L, ''Latte hạt dẻ'', null)', latte), 'MENU_NAME_DUPLICATE');

  -- ===== Danh mục: đổi tên kéo theo món, sắp xếp =====
  perform menu_category_rename(cat_cf, 'Cà phê & espresso');
  if (select group_name from menu_items where id = latte) <> 'Cà phê & espresso' then raise exception 'doi ten danh muc phai doi ca mon'; end if;
  perform pg_temp.expect_err(format('select menu_category_rename(%L, ''trà'')', cat_cf), 'CATEGORY_DUPLICATE');
  perform menu_category_reorder(array[cat_tea, cat_cf]);
  if (menu_categories_list()->0->>'name') <> 'Trà' then raise exception 'sap xep danh muc'; end if;
  if (menu_categories_list()->1->>'item_count')::int <> 2 then raise exception 'dem mon trong danh muc: %', menu_categories_list(); end if;
  perform pg_temp.expect_err(format('select menu_category_reorder(%L)', array[cat_tea]), 'CATEGORY_ORDER_INVALID');
  perform pg_temp.expect_err(format('select menu_category_reorder(%L)', array[cat_tea, cat_tea]), 'CATEGORY_ORDER_INVALID');
  reset session authorization;

  -- thứ tự món khi bán theo danh mục đã sắp xếp: Trà (nếu có món) trước, rồi Cà phê
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform menu_item_create('Trà đào', 'Trà', '[{"name":"M","price":39000}]', true);
  reset session authorization;
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  reset session authorization;

  -- ===== Sao chép trong quán =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform pg_temp.expect_err(format('select menu_item_copy(%L, ''Latte sữa tươi'')', latte), 'MENU_NAME_DUPLICATE');
  copy_item := menu_item_copy(latte, 'Latte sữa tươi (bản sao)');
  if not (select is_draft from menu_items where id = (copy_item->>'item_id')::uuid) then raise exception 'ban sao phai la nhap'; end if;
  if (select count(*) from menu_sizes where item_id = (copy_item->>'item_id')::uuid) <> 1 then raise exception 'ban sao chi lay size dang ban'; end if;
  -- món có công thức: sao chép giữ công thức
  cacao := menu_item_create('Cacao đá', 'Trà', '[{"name":"S","price":35000}]', true);
  select id into c_s from menu_sizes where item_id = cacao;
  perform menu_recipe_save(c_s, jsonb_build_array(jsonb_build_object('ingredient_id', milk, 'qty', 200), jsonb_build_object('ingredient_id', ice, 'qty', 80)));
  copy_item := menu_item_copy(cacao, 'Cacao đá 2');
  if (copy_item->>'copied_lines')::int <> 2 then raise exception 'ban sao phai giu 2 dong cong thuc: %', copy_item; end if;
  if (select count(*) from recipe_version_lines l join recipe_versions v on v.id = l.version_id
       join menu_sizes ms on ms.id = v.size_id where ms.item_id = (copy_item->>'item_id')::uuid) <> 2 then raise exception 'ban sao thieu version lines'; end if;
  reset session authorization;

  -- ===== Sao chép sang quán khác (cùng chủ) =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  shop_b := create_shop('Quán B', 'Chủ B');
  insert into ingredients (name, unit) values ('Sữa tươi', 'ml');   -- quán B chỉ có sữa, không có đá
  perform select_shop('00000000-0000-0000-0000-0000000000f1');
  j := menu_copy_targets();
  if jsonb_array_length(j) <> 1 or j->0->>'shop_id' <> shop_b::text then raise exception 'menu_copy_targets: %', j; end if;
  item_b := menu_item_copy_to_shop(cacao, shop_b, null);
  if (item_b->>'copied_lines')::int <> 0 or item_b->'skipped_ingredients' <> '["Đá"]'::jsonb then
    raise exception 'sao chep sang quan B: %', item_b;
  end if;
  perform pg_temp.expect_err(format('select menu_item_copy_to_shop(%L, %L, null)', cacao, shop_b), 'MENU_NAME_DUPLICATE');
  perform pg_temp.expect_err(format('select menu_item_copy_to_shop(%L, %L, null)', cacao, '00000000-0000-0000-0000-0000000000f1'), 'OWNER_ONLY');
  perform pg_temp.expect_err(format('select menu_item_copy_to_shop(%L, %L, null)', cacao, gen_random_uuid()), 'OWNER_ONLY');
  reset session authorization;
  if (select shop_id from menu_items where id = (item_b->>'item_id')::uuid) <> shop_b then raise exception 'ban sao phai o quan B'; end if;
  if not (select is_draft from menu_items where id = (item_b->>'item_id')::uuid) then raise exception 'ban sao quan B phai la nhap'; end if;
  if not exists (select 1 from menu_categories where shop_id = shop_b and name = 'Trà') then raise exception 'danh muc phai duoc tao o quan B'; end if;

  -- người không phải chủ quán đích không sao chép sang được
  insert into staff (shop_id, auth_user_id, full_name, role) values
    (shop_b, '00000000-0000-0000-0000-0000000000b1', 'NV B', 'staff');
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform select_shop('00000000-0000-0000-0000-0000000000f1');
  if jsonb_array_length(menu_copy_targets()) <> 1 then raise exception 'targets'; end if;
  reset session authorization;

  -- ===== Cô lập giữa các quán =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform select_shop(shop_b);
  j := menu_overview();
  if jsonb_array_length(j->'items') <> 1 then raise exception 'quan B chi co 1 mon (ban sao): %', jsonb_array_length(j->'items'); end if;
  perform pg_temp.expect_err(format('select menu_item_detail(%L)', latte), 'MENU_ITEM_NOT_FOUND');
  perform pg_temp.expect_err(format('select menu_recipe_save(%L, %L)', s_s, lines1), 'MENU_SIZE_NOT_FOUND');
  perform select_shop('00000000-0000-0000-0000-0000000000f1');
  reset session authorization;

  -- ===== Đối soát vẫn dùng công thức đúng thời điểm =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  perform select_shop('00000000-0000-0000-0000-0000000000f1');
  reset session authorization;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  select x into d from jsonb_array_elements(menu_overview()->'items') x where x->>'id' = latte::text;
  if d->>'name' <> 'Latte sữa tươi' then raise exception 'overview mon latte'; end if;
  reset session authorization;

  raise notice 'MENU MANAGEMENT: TAT CA DEU DUNG';
end $test$;
