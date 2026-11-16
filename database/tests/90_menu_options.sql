-- Kiểm thử TOPPING, TÙY CHỌN PHA CHẾ và SAO CHÉP có đối chiếu nguyên liệu (database/06_menu_options.sql).
-- Chạy sau tests/00_supabase_stub.sql và 01..06. Đúng hết in "MENU OPTIONS: TAT CA DEU DUNG". KHÔNG chạy trên Supabase thật.
\set ON_ERROR_STOP on

truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts, menu_categories, recipe_versions,
         price_changes, menu_events, menu_toppings restart identity cascade;
delete from auth.users;
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán A');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, unit, importance, unit_cost) values
  ('Cà phê', 'g', 'important', 200), ('Sữa tươi', 'ml', 'important', 50), ('Trân châu', 'g', 'normal', 60), ('Ly + nắp', 'piece', 'normal', 400);

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

create or replace function pg_temp.q(p_sql text) returns bigint language plpgsql security definer as $f$
declare n bigint; begin execute p_sql into n; return n; end $f$;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  shop_a  constant uuid := '00000000-0000-0000-0000-0000000000f1';
  cf uuid; milk uuid; pearl uuid; cup uuid; latte uuid; s_s uuid; s_m uuid; tp1 uuid; tp2 uuid; tp3 uuid;
  j jsonb; g jsonb; shop_b uuid; r jsonb; cp jsonb; ice_g uuid; line jsonb; new_item uuid; new_size uuid;
  b_milk uuid; b_cf uuid; b_rice uuid; b_cup uuid;
begin
  select id into cf from ingredients where name = 'Cà phê';
  select id into milk from ingredients where name = 'Sữa tươi';
  select id into pearl from ingredients where name = 'Trân châu';
  select id into cup from ingredients where name = 'Ly + nắp';

  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform select_shop(shop_a);
  perform menu_category_add('Cà phê');
  latte := menu_item_create('Latte sữa tươi', 'Cà phê', '[{"name":"S","price":35000},{"name":"M","price":42000}]', true);
  select id into s_s from menu_sizes where item_id = latte and size_name = 'S';
  select id into s_m from menu_sizes where item_id = latte and size_name = 'M';
  perform menu_recipe_save(s_s, jsonb_build_array(
    jsonb_build_object('ingredient_id', cf, 'qty', 18), jsonb_build_object('ingredient_id', milk, 'qty', 140), jsonb_build_object('ingredient_id', cup, 'qty', 1)));
  perform menu_recipe_save(s_m, jsonb_build_array(
    jsonb_build_object('ingredient_id', cf, 'qty', 18), jsonb_build_object('ingredient_id', milk, 'qty', 160)));
  reset session authorization;

  -- ===== Quyền =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  perform pg_temp.expect_err('select menu_toppings_list()', 'OWNER_ONLY');
  perform pg_temp.expect_err(format('select menu_item_extras(%L)', latte), 'OWNER_ONLY');
  perform pg_temp.expect_err($$select menu_topping_save(null, 'X', 1000, null, null, true)$$, 'OWNER_ONLY');
  reset session authorization;

  -- ===== Topping =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform select_shop(shop_a);
  perform pg_temp.expect_err($$select menu_topping_save(null, '  ', 5000, null, null, true)$$, 'TOPPING_NAME_REQUIRED');
  perform pg_temp.expect_err($$select menu_topping_save(null, 'X', -1, null, null, true)$$, 'PRICE_INVALID');
  perform pg_temp.expect_err(format('select menu_topping_save(null, %L, 5000, %L, null, true)', 'X', pearl), 'QTY_INVALID');
  perform pg_temp.expect_err(format('select menu_topping_save(null, %L, 5000, %L, 0, true)', 'X', pearl), 'QTY_INVALID');
  perform pg_temp.expect_err(format('select menu_topping_save(null, %L, 5000, %L, 30, true)', 'X', gen_random_uuid()), 'INGREDIENT_NOT_FOUND');
  tp1 := menu_topping_save(null, 'Trân châu', 5000, pearl, 30, true);
  tp2 := menu_topping_save(null, 'Thạch cà phê', 6000, null, null, true);
  tp3 := menu_topping_save(null, 'Kem sữa', 8000, null, null, false);
  perform pg_temp.expect_err($$select menu_topping_save(null, 'TRân châu', 1000, null, null, true)$$, 'TOPPING_DUPLICATE');
  perform menu_topping_save(tp2, 'Thạch cà phê', 6500, null, null, true);
  j := menu_toppings_list();
  if jsonb_array_length(j) <> 3 then raise exception 'toppings_list: %', j; end if;
  select x into line from jsonb_array_elements(j) x where x->>'id' = tp1::text;
  if (line->>'cost')::int <> 1800 or line->>'cost_known' <> 'true' or line->>'unit' <> 'g' then raise exception 'von topping tran chau phai 30g x 60 = 1800: %', line; end if;
  select x into line from jsonb_array_elements(j) x where x->>'id' = tp2::text;
  if (line->>'price')::int <> 6500 or (line->>'cost')::int <> 0 then raise exception 'topping khong dinh luong: %', line; end if;

  -- ===== Topping của món =====
  j := menu_item_extras(latte);
  if (j->>'topping_max_kinds')::int <> 2 or (j->>'topping_max_portions')::int <> 1 then raise exception 'mac dinh gioi han: %', j; end if;
  if (select count(*) from jsonb_array_elements(j->'toppings') x where x->>'selected' = 'true') <> 0 then raise exception 'chua chon topping nao'; end if;
  perform pg_temp.expect_err(format('select menu_item_toppings_save(%L, %L::uuid[], 0, 1)', latte, array[tp1]), 'TOPPING_LIMIT_INVALID');
  perform pg_temp.expect_err(format('select menu_item_toppings_save(%L, %L::uuid[], 3, 1)', latte, array[tp1, tp2]), 'TOPPING_LIMIT_INVALID');
  perform pg_temp.expect_err(format('select menu_item_toppings_save(%L, %L::uuid[], 1, 1)', latte, array[gen_random_uuid()]), 'TOPPING_NOT_FOUND');
  perform menu_item_toppings_save(latte, array[tp1, tp2], 2, 3);
  j := menu_item_extras(latte);
  if (j->>'topping_max_portions')::int <> 3 then raise exception 'gioi han phan'; end if;
  if (select count(*) from jsonb_array_elements(j->'toppings') x where x->>'selected' = 'true') <> 2 then raise exception 'chon 2 topping: %', j; end if;
  perform menu_item_toppings_save(latte, array[tp1], 1, 1);
  if (select count(*) from jsonb_array_elements(menu_item_extras(latte)->'toppings') x where x->>'selected' = 'true') <> 1 then raise exception 'bo chon 1 topping'; end if;
  if pg_temp.q(format('select count(*) from menu_item_toppings where item_id = %L', latte)) <> 2 then raise exception 'khong xoa cung dong lien ket'; end if;
  if pg_temp.q(format('select count(*) from menu_events where item_id = %L and kind = ''topping''', latte)) = 0 then raise exception 'thieu su kien topping'; end if;

  -- ===== Tùy chọn pha chế =====
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '{}'), 'OPTION_INVALID');
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '[{"name":"","required":true,"choices":[{"name":"A","is_default":true}]}]'), 'OPTION_GROUP_NAME_REQUIRED');
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '[{"name":"Đá","required":true,"choices":[]}]'), 'OPTION_CHOICE_REQUIRED');
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '[{"name":"Đá","required":true,"choices":[{"name":"A"},{"name":"B"}]}]'), 'OPTION_DEFAULT_REQUIRED');
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '[{"name":"Đá","required":true,"choices":[{"name":"A","is_default":true},{"name":"B","is_default":true}]}]'), 'OPTION_DEFAULT_REQUIRED');
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '[{"name":"Đá","required":true,"choices":[{"name":"A","is_default":true},{"name":"a"}]}]'), 'OPTION_CHOICE_DUPLICATE');
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '[{"name":"Đá","required":true,"choices":[{"name":"A","is_default":true,"qty":5}]}]'), 'QTY_INVALID');
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte, '[{"name":"Ice","required":true,"choices":[{"name":"A","is_default":true}]},{"name":"ice","required":true,"choices":[{"name":"A","is_default":true}]}]'), 'OPTION_GROUP_DUPLICATE');
  perform menu_item_options_save(latte, jsonb_build_array(
    jsonb_build_object('name', 'Mức đá', 'required', true, 'choices', jsonb_build_array(
      jsonb_build_object('name', 'Không', 'is_default', false),
      jsonb_build_object('name', 'Ít', 'is_default', false),
      jsonb_build_object('name', 'Bình thường', 'is_default', true))),
    jsonb_build_object('name', 'Mức đường', 'required', true, 'choices', jsonb_build_array(
      jsonb_build_object('name', 'Ít', 'is_default', false),
      jsonb_build_object('name', 'Bình thường', 'is_default', true),
      jsonb_build_object('name', 'Thêm', 'is_default', false, 'ingredient_id', milk, 'qty', 10)))));
  j := menu_item_extras(latte);
  if jsonb_array_length(j->'groups') <> 2 then raise exception 'phai co 2 nhom: %', j; end if;
  g := j->'groups'->0;
  if g->>'name' <> 'Mức đá' or jsonb_array_length(g->'choices') <> 3 then raise exception 'nhom da: %', g; end if;
  -- sửa: bỏ nhóm đường, đổi lựa chọn nhóm đá (giữ id) => nhóm đường chỉ bị tắt
  select x into g from jsonb_array_elements(j->'groups') x where x->>'name' = 'Mức đá';
  perform menu_item_options_save(latte, jsonb_build_array(
    jsonb_build_object('id', g->>'id', 'name', 'Mức đá', 'required', false, 'choices', jsonb_build_array(
      jsonb_build_object('id', g->'choices'->0->>'id', 'name', 'Không đá', 'is_default', false),
      jsonb_build_object('id', g->'choices'->2->>'id', 'name', 'Bình thường', 'is_default', true)))));
  j := menu_item_extras(latte);
  if jsonb_array_length(j->'groups') <> 1 or jsonb_array_length(j->'groups'->0->'choices') <> 2 then raise exception 'sau sua: %', j; end if;
  if pg_temp.q(format('select count(*) from menu_option_groups where item_id = %L', latte)) <> 2 then raise exception 'nhom bi xoa cung'; end if;
  if pg_temp.q(format('select count(*) from menu_option_choices c join menu_option_groups g2 on g2.id = c.group_id where g2.item_id = %L and not c.active', latte)) <> 1 then raise exception 'lua chon bi tat khong dung'; end if;
  perform pg_temp.expect_err(format('select menu_item_options_save(%L, %L)', latte,
    format('[{"id":"%s","name":"X","required":true,"choices":[{"name":"A","is_default":true}]}]', gen_random_uuid())::text), 'OPTION_NOT_FOUND');
  reset session authorization;

  -- ===== Sao chép trong cùng quán: chép topping + tùy chọn =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform select_shop(shop_a);
  r := menu_item_copy_to_shop(latte, shop_a, 'Latte 2', '{}', true, true);
  new_item := (r->>'item_id')::uuid;
  if (r->>'copied_lines')::int <> 5 or (r->>'copied_toppings')::int <> 1 or (r->>'copied_option_groups')::int <> 1 then raise exception 'copy cung quan: %', r; end if;
  if (select count(*) from jsonb_array_elements(menu_item_extras(new_item)->'toppings') x where x->>'selected' = 'true') <> 1 then raise exception 'ban sao giu topping'; end if;
  r := menu_item_copy(latte, 'Latte 3');
  if (menu_item_extras((r->>'item_id')::uuid)->'groups') <> '[]'::jsonb then raise exception 'mac dinh khong chep tuy chon'; end if;
  perform pg_temp.expect_err(format('select menu_item_copy_to_shop(%L, %L, %L, %L, false, false)', latte, shop_a, 'latte 2', '{}'), 'MENU_NAME_DUPLICATE');
  reset session authorization;

  -- ===== Sao chép sang quán khác, đối chiếu nguyên liệu =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  shop_b := create_shop('Quán B', 'Chủ B');
  perform pg_temp.q('select 1'); insert into ingredients (name, unit) values ('Cà phê espresso', 'g'), ('Sữa tươi', 'ml'), ('Ly lớn', 'piece'), ('Gạo', 'g');
  perform pg_temp.q(format('with x as (insert into menu_toppings (shop_id, name, price) values (%L, ''Trân châu'', 6000) returning 1) select count(*) from x', shop_b));
  select id into b_milk from ingredients where shop_id = shop_b and name = 'Sữa tươi';
  select id into b_cf from ingredients where shop_id = shop_b and name = 'Cà phê espresso';
  select id into b_rice from ingredients where shop_id = shop_b and name = 'Gạo';
  select id into b_cup from ingredients where shop_id = shop_b and name = 'Ly lớn';
  perform select_shop(shop_a);
  cp := menu_copy_preview(latte, shop_b, null);
  if cp->>'name_taken' <> 'false' or jsonb_array_length(cp->'sizes') <> 2 then raise exception 'preview: %', cp; end if;
  if (select count(*) from jsonb_array_elements(cp->'lines') x where x->>'match_id' is not null) <> 1 then raise exception 'chi sua tuoi khop tu dong: %', cp->'lines'; end if;
  if jsonb_array_length(cp->'dest_ingredients') <> 4 then raise exception 'dest ingredients: %', cp->'dest_ingredients'; end if;
  if (cp->>'topping_count')::int <> 1 or (cp->>'option_group_count')::int <> 1 then raise exception 'dem topping/tuy chon: %', cp; end if;
  -- chưa ánh xạ đủ: size nào thiếu nguyên liệu thì không có công thức
  r := menu_item_copy_to_shop(latte, shop_b, 'Latte B1', '{}', false, false);
  if (r->>'copied_lines')::int <> 0 or jsonb_array_length(r->'skipped_ingredients') <> 2 then raise exception 'chua anh xa: %', r; end if;
  -- ánh xạ tay đủ: Cà phê -> espresso; Ly + nắp -> Ly lớn (đơn vị khớp)
  perform pg_temp.expect_err(format('select menu_item_copy_to_shop(%L, %L, %L, %L::jsonb, false, false)', latte, shop_b, 'X1',
    jsonb_build_object(cf::text, b_rice, cup::text, b_rice)::text), 'INGREDIENT_UNIT_MISMATCH');
  perform pg_temp.expect_err(format('select menu_item_copy_to_shop(%L, %L, %L, %L::jsonb, false, false)', latte, shop_b, 'X2',
    jsonb_build_object(cf::text, gen_random_uuid())::text), 'INGREDIENT_NOT_FOUND');
  r := menu_item_copy_to_shop(latte, shop_b, 'Latte B2',
    jsonb_build_object(cf::text, b_cf, cup::text, b_cup), true, true);
  if (r->>'copied_lines')::int <> 5 or jsonb_array_length(r->'skipped_ingredients') <> 0 then raise exception 'anh xa du: %', r; end if;
  if (r->>'copied_toppings')::int <> 1 then raise exception 'topping khop theo ten: %', r; end if;
  -- định lượng riêng của lựa chọn bị bỏ vì nhóm đường đã tắt; nhóm đá có 2 lựa chọn
  if (r->>'copied_option_groups')::int <> 1 then raise exception 'nhom tuy chon: %', r; end if;
  reset session authorization;
  if not (select is_draft from menu_items where id = (r->>'item_id')::uuid) then raise exception 'ban sao phai la nhap'; end if;
  if exists (select 1 from recipe_lines rl join recipe_version_lines l on true where false) then null; end if;
  if (select count(*) from recipe_lines rl join menu_sizes ms on ms.id = rl.size_id where ms.item_id = (r->>'item_id')::uuid and rl.shop_id <> shop_b) <> 0 then raise exception 'cong thuc phai dung id quan B'; end if;
  if exists (select 1 from recipe_lines rl join menu_sizes ms on ms.id = rl.size_id join ingredients i on i.id = rl.ingredient_id
              where ms.item_id = (r->>'item_id')::uuid and i.shop_id <> shop_b) then raise exception 'nguyen lieu phai thuoc quan B'; end if;

  raise notice 'MENU OPTIONS: TAT CA DEU DUNG';
end $test$;
