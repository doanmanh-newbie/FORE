-- Fore · 06_menu_options.sql · TOPPING và TÙY CHỌN PHA CHẾ của món; sao chép món có đối chiếu nguyên liệu
-- Áp dụng SAU 05_menu_management.sql. Chạy lại nhiều lần an toàn.
--
-- Mô hình (mỗi quán riêng):
--   · menu_toppings: topping của quán (giá bán thêm, định lượng + nguyên liệu tùy chọn để tính vốn).
--   · menu_item_toppings: món nào được bán kèm topping nào; giới hạn "tối đa N loại, mỗi loại M phần" nằm trên menu_items.
--   · menu_option_groups / menu_option_choices: nhóm tùy chọn pha chế của món (mức đá, mức đường...), áp dụng cho mọi size.
--     Mặc định chỉ là CHỈ DẪN CHO BARISTA: không đổi giá, không đổi lượng trừ kho. Chỉ khi một lựa chọn có "định lượng riêng"
--     (ingredient_id + qty) thì mới được tính vốn riêng.
--   · Không xóa cứng: tắt bằng cột active.
-- LƯU Ý: phần BÁN HÀNG (nhân viên chọn topping/tùy chọn khi gọi món, trừ kho theo topping) CHƯA nối; lần này chỉ là
--   cấu hình + xem trước của chủ quán.

-- ---------- 1) Bảng ----------
alter table menu_items add column if not exists topping_max_kinds integer not null default 2 check (topping_max_kinds >= 1);
alter table menu_items add column if not exists topping_max_portions integer not null default 1 check (topping_max_portions >= 1);

create table if not exists menu_toppings (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null default app_shop_id() references shops(id),
  name          text not null check (char_length(btrim(name)) >= 1),
  price         integer not null default 0 check (price >= 0),
  ingredient_id uuid references ingredients(id),
  qty           integer check (qty is null or qty > 0),
  active        boolean not null default true,
  created_at    timestamptz not null default now(),
  check ((ingredient_id is null) = (qty is null))
);
create unique index if not exists menu_toppings_name_uq on menu_toppings (shop_id, lower(btrim(name)));

create table if not exists menu_item_toppings (
  item_id    uuid not null references menu_items(id),
  topping_id uuid not null references menu_toppings(id),
  shop_id    uuid not null default app_shop_id() references shops(id),
  active     boolean not null default true,
  primary key (item_id, topping_id)
);

create table if not exists menu_option_groups (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null default app_shop_id() references shops(id),
  item_id    uuid not null references menu_items(id),
  name       text not null check (char_length(btrim(name)) >= 1),
  required   boolean not null default true,
  active     boolean not null default true,
  sort_order integer not null default 0
);
create index if not exists menu_option_groups_item_idx on menu_option_groups (item_id);

create table if not exists menu_option_choices (
  id            uuid primary key default gen_random_uuid(),
  group_id      uuid not null references menu_option_groups(id),
  shop_id       uuid not null default app_shop_id() references shops(id),
  name          text not null check (char_length(btrim(name)) >= 1),
  is_default    boolean not null default false,
  price_delta   integer not null default 0 check (price_delta >= 0),
  ingredient_id uuid references ingredients(id),
  qty           integer check (qty is null or qty > 0),
  active        boolean not null default true,
  sort_order    integer not null default 0,
  check ((ingredient_id is null) = (qty is null))
);

alter table menu_toppings       enable row level security;
alter table menu_item_toppings  enable row level security;
alter table menu_option_groups  enable row level security;
alter table menu_option_choices enable row level security;
drop policy if exists menu_toppings_read on menu_toppings;
create policy menu_toppings_read on menu_toppings for select to authenticated using (shop_id = (select app_shop_id()));
drop policy if exists menu_item_toppings_read on menu_item_toppings;
create policy menu_item_toppings_read on menu_item_toppings for select to authenticated using (shop_id = (select app_shop_id()));
drop policy if exists menu_option_groups_read on menu_option_groups;
create policy menu_option_groups_read on menu_option_groups for select to authenticated using (shop_id = (select app_shop_id()));
drop policy if exists menu_option_choices_read on menu_option_choices;
create policy menu_option_choices_read on menu_option_choices for select to authenticated using (shop_id = (select app_shop_id()));

-- ---------- 2) Topping ----------
create or replace function _menu_topping_json(p_id uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', t.id, 'name', t.name, 'price', t.price, 'active', t.active,
    'ingredient_id', t.ingredient_id, 'ingredient_name', i.name, 'unit', i.unit, 'qty', t.qty,
    'unit_cost', i.unit_cost,
    'cost', case when t.ingredient_id is null then 0
                 when i.unit_cost is null then null else round(t.qty * i.unit_cost)::integer end,
    'cost_known', t.ingredient_id is null or i.unit_cost is not null)
  from menu_toppings t left join ingredients i on i.id = t.ingredient_id
 where t.id = p_id
$$;

create or replace function menu_toppings_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return coalesce((select jsonb_agg(_menu_topping_json(t.id) || jsonb_build_object(
      'used_by', (select count(*) from menu_item_toppings x where x.topping_id = t.id and x.active)) order by t.active desc, t.name)
    from menu_toppings t where t.shop_id = app_shop_id()), '[]'::jsonb);
end $$;

create or replace function menu_topping_save(p_id uuid, p_name text, p_price integer, p_ingredient uuid, p_qty integer, p_active boolean default true)
returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_name text := btrim(coalesce(p_name, '')); v_id uuid := p_id;
begin
  perform _require_owner();
  if v_name = '' then raise exception 'TOPPING_NAME_REQUIRED'; end if;
  if p_price is null or p_price < 0 then raise exception 'PRICE_INVALID'; end if;
  if (p_ingredient is null) <> (p_qty is null) or (p_qty is not null and p_qty <= 0) then raise exception 'QTY_INVALID'; end if;
  if p_ingredient is not null and not exists (select 1 from ingredients where id = p_ingredient and shop_id = v_shop and active) then
    raise exception 'INGREDIENT_NOT_FOUND';
  end if;
  if exists (select 1 from menu_toppings where shop_id = v_shop and lower(btrim(name)) = lower(v_name) and id is distinct from p_id) then
    raise exception 'TOPPING_DUPLICATE';
  end if;
  if p_id is null then
    insert into menu_toppings (shop_id, name, price, ingredient_id, qty, active)
    values (v_shop, v_name, p_price, p_ingredient, p_qty, coalesce(p_active, true)) returning id into v_id;
  else
    update menu_toppings set name = v_name, price = p_price, ingredient_id = p_ingredient, qty = p_qty, active = coalesce(p_active, true)
     where id = p_id and shop_id = v_shop;
    if not found then raise exception 'TOPPING_NOT_FOUND'; end if;
  end if;
  return v_id;
end $$;

-- ---------- 3) Topping + tùy chọn của một món ----------
create or replace function menu_item_extras(p_item uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_item menu_items%rowtype;
begin
  perform _require_owner();
  select * into v_item from menu_items where id = p_item and shop_id = app_shop_id();
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  return jsonb_build_object(
    'item_id', v_item.id,
    'topping_max_kinds', v_item.topping_max_kinds,
    'topping_max_portions', v_item.topping_max_portions,
    'toppings', coalesce((
      select jsonb_agg(_menu_topping_json(t.id) || jsonb_build_object(
               'selected', coalesce((select x.active from menu_item_toppings x where x.item_id = p_item and x.topping_id = t.id), false))
             order by t.active desc, t.name)
        from menu_toppings t where t.shop_id = app_shop_id()), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(jsonb_build_object(
          'id', g.id, 'name', g.name, 'required', g.required, 'active', g.active,
          'choices', coalesce((
            select jsonb_agg(jsonb_build_object(
                'id', c.id, 'name', c.name, 'is_default', c.is_default, 'price_delta', c.price_delta,
                'ingredient_id', c.ingredient_id, 'ingredient_name', i.name, 'unit', i.unit, 'qty', c.qty,
                'unit_cost', i.unit_cost, 'active', c.active) order by c.sort_order, c.name)
              from menu_option_choices c left join ingredients i on i.id = c.ingredient_id
             where c.group_id = g.id and c.active), '[]'::jsonb)) order by g.sort_order, g.name)
        from menu_option_groups g where g.item_id = p_item and g.active), '[]'::jsonb));
end $$;

create or replace function menu_item_toppings_save(p_item uuid, p_ids uuid[], p_max_kinds integer, p_max_portions integer)
returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_n integer; v_names text;
begin
  perform _require_owner();
  if not exists (select 1 from menu_items where id = p_item and shop_id = v_shop) then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  p_ids := coalesce(p_ids, '{}');
  if p_max_kinds is null or p_max_kinds < 1 or p_max_portions is null or p_max_portions < 1 then raise exception 'TOPPING_LIMIT_INVALID'; end if;
  select count(*) into v_n from menu_toppings where shop_id = v_shop and id = any (p_ids);
  if v_n <> (select count(distinct x) from unnest(p_ids) x) then raise exception 'TOPPING_NOT_FOUND'; end if;
  if p_max_kinds > greatest(v_n, 1) then raise exception 'TOPPING_LIMIT_INVALID'; end if;
  update menu_item_toppings set active = false where item_id = p_item and not (topping_id = any (p_ids));
  insert into menu_item_toppings (item_id, topping_id, shop_id, active)
  select p_item, x, v_shop, true from unnest(p_ids) x
  on conflict (item_id, topping_id) do update set active = true;
  update menu_items set topping_max_kinds = p_max_kinds, topping_max_portions = p_max_portions where id = p_item;
  select string_agg(t.name, ', ' order by t.name) into v_names from menu_toppings t where t.id = any (p_ids);
  perform _menu_event(p_item, null, 'topping',
    case when v_n = 0 then 'Tắt topping bán kèm' else 'Topping bán kèm: ' || v_names || ' (tối đa ' || p_max_kinds || ' loại, ' || p_max_portions || ' phần/loại)' end);
end $$;

-- Lưu TOÀN BỘ nhóm tùy chọn của món. Nhóm/lựa chọn không còn trong danh sách bị tắt (không xóa).
-- p_groups: [{id?, name, required, choices:[{id?, name, is_default, price_delta?, ingredient_id?, qty?}]}]
create or replace function menu_item_options_save(p_item uuid, p_groups jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id(); g jsonb; c jsonb; v_gid uuid; v_cid uuid; v_gi integer := 0; v_ci integer;
  v_name text; v_cname text; v_defaults integer; v_ing uuid; v_qty integer; v_required boolean;
  v_keep_g uuid[] := '{}'; v_keep_c uuid[]; v_seen_g text[] := '{}'; v_seen_c text[];
begin
  perform _require_owner();
  if not exists (select 1 from menu_items where id = p_item and shop_id = v_shop) then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if p_groups is null or jsonb_typeof(p_groups) <> 'array' then raise exception 'OPTION_INVALID'; end if;
  for g in select * from jsonb_array_elements(p_groups) loop
    v_gi := v_gi + 1;
    v_name := btrim(coalesce(g->>'name', ''));
    if v_name = '' then raise exception 'OPTION_GROUP_NAME_REQUIRED'; end if;
    if lower(v_name) = any (v_seen_g) then raise exception 'OPTION_GROUP_DUPLICATE'; end if;
    v_seen_g := array_append(v_seen_g, lower(v_name));
    v_required := coalesce((g->>'required')::boolean, true);
    if jsonb_array_length(coalesce(g->'choices', '[]')) < 1 then raise exception 'OPTION_CHOICE_REQUIRED'; end if;
    select count(*) into v_defaults from jsonb_array_elements(g->'choices') x where coalesce((x->>'is_default')::boolean, false);
    if v_required and v_defaults <> 1 then raise exception 'OPTION_DEFAULT_REQUIRED'; end if;
    if not v_required and v_defaults > 1 then raise exception 'OPTION_DEFAULT_REQUIRED'; end if;
    if nullif(g->>'id', '') is not null then
      v_gid := (g->>'id')::uuid;
      update menu_option_groups set name = v_name, required = v_required, active = true, sort_order = v_gi
       where id = v_gid and item_id = p_item and shop_id = v_shop;
      if not found then raise exception 'OPTION_NOT_FOUND'; end if;
    else
      insert into menu_option_groups (shop_id, item_id, name, required, sort_order) values (v_shop, p_item, v_name, v_required, v_gi)
      returning id into v_gid;
    end if;
    v_keep_g := array_append(v_keep_g, v_gid);
    v_keep_c := '{}'; v_seen_c := '{}'; v_ci := 0;
    for c in select * from jsonb_array_elements(g->'choices') loop
      v_ci := v_ci + 1;
      v_cname := btrim(coalesce(c->>'name', ''));
      if v_cname = '' then raise exception 'OPTION_CHOICE_NAME_REQUIRED'; end if;
      if lower(v_cname) = any (v_seen_c) then raise exception 'OPTION_CHOICE_DUPLICATE'; end if;
      v_seen_c := array_append(v_seen_c, lower(v_cname));
      v_ing := nullif(c->>'ingredient_id', '')::uuid;
      v_qty := nullif(c->>'qty', '')::integer;
      if (v_ing is null) <> (v_qty is null) or (v_qty is not null and v_qty <= 0) then raise exception 'QTY_INVALID'; end if;
      if v_ing is not null and not exists (select 1 from ingredients where id = v_ing and shop_id = v_shop and active) then
        raise exception 'INGREDIENT_NOT_FOUND';
      end if;
      if coalesce((c->>'price_delta')::integer, 0) < 0 then raise exception 'PRICE_INVALID'; end if;
      if nullif(c->>'id', '') is not null then
        v_cid := (c->>'id')::uuid;
        update menu_option_choices set name = v_cname, is_default = coalesce((c->>'is_default')::boolean, false),
               price_delta = coalesce((c->>'price_delta')::integer, 0), ingredient_id = v_ing, qty = v_qty, active = true, sort_order = v_ci
         where id = v_cid and group_id = v_gid and shop_id = v_shop;
        if not found then raise exception 'OPTION_NOT_FOUND'; end if;
      else
        insert into menu_option_choices (group_id, shop_id, name, is_default, price_delta, ingredient_id, qty, sort_order)
        values (v_gid, v_shop, v_cname, coalesce((c->>'is_default')::boolean, false), coalesce((c->>'price_delta')::integer, 0), v_ing, v_qty, v_ci)
        returning id into v_cid;
      end if;
      v_keep_c := array_append(v_keep_c, v_cid);
    end loop;
    update menu_option_choices set active = false where group_id = v_gid and not (id = any (v_keep_c));
  end loop;
  update menu_option_groups set active = false where item_id = p_item and not (id = any (v_keep_g));
  perform _menu_event(p_item, null, 'option',
    case when v_gi = 0 then 'Tắt các tùy chọn pha chế' else 'Cập nhật tùy chọn pha chế (' || v_gi || ' nhóm)' end);
end $$;

-- ---------- 4) Sao chép món: xem trước đối chiếu + sao chép có ánh xạ nguyên liệu ----------
-- Xem trước: mỗi dòng công thức của món nguồn và nguyên liệu khớp ở quán nhận (cùng tên + đơn vị), danh sách nguyên liệu
-- của quán nhận để chủ chọn tay, và tên món có bị trùng không.
create or replace function menu_copy_preview(p_item uuid, p_shop uuid, p_new_name text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_src menu_items%rowtype; v_name text;
begin
  perform _require_owner();
  select * into v_src from menu_items where id = p_item and shop_id = app_shop_id();
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if p_shop is distinct from app_shop_id() and not exists (
       select 1 from staff s where s.auth_user_id = auth.uid() and s.active and s.role = 'owner' and s.shop_id = p_shop) then
    raise exception 'OWNER_ONLY';
  end if;
  v_name := coalesce(nullif(btrim(coalesce(p_new_name, '')), ''), v_src.name);
  return jsonb_build_object(
    'name_taken', exists (select 1 from menu_items where shop_id = p_shop and lower(btrim(name)) = lower(btrim(v_name))),
    'category', v_src.group_name,
    'category_exists', v_src.group_name is null or exists (select 1 from menu_categories where shop_id = p_shop and lower(btrim(name)) = lower(btrim(v_src.group_name))),
    'sizes', coalesce((select jsonb_agg(jsonb_build_object('name', s.size_name, 'price', s.price) order by s.price, s.size_name)
                         from menu_sizes s where s.item_id = p_item and s.active), '[]'::jsonb),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
          'ingredient_id', x.ingredient_id, 'name', x.name, 'unit', x.unit, 'qty', x.qty, 'sizes', x.sizes,
          'match_id', m.id, 'match_name', m.name) order by x.name)
        from (select rl.ingredient_id, i.name, i.unit, max(rl.qty) as qty,
                     jsonb_agg(ms.size_name order by ms.price) as sizes
                from menu_sizes ms join recipe_lines rl on rl.size_id = ms.id join ingredients i on i.id = rl.ingredient_id
               where ms.item_id = p_item and ms.active
               group by rl.ingredient_id, i.name, i.unit) x
        left join lateral (select d.id, d.name from ingredients d
                            where d.shop_id = p_shop and d.active and d.unit = x.unit and lower(btrim(d.name)) = lower(btrim(x.name))
                            limit 1) m on true), '[]'::jsonb),
    'dest_ingredients', coalesce((select jsonb_agg(jsonb_build_object('id', d.id, 'name', d.name, 'unit', d.unit) order by d.name)
                                    from ingredients d where d.shop_id = p_shop and d.active), '[]'::jsonb),
    'topping_count', (select count(*) from menu_item_toppings x where x.item_id = p_item and x.active),
    'option_group_count', (select count(*) from menu_option_groups g where g.item_id = p_item and g.active));
end $$;

-- Thay thế hàm nội bộ ở 05: thêm ánh xạ nguyên liệu tay, sao chép topping/tùy chọn.
-- Size có nguyên liệu chưa khớp thì KHÔNG tạo công thức cho size đó (vốn/lãi "chưa xác định", chủ soạn công thức sau),
-- để không có công thức thiếu nguyên liệu làm sai kho và vốn.
drop function if exists _menu_copy_item(uuid, uuid, text);
create or replace function _menu_copy_item(p_item uuid, p_to_shop uuid, p_name text,
                                           p_mapping jsonb default '{}', p_copy_toppings boolean default false, p_copy_options boolean default false)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_from uuid; v_src menu_items%rowtype; v_new uuid; v_cat text; v_s record; v_size uuid; v_ver uuid;
  v_lines integer := 0; v_skipped text[] := '{}'; v_l record; v_ing uuid; v_map uuid; v_ok boolean; v_resolved jsonb;
  v_t record; v_tid uuid; v_tskip text[] := '{}'; v_g record; v_gid uuid; v_c record; v_cing uuid; v_copied_t integer := 0; v_copied_g integer := 0;
begin
  select * into v_src from menu_items where id = p_item;
  v_from := v_src.shop_id;
  p_mapping := coalesce(p_mapping, '{}');
  if exists (select 1 from menu_items where shop_id = p_to_shop and lower(btrim(name)) = lower(btrim(p_name))) then
    raise exception 'MENU_NAME_DUPLICATE';
  end if;
  v_cat := v_src.group_name;
  if v_cat is not null and not exists (select 1 from menu_categories where shop_id = p_to_shop and lower(btrim(name)) = lower(btrim(v_cat))) then
    insert into menu_categories (shop_id, name, sort_order)
    values (p_to_shop, v_cat, coalesce((select max(sort_order) from menu_categories where shop_id = p_to_shop), 0) + 1);
  end if;
  insert into menu_items (shop_id, name, group_name, active, is_draft, description, image_path, topping_max_kinds, topping_max_portions)
  values (p_to_shop, btrim(p_name), v_cat, false, true, v_src.description,
          case when p_to_shop = v_from then v_src.image_path end,
          v_src.topping_max_kinds, v_src.topping_max_portions)
  returning id into v_new;

  -- Đối chiếu từng nguyên liệu nguồn -> nguyên liệu quán nhận (ánh xạ tay, rồi cùng tên + đơn vị)
  for v_l in select distinct rl.ingredient_id, i.name, i.unit
               from menu_sizes ms join recipe_lines rl on rl.size_id = ms.id join ingredients i on i.id = rl.ingredient_id
              where ms.item_id = p_item and ms.active loop
    if p_to_shop = v_from then v_ing := v_l.ingredient_id;
    else
      v_ing := null;
      v_map := nullif(p_mapping->>(v_l.ingredient_id::text), '')::uuid;
      if v_map is not null then
        select id into v_ing from ingredients where id = v_map and shop_id = p_to_shop and active;
        if v_ing is null then raise exception 'INGREDIENT_NOT_FOUND'; end if;
        if (select unit from ingredients where id = v_ing) <> v_l.unit then raise exception 'INGREDIENT_UNIT_MISMATCH'; end if;
      else
        select id into v_ing from ingredients
         where shop_id = p_to_shop and active and unit = v_l.unit and lower(btrim(name)) = lower(btrim(v_l.name)) limit 1;
      end if;
    end if;
    v_resolved := coalesce(v_resolved, '{}') || jsonb_build_object(v_l.ingredient_id::text, v_ing);
  end loop;
  v_resolved := coalesce(v_resolved, '{}');

  for v_s in select * from menu_sizes where item_id = p_item and active order by price, size_name loop
    insert into menu_sizes (shop_id, item_id, size_name, price, active)
    values (p_to_shop, v_new, v_s.size_name, v_s.price, true) returning id into v_size;
    v_ok := true;
    for v_l in select rl.ingredient_id, i.name from recipe_lines rl join ingredients i on i.id = rl.ingredient_id where rl.size_id = v_s.id loop
      if nullif(v_resolved->>(v_l.ingredient_id::text), '') is null then
        v_ok := false;
        if not (v_l.name = any (v_skipped)) then v_skipped := array_append(v_skipped, v_l.name); end if;
      end if;
    end loop;
    if not v_ok or not exists (select 1 from recipe_lines where size_id = v_s.id) then continue; end if;
    insert into recipe_versions (shop_id, size_id, version_no, status, effective_from, applied_at, created_by)
    values (p_to_shop, v_size, 1, 'active', now(), now(), app_staff_id()) returning id into v_ver;
    for v_l in select rl.ingredient_id, rl.qty from recipe_lines rl where rl.size_id = v_s.id loop
      v_ing := (v_resolved->>(v_l.ingredient_id::text))::uuid;
      insert into recipe_version_lines (version_id, ingredient_id, qty) values (v_ver, v_ing, v_l.qty);
      perform set_config('fore.recipe_apply', 'on', true);
      insert into recipe_lines (shop_id, size_id, ingredient_id, qty) values (p_to_shop, v_size, v_ing, v_l.qty);
      perform set_config('fore.recipe_apply', 'off', true);
      v_lines := v_lines + 1;
    end loop;
  end loop;

  if p_copy_toppings then
    for v_t in select t.* from menu_item_toppings x join menu_toppings t on t.id = x.topping_id where x.item_id = p_item and x.active loop
      if p_to_shop = v_from then v_tid := v_t.id;
      else select id into v_tid from menu_toppings where shop_id = p_to_shop and lower(btrim(name)) = lower(btrim(v_t.name)) limit 1;
      end if;
      if v_tid is null then v_tskip := array_append(v_tskip, v_t.name); continue; end if;
      insert into menu_item_toppings (item_id, topping_id, shop_id, active) values (v_new, v_tid, p_to_shop, true);
      v_copied_t := v_copied_t + 1;
    end loop;
  end if;

  if p_copy_options then
    for v_g in select * from menu_option_groups where item_id = p_item and active order by sort_order loop
      insert into menu_option_groups (shop_id, item_id, name, required, sort_order) values (p_to_shop, v_new, v_g.name, v_g.required, v_g.sort_order)
      returning id into v_gid;
      for v_c in select * from menu_option_choices where group_id = v_g.id and active order by sort_order loop
        v_cing := null;
        if v_c.ingredient_id is not null then
          if p_to_shop = v_from then v_cing := v_c.ingredient_id;
          else v_cing := nullif(v_resolved->>(v_c.ingredient_id::text), '')::uuid;
          end if;
        end if;
        -- định lượng riêng chỉ giữ khi tìm được nguyên liệu tương ứng; nếu không thì chỉ còn là chỉ dẫn
        insert into menu_option_choices (group_id, shop_id, name, is_default, price_delta, ingredient_id, qty, sort_order)
        values (v_gid, p_to_shop, v_c.name, v_c.is_default, v_c.price_delta, v_cing, case when v_cing is null then null else v_c.qty end, v_c.sort_order);
      end loop;
      v_copied_g := v_copied_g + 1;
    end loop;
  end if;

  return jsonb_build_object('item_id', v_new, 'copied_lines', v_lines, 'skipped_ingredients', to_jsonb(v_skipped),
                            'copied_toppings', v_copied_t, 'skipped_toppings', to_jsonb(v_tskip), 'copied_option_groups', v_copied_g);
end $$;

-- Hàm 3 tham số ở 05 vẫn dùng được (không ánh xạ tay, không chép topping/tùy chọn).
create or replace function menu_item_copy_to_shop(p_item uuid, p_shop uuid, p_new_name text, p_mapping jsonb, p_copy_toppings boolean, p_copy_options boolean)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_src menu_items%rowtype; v_r jsonb; v_name text;
begin
  perform _require_owner();
  select * into v_src from menu_items where id = p_item and shop_id = app_shop_id();
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if p_shop is null or (p_shop <> app_shop_id() and not exists (
       select 1 from staff s where s.auth_user_id = auth.uid() and s.active and s.role = 'owner' and s.shop_id = p_shop)) then
    raise exception 'OWNER_ONLY';
  end if;
  v_name := coalesce(nullif(btrim(coalesce(p_new_name, '')), ''), v_src.name);
  v_r := _menu_copy_item(p_item, p_shop, v_name, p_mapping, coalesce(p_copy_toppings, false), coalesce(p_copy_options, false));
  insert into menu_events (shop_id, item_id, kind, summary, detail, actor)
  values (p_shop, (v_r->>'item_id')::uuid, 'copy',
          case when p_shop = app_shop_id() then 'Tạo bản sao từ "' || v_src.name || '" (bản nháp)' else 'Sao chép từ quán khác (bản nháp)' end, v_r,
          (select s.id from staff s where s.auth_user_id = auth.uid() and s.shop_id = p_shop and s.active limit 1));
  if p_shop <> app_shop_id() then perform _menu_event(p_item, null, 'copy', 'Sao chép sang quán khác'); end if;
  return v_r;
end $$;

-- Hàm 3 tham số (05) gọi hàm nội bộ cũ đã bị thay thế ở trên: viết lại cho dùng hàm mới.
create or replace function menu_item_copy(p_item uuid, p_new_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_name text := btrim(coalesce(p_new_name, ''));
begin
  perform _require_owner();
  if not exists (select 1 from menu_items where id = p_item and shop_id = v_shop) then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if v_name = '' then raise exception 'MENU_NAME_REQUIRED'; end if;
  return menu_item_copy_to_shop(p_item, v_shop, v_name, '{}', false, false);
end $$;

create or replace function menu_item_copy_to_shop(p_item uuid, p_shop uuid, p_new_name text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
begin
  if p_shop is not distinct from app_shop_id() then raise exception 'OWNER_ONLY'; end if;   -- cùng quán: dùng menu_item_copy
  return menu_item_copy_to_shop(p_item, p_shop, p_new_name, '{}'::jsonb, false, false);
end $$;

-- ---------- 5) Quyền gọi ----------
revoke all on function
  menu_toppings_list(), menu_topping_save(uuid, text, integer, uuid, integer, boolean), menu_item_extras(uuid),
  menu_item_toppings_save(uuid, uuid[], integer, integer), menu_item_options_save(uuid, jsonb),
  menu_copy_preview(uuid, uuid, text), menu_item_copy_to_shop(uuid, uuid, text, jsonb, boolean, boolean),
  menu_item_copy_to_shop(uuid, uuid, text), menu_item_copy(uuid, text)
  from public, anon;
grant execute on function
  menu_toppings_list(), menu_topping_save(uuid, text, integer, uuid, integer, boolean), menu_item_extras(uuid),
  menu_item_toppings_save(uuid, uuid[], integer, integer), menu_item_options_save(uuid, jsonb),
  menu_copy_preview(uuid, uuid, text), menu_item_copy_to_shop(uuid, uuid, text, jsonb, boolean, boolean),
  menu_item_copy_to_shop(uuid, uuid, text), menu_item_copy(uuid, text)
  to authenticated;
revoke all on function _menu_topping_json(uuid), _menu_copy_item(uuid, uuid, text, jsonb, boolean, boolean) from public, anon, authenticated;
