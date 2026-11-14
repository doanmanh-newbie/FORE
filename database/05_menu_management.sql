-- Fore · 05_menu_management.sql · Quản lý THỰC ĐƠN của chủ quán
-- Áp dụng SAU 04_membership_sessions.sql. Chạy lại nhiều lần an toàn (create if not exists / or replace).
--
-- Mô hình: MỖI QUÁN một thực đơn riêng (menu_items/menu_sizes/ingredients đều có shop_id).
--   · Giá vốn = Σ (định lượng × ingredients.unit_cost). Thiếu giá một nguyên liệu thì "chưa xác định".
--   · Công thức theo PHIÊN BẢN: recipe_versions (+ recipe_version_lines). Bảng recipe_lines vẫn là công thức
--     ĐANG DÙNG (pay_bill ghi sổ kho theo nó). Phiên bản hẹn giờ được kích hoạt "lười" (_menu_apply_due) ở
--     những hàm bán hàng và hàm thực đơn, nên không cần cron. Sổ kho đã ghi lúc bán nên ca cũ không bị lệch.
--   · Đổi giá: price_changes (áp dụng ngay hoặc hẹn giờ). bill_lines.unit_price giữ giá lúc bán.
--   · Mọi thay đổi ghi vào menu_events để hiện "Lịch sử thay đổi".
--   · Định lượng là SỐ NGUYÊN theo đơn vị gốc (g, ml, cái) như sổ kho; chưa hỗ trợ số lẻ.

-- ---------- 1) Cột và bảng mới ----------
alter table ingredients add column if not exists unit_cost numeric(12,2) check (unit_cost is null or unit_cost >= 0);
alter table ingredients add column if not exists unit_cost_updated_at timestamptz;
alter table menu_items  add column if not exists is_draft boolean not null default false;
alter table menu_items  add column if not exists image_path text;
alter table menu_items  add column if not exists description text;

create table if not exists menu_categories (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null default app_shop_id() references shops(id),
  name       text not null check (char_length(btrim(name)) >= 1),
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create unique index if not exists menu_categories_name_uq on menu_categories (shop_id, lower(btrim(name)));

create table if not exists recipe_versions (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null default app_shop_id() references shops(id),
  size_id        uuid not null references menu_sizes(id),
  version_no     integer not null check (version_no >= 1),
  status         text not null check (status in ('scheduled','active','superseded','cancelled')),
  effective_from timestamptz not null,
  applied_at     timestamptz,
  note           text,
  created_by     uuid references staff(id),
  created_at     timestamptz not null default now(),
  unique (size_id, version_no)
);
create index if not exists recipe_versions_due_idx on recipe_versions (shop_id, effective_from) where status = 'scheduled';

create table if not exists recipe_version_lines (
  version_id    uuid not null references recipe_versions(id) on delete cascade,
  ingredient_id uuid not null references ingredients(id),
  qty           integer not null check (qty > 0),
  primary key (version_id, ingredient_id)
);

create table if not exists price_changes (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null default app_shop_id() references shops(id),
  size_id        uuid not null references menu_sizes(id),
  old_price      integer not null check (old_price >= 0),
  new_price      integer not null check (new_price > 0),
  status         text not null check (status in ('scheduled','applied','cancelled')),
  effective_from timestamptz not null,
  applied_at     timestamptz,
  created_by     uuid references staff(id),
  created_at     timestamptz not null default now()
);
create index if not exists price_changes_due_idx on price_changes (shop_id, effective_from) where status = 'scheduled';

create table if not exists menu_events (
  id         uuid primary key default gen_random_uuid(),
  shop_id    uuid not null default app_shop_id() references shops(id),
  item_id    uuid references menu_items(id) on delete cascade,
  size_id    uuid references menu_sizes(id) on delete set null,
  kind       text not null,           -- created | recipe | price | status | category | copy | image | update
  summary    text not null,
  detail     jsonb,
  actor      uuid references staff(id),
  created_at timestamptz not null default now()
);
create index if not exists menu_events_item_idx on menu_events (item_id, created_at desc);

alter table menu_categories      enable row level security;
alter table recipe_versions      enable row level security;
alter table recipe_version_lines enable row level security;
alter table price_changes        enable row level security;
alter table menu_events          enable row level security;
-- Chỉ chủ đọc được; GHI chỉ qua các hàm bên dưới (security definer)
grant select on menu_categories, recipe_versions, recipe_version_lines, price_changes, menu_events to authenticated;
drop policy if exists menu_categories_read on menu_categories;
create policy menu_categories_read on menu_categories for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
drop policy if exists recipe_versions_read on recipe_versions;
create policy recipe_versions_read on recipe_versions for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner()));
drop policy if exists recipe_version_lines_read on recipe_version_lines;
create policy recipe_version_lines_read on recipe_version_lines for select to authenticated
  using (exists (select 1 from recipe_versions v where v.id = version_id and v.shop_id = (select app_shop_id()) and (select app_is_owner())));
drop policy if exists price_changes_read on price_changes;
create policy price_changes_read on price_changes for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner()));
drop policy if exists menu_events_read on menu_events;
create policy menu_events_read on menu_events for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- ---------- 2) Dữ liệu cũ: danh mục từ group_name, công thức hiện tại thành phiên bản 1 ----------
insert into menu_categories (shop_id, name, sort_order)
select shop_id, name, (row_number() over (partition by shop_id order by name))::integer
  from (select distinct shop_id, btrim(group_name) as name from menu_items
         where group_name is not null and btrim(group_name) <> '') g
 where not exists (select 1 from menu_categories c
                    where c.shop_id = g.shop_id and lower(btrim(c.name)) = lower(g.name))
on conflict do nothing;

with todo as (
  select ms.id as size_id, ms.shop_id
    from menu_sizes ms
   where exists (select 1 from recipe_lines rl where rl.size_id = ms.id)
     and not exists (select 1 from recipe_versions rv where rv.size_id = ms.id)
), ins as (
  insert into recipe_versions (shop_id, size_id, version_no, status, effective_from, applied_at)
  select shop_id, size_id, 1, 'active', timestamptz '1970-01-01', now() from todo
  returning id, size_id
)
insert into recipe_version_lines (version_id, ingredient_id, qty)
select ins.id, rl.ingredient_id, rl.qty from ins join recipe_lines rl on rl.size_id = ins.size_id;

-- ---------- 3) Hàm nội bộ ----------
create or replace function _menu_event(p_item uuid, p_size uuid, p_kind text, p_summary text, p_detail jsonb default null)
returns void language sql security definer set search_path = public as $$
  insert into menu_events (shop_id, item_id, size_id, kind, summary, detail, actor)
  values (app_shop_id(), p_item, p_size, p_kind, p_summary, p_detail, app_staff_id())
$$;

-- Công thức có hiệu lực tại một thời điểm (dùng cho đối soát: ca cũ vẫn tính theo công thức cũ)
create or replace function _recipe_at(p_size uuid, p_at timestamptz)
returns table (ingredient_id uuid, qty integer)
language sql stable security definer set search_path = public as $$
  select l.ingredient_id, l.qty
    from recipe_version_lines l
   where l.version_id = (select v.id from recipe_versions v
                          where v.size_id = p_size and v.status in ('active','superseded')
                            and v.effective_from <= p_at
                          order by v.version_no desc limit 1)
  union all
  select rl.ingredient_id, rl.qty
    from recipe_lines rl
   where rl.size_id = p_size
     and not exists (select 1 from recipe_versions v where v.size_id = p_size and v.status in ('active','superseded'))
$$;

create or replace function _recipe_activate(p_version uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v recipe_versions%rowtype;
begin
  select * into v from recipe_versions where id = p_version for update;
  if not found or v.status <> 'scheduled' then return; end if;
  perform set_config('fore.recipe_apply', 'on', true);
  delete from recipe_lines where size_id = v.size_id;
  insert into recipe_lines (shop_id, size_id, ingredient_id, qty)
  select v.shop_id, v.size_id, l.ingredient_id, l.qty from recipe_version_lines l where l.version_id = v.id;
  perform set_config('fore.recipe_apply', 'off', true);
  update recipe_versions set status = 'superseded' where size_id = v.size_id and status = 'active';
  update recipe_versions set status = 'active', applied_at = now() where id = v.id;
end $$;

-- Áp dụng các công thức và giá đã hẹn tới giờ (gọi ở pay_bill, add_bill_line, menu_for_sale và các hàm thực đơn)
create or replace function _menu_apply_due(p_shop uuid default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := coalesce(p_shop, app_shop_id()); r record;
begin
  if v_shop is null then return; end if;
  for r in select id from recipe_versions
            where shop_id = v_shop and status = 'scheduled' and effective_from <= now()
            order by effective_from, version_no loop
    perform _recipe_activate(r.id);
  end loop;
  for r in select id, size_id, new_price from price_changes
            where shop_id = v_shop and status = 'scheduled' and effective_from <= now()
            order by effective_from for update skip locked loop
    update menu_sizes set price = r.new_price where id = r.size_id;
    update price_changes set status = 'applied', applied_at = now() where id = r.id;
  end loop;
end $$;

-- ---------- 4) Đọc ----------
create or replace function menu_ingredients() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return jsonb_build_object(
    'cost_updated_at', (select max(unit_cost_updated_at) from ingredients where shop_id = app_shop_id()),
    'items', coalesce((select jsonb_agg(jsonb_build_object(
        'id', i.id, 'name', i.name, 'unit', i.unit, 'group_name', i.group_name,
        'unit_cost', i.unit_cost, 'unit_cost_updated_at', i.unit_cost_updated_at) order by i.name)
      from ingredients i where i.shop_id = app_shop_id() and i.active), '[]'::jsonb));
end $$;

create or replace function menu_overview() returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
  v_low integer;
  v_week_from date;
  v_week_ts timestamptz;
  v_n integer;
begin
  perform _require_owner();
  perform _menu_apply_due(v_shop);
  v_low := _setting('menu_low_margin_pct', 30, v_shop);
  -- Tuần kinh doanh: từ thứ Hai 06:00 (giờ Việt Nam)
  v_week_from := date_trunc('week', (now() at time zone 'Asia/Ho_Chi_Minh') - interval '6 hours')::date;
  v_week_ts := (v_week_from + time '06:00') at time zone 'Asia/Ho_Chi_Minh';
  select count(*) into v_n from menu_items where shop_id = v_shop and not is_draft;

  return (
    with sold as (
      select bl.size_id, sum(bl.qty)::integer as q
        from bill_lines bl join bills b on b.id = bl.bill_id and b.status = 'paid'
       where bl.shop_id = v_shop and bl.voided_at is null and b.paid_at >= v_week_ts
       group by bl.size_id
    ), rc as (
      select rl.size_id, round(sum(rl.qty * i.unit_cost))::integer as cost,
             bool_and(i.unit_cost is not null) as known, count(*)::integer as n
        from recipe_lines rl join ingredients i on i.id = rl.ingredient_id
       where rl.shop_id = v_shop group by rl.size_id
    ), sz as (
      select ms.item_id,
             jsonb_agg(jsonb_build_object(
               'id', ms.id, 'name', ms.size_name, 'price', ms.price, 'active', ms.active,
               'has_recipe', coalesce(rc.n, 0) > 0,
               'cost', case when rc.known then rc.cost end,
               'cost_known', coalesce(rc.known, false),
               'recipe_version', (select max(v.version_no) from recipe_versions v where v.size_id = ms.id and v.status = 'active'),
               'scheduled_from', (select v.effective_from from recipe_versions v where v.size_id = ms.id and v.status = 'scheduled' order by v.version_no desc limit 1),
               'pending_price', (select p.new_price from price_changes p where p.size_id = ms.id and p.status = 'scheduled' order by p.created_at desc limit 1),
               'sold_week', coalesce(sold.q, 0)
             ) order by ms.price, ms.size_name) as sizes,
             sum(coalesce(sold.q, 0))::integer as sold_week
        from menu_sizes ms
        left join rc on rc.size_id = ms.id
        left join sold on sold.size_id = ms.id
       where ms.shop_id = v_shop
       group by ms.item_id
    ), ranked as (
      select mi.id, sz.sizes, coalesce(sz.sold_week, 0) as sold_week,
             rank() over (order by coalesce(sz.sold_week, 0) desc) as rk
        from menu_items mi left join sz on sz.item_id = mi.id
       where mi.shop_id = v_shop and not mi.is_draft
    )
    select jsonb_build_object(
      'low_margin_pct', v_low,
      'week_from', v_week_from,
      'week_to', v_week_from + 6,
      'cost_updated_at', (select max(unit_cost_updated_at) from ingredients where shop_id = v_shop),
      'categories', coalesce((select jsonb_agg(jsonb_build_object(
            'id', c.id, 'name', c.name, 'sort_order', c.sort_order,
            'item_count', (select count(*) from menu_items m where m.shop_id = v_shop
                            and lower(btrim(m.group_name)) = lower(btrim(c.name))))
            order by c.sort_order, c.name) from menu_categories c where c.shop_id = v_shop), '[]'::jsonb),
      'items', coalesce((select jsonb_agg(jsonb_build_object(
            'id', mi.id, 'name', mi.name, 'category', mi.group_name, 'active', mi.active,
            'is_draft', mi.is_draft, 'image_path', mi.image_path, 'description', mi.description,
            'sold_week', coalesce(sz.sold_week, 0),
            'best_seller', coalesce(sz.sold_week, 0) > 0
                           and (select rk from ranked where ranked.id = mi.id) <= case when v_n >= 4 then 2 else 1 end,
            'sizes', coalesce(sz.sizes, '[]'::jsonb))
            order by mi.is_draft desc, lower(mi.name))
          from menu_items mi left join sz on sz.item_id = mi.id where mi.shop_id = v_shop), '[]'::jsonb)
    )
  );
end $$;

create or replace function _menu_recipe_json(p_version uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'lines', coalesce(jsonb_agg(jsonb_build_object(
        'ingredient_id', i.id, 'name', i.name, 'unit', i.unit, 'qty', l.qty,
        'unit_cost', i.unit_cost,
        'line_cost', case when i.unit_cost is null then null else round(l.qty * i.unit_cost)::integer end)
        order by i.name), '[]'::jsonb),
    'cost', case when bool_and(i.unit_cost is not null) then round(sum(l.qty * i.unit_cost))::integer end,
    'cost_known', coalesce(bool_and(i.unit_cost is not null), false))
  from recipe_version_lines l join ingredients i on i.id = l.ingredient_id
 where l.version_id = p_version
$$;

create or replace function menu_item_detail(p_item uuid) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_item menu_items%rowtype; v_sizes jsonb;
begin
  perform _require_owner();
  perform _menu_apply_due(v_shop);
  select * into v_item from menu_items where id = p_item and shop_id = v_shop;
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
      'id', ms.id, 'name', ms.size_name, 'price', ms.price, 'active', ms.active,
      'ever_sold', exists (select 1 from bill_lines bl where bl.size_id = ms.id),
      'current', (select jsonb_build_object('version_id', v.id, 'version_no', v.version_no,
                         'effective_from', v.effective_from, 'applied_at', v.applied_at) || _menu_recipe_json(v.id)
                    from recipe_versions v where v.size_id = ms.id and v.status = 'active'),
      'scheduled', (select jsonb_build_object('version_id', v.id, 'version_no', v.version_no,
                         'effective_from', v.effective_from, 'created_at', v.created_at,
                         'created_by_name', (select s.full_name from staff s where s.id = v.created_by))
                         || _menu_recipe_json(v.id)
                    from recipe_versions v where v.size_id = ms.id and v.status = 'scheduled'
                    order by v.version_no desc limit 1),
      'pending_price', (select jsonb_build_object('change_id', p.id, 'new_price', p.new_price,
                         'effective_from', p.effective_from)
                    from price_changes p where p.size_id = ms.id and p.status = 'scheduled'
                    order by p.created_at desc limit 1)
    ) order by ms.price, ms.size_name), '[]'::jsonb)
    into v_sizes
    from menu_sizes ms where ms.item_id = p_item and ms.shop_id = v_shop;

  return jsonb_build_object(
    'item', jsonb_build_object('id', v_item.id, 'name', v_item.name, 'category', v_item.group_name,
        'active', v_item.active, 'is_draft', v_item.is_draft, 'description', v_item.description,
        'image_path', v_item.image_path),
    'low_margin_pct', _setting('menu_low_margin_pct', 30, v_shop),
    'sizes', v_sizes);
end $$;

create or replace function menu_recipe_versions(p_size uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  if not exists (select 1 from menu_sizes where id = p_size and shop_id = app_shop_id()) then
    raise exception 'MENU_SIZE_NOT_FOUND';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
      'id', v.id, 'version_no', v.version_no, 'status', v.status,
      'effective_from', v.effective_from, 'applied_at', v.applied_at, 'created_at', v.created_at,
      'created_by_name', (select s.full_name from staff s where s.id = v.created_by), 'note', v.note)
      || _menu_recipe_json(v.id) order by v.version_no desc)
    from recipe_versions v where v.size_id = p_size and v.status <> 'cancelled'), '[]'::jsonb);
end $$;

create or replace function menu_item_history(p_item uuid, p_limit integer default 50) returns jsonb
language plpgsql volatile security definer set search_path = public as $$
declare v_shop uuid := app_shop_id();
begin
  perform _require_owner();
  perform _menu_apply_due(v_shop);
  if not exists (select 1 from menu_items where id = p_item and shop_id = v_shop) then
    raise exception 'MENU_ITEM_NOT_FOUND';
  end if;
  return jsonb_build_object(
    'upcoming', coalesce((
      select jsonb_agg(x order by (x->>'effective_from')) from (
        select jsonb_build_object('kind', 'recipe', 'id', v.id, 'size_name', ms.size_name,
               'version_no', v.version_no, 'effective_from', v.effective_from, 'created_at', v.created_at,
               'actor_name', (select s.full_name from staff s where s.id = v.created_by)) as x
          from recipe_versions v join menu_sizes ms on ms.id = v.size_id
         where ms.item_id = p_item and v.status = 'scheduled'
        union all
        select jsonb_build_object('kind', 'price', 'id', p.id, 'size_name', ms.size_name,
               'old_price', p.old_price, 'new_price', p.new_price,
               'effective_from', p.effective_from, 'created_at', p.created_at,
               'actor_name', (select s.full_name from staff s where s.id = p.created_by))
          from price_changes p join menu_sizes ms on ms.id = p.size_id
         where ms.item_id = p_item and p.status = 'scheduled') u), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object('id', e.id, 'kind', e.kind, 'summary', e.summary, 'detail', e.detail,
               'actor_name', (select s.full_name from staff s where s.id = e.actor), 'created_at', e.created_at)
               order by e.created_at desc)
        from (select * from menu_events where item_id = p_item and shop_id = v_shop
               order by created_at desc limit greatest(1, least(coalesce(p_limit, 50), 200))) e), '[]'::jsonb));
end $$;

create or replace function menu_categories_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return coalesce((select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'sort_order', c.sort_order,
      'item_count', (select count(*) from menu_items m where m.shop_id = c.shop_id
                      and lower(btrim(m.group_name)) = lower(btrim(c.name)))) order by c.sort_order, c.name)
    from menu_categories c where c.shop_id = app_shop_id()), '[]'::jsonb);
end $$;

-- ---------- 5) Ghi: món và size ----------
create or replace function menu_item_create(p_name text, p_category text, p_sizes jsonb, p_publish boolean default false)
returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id(); v_name text := btrim(coalesce(p_name, '')); v_cat text := nullif(btrim(coalesce(p_category, '')), '');
  v_item uuid; v_s jsonb; v_sname text; v_price integer; v_seen text[] := '{}';
begin
  perform _require_owner();
  if v_name = '' then raise exception 'MENU_NAME_REQUIRED'; end if;
  if exists (select 1 from menu_items where shop_id = v_shop and lower(btrim(name)) = lower(v_name)) then
    raise exception 'MENU_NAME_DUPLICATE';
  end if;
  if v_cat is not null then
    select name into v_cat from menu_categories where shop_id = v_shop and lower(btrim(name)) = lower(v_cat);
    if v_cat is null then raise exception 'CATEGORY_NOT_FOUND'; end if;
  end if;
  if p_sizes is null or jsonb_typeof(p_sizes) <> 'array' or jsonb_array_length(p_sizes) = 0 then
    raise exception 'MENU_SIZE_REQUIRED';
  end if;
  for v_s in select * from jsonb_array_elements(p_sizes) loop
    v_sname := btrim(coalesce(v_s->>'name', ''));
    if v_sname = '' then raise exception 'SIZE_NAME_REQUIRED'; end if;
    if lower(v_sname) = any (v_seen) then raise exception 'SIZE_NAME_DUPLICATE'; end if;
    v_seen := v_seen || lower(v_sname);
    v_price := (v_s->>'price')::integer;
    if v_price is null or v_price <= 0 then raise exception 'PRICE_INVALID'; end if;
  end loop;

  insert into menu_items (shop_id, name, group_name, active, is_draft)
  values (v_shop, v_name, v_cat, coalesce(p_publish, false), not coalesce(p_publish, false))
  returning id into v_item;
  for v_s in select * from jsonb_array_elements(p_sizes) loop
    insert into menu_sizes (shop_id, item_id, size_name, price, active)
    values (v_shop, v_item, btrim(v_s->>'name'), (v_s->>'price')::integer, true);
  end loop;
  perform _menu_event(v_item, null, 'created',
    case when coalesce(p_publish, false) then 'Tạo món và mở bán' else 'Lưu bản nháp (chưa bán)' end,
    jsonb_build_object('sizes', p_sizes));
  return v_item;
end $$;

create or replace function menu_item_update(p_item uuid, p_name text, p_category text, p_description text default null)
returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_name text := btrim(coalesce(p_name, '')); v_cat text := nullif(btrim(coalesce(p_category, '')), ''); v_old menu_items%rowtype;
begin
  perform _require_owner();
  select * into v_old from menu_items where id = p_item and shop_id = v_shop for update;
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if v_name = '' then raise exception 'MENU_NAME_REQUIRED'; end if;
  if exists (select 1 from menu_items where shop_id = v_shop and id <> p_item and lower(btrim(name)) = lower(v_name)) then
    raise exception 'MENU_NAME_DUPLICATE';
  end if;
  if v_cat is not null then
    select name into v_cat from menu_categories where shop_id = v_shop and lower(btrim(name)) = lower(v_cat);
    if v_cat is null then raise exception 'CATEGORY_NOT_FOUND'; end if;
  end if;
  update menu_items set name = v_name, group_name = v_cat, description = nullif(btrim(coalesce(p_description, '')), '')
   where id = p_item;
  if v_old.name is distinct from v_name then
    perform _menu_event(p_item, null, 'update', 'Đổi tên từ "' || v_old.name || '" thành "' || v_name || '"');
  end if;
  if v_old.group_name is distinct from v_cat then
    perform _menu_event(p_item, null, 'category', 'Đổi nhóm món: ' || coalesce(v_old.group_name, 'Khác') || ' → ' || coalesce(v_cat, 'Khác'));
  end if;
end $$;

create or replace function menu_size_add(p_item uuid, p_name text, p_price integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_name text := btrim(coalesce(p_name, '')); v_id uuid; v_old menu_sizes%rowtype;
begin
  perform _require_owner();
  if not exists (select 1 from menu_items where id = p_item and shop_id = v_shop) then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if v_name = '' then raise exception 'SIZE_NAME_REQUIRED'; end if;
  if p_price is null or p_price <= 0 then raise exception 'PRICE_INVALID'; end if;
  select * into v_old from menu_sizes where item_id = p_item and lower(btrim(size_name)) = lower(v_name) for update;
  if found then
    if v_old.active then raise exception 'SIZE_NAME_DUPLICATE'; end if;
    -- size đã ẩn trước đó: bật lại (giữ lịch sử và công thức cũ) với giá mới
    update menu_sizes set active = true, price = p_price where id = v_old.id;
    perform _menu_event(p_item, v_old.id, 'update', 'Bật lại size ' || v_old.size_name || ' · giá ' || p_price);
    return v_old.id;
  end if;
  insert into menu_sizes (shop_id, item_id, size_name, price, active) values (v_shop, p_item, v_name, p_price, true)
  returning id into v_id;
  perform _menu_event(p_item, v_id, 'update', 'Thêm size ' || v_name || ' · giá ' || p_price);
  return v_id;
end $$;

-- Dữ liệu bán hàng không bị xóa: bỏ size = ẩn size (active = false), có thể bật lại bằng menu_size_add cùng tên
create or replace function menu_size_remove(p_size uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_ms menu_sizes%rowtype; v_left integer;
begin
  perform _require_owner();
  select * into v_ms from menu_sizes where id = p_size and shop_id = v_shop for update;
  if not found then raise exception 'MENU_SIZE_NOT_FOUND'; end if;
  if not v_ms.active then return; end if;
  select count(*) into v_left from menu_sizes where item_id = v_ms.item_id and active and id <> p_size;
  if v_left = 0 then raise exception 'LAST_SIZE'; end if;
  update menu_sizes set active = false where id = p_size;
  update recipe_versions set status = 'cancelled' where size_id = p_size and status = 'scheduled';
  update price_changes set status = 'cancelled' where size_id = p_size and status = 'scheduled';
  perform _menu_event(v_ms.item_id, p_size, 'status', 'Ngừng bán size ' || v_ms.size_name);
end $$;

create or replace function menu_item_set_active(p_item uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v menu_items%rowtype;
begin
  perform _require_owner();
  select * into v from menu_items where id = p_item and shop_id = app_shop_id() for update;
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if v.is_draft then raise exception 'ITEM_IS_DRAFT'; end if;
  if v.active = coalesce(p_active, false) then return; end if;
  update menu_items set active = coalesce(p_active, false) where id = p_item;
  perform _menu_event(p_item, null, 'status',
    case when p_active then 'Mở bán lại' else 'Tạm ngừng bán' end,
    jsonb_build_object('from', case when v.active then 'Đang bán' else 'Ngừng bán' end,
                       'to', case when p_active then 'Đang bán' else 'Ngừng bán' end));
end $$;

create or replace function menu_item_publish(p_item uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v menu_items%rowtype;
begin
  perform _require_owner();
  select * into v from menu_items where id = p_item and shop_id = app_shop_id() for update;
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if not exists (select 1 from menu_sizes where item_id = p_item and active) then raise exception 'MENU_SIZE_REQUIRED'; end if;
  update menu_items set is_draft = false, active = true where id = p_item;
  perform _menu_event(p_item, null, 'status', 'Mở bán món');
end $$;

create or replace function menu_item_set_image(p_item uuid, p_path text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();
  update menu_items set image_path = nullif(btrim(coalesce(p_path, '')), '') where id = p_item and shop_id = app_shop_id();
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  perform _menu_event(p_item, null, 'image', case when nullif(btrim(coalesce(p_path, '')), '') is null then 'Gỡ ảnh món' else 'Đổi ảnh món' end);
end $$;

-- ---------- 6) Ghi: công thức, giá ----------
create or replace function menu_recipe_save(p_size uuid, p_lines jsonb, p_effective timestamptz default null, p_note text default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id(); v_ms menu_sizes%rowtype; v_eff timestamptz; v_no integer; v_id uuid;
  v_l jsonb; v_ing uuid; v_qty integer; v_seen uuid[] := '{}'; v_last uuid; v_same boolean; v_status text;
begin
  perform _require_owner();
  perform _menu_apply_due(v_shop);
  select * into v_ms from menu_sizes where id = p_size and shop_id = v_shop for update;
  if not found then raise exception 'MENU_SIZE_NOT_FOUND'; end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' or jsonb_array_length(p_lines) = 0 then
    raise exception 'RECIPE_EMPTY';
  end if;
  for v_l in select * from jsonb_array_elements(p_lines) loop
    v_ing := (v_l->>'ingredient_id')::uuid;
    v_qty := (v_l->>'qty')::integer;
    if not exists (select 1 from ingredients where id = v_ing and shop_id = v_shop and active) then
      raise exception 'INGREDIENT_NOT_FOUND';
    end if;
    if v_qty is null or v_qty <= 0 then raise exception 'QTY_INVALID'; end if;
    if v_ing = any (v_seen) then raise exception 'INGREDIENT_DUPLICATE'; end if;
    v_seen := v_seen || v_ing;
  end loop;

  v_eff := coalesce(p_effective, now());
  if v_eff > now() + interval '365 days' then raise exception 'EFFECTIVE_INVALID'; end if;
  if v_eff < now() then v_eff := now(); end if;

  -- Không đổi gì so với bản mới nhất (đang dùng hoặc đã hẹn) thì không tạo phiên bản
  select id into v_last from recipe_versions
   where size_id = p_size and status in ('active','scheduled') order by version_no desc limit 1;
  if v_last is not null then
    select not exists (
             (select ingredient_id, qty from recipe_version_lines where version_id = v_last
              except select (e->>'ingredient_id')::uuid, (e->>'qty')::integer from jsonb_array_elements(p_lines) e)
             union all
             (select (e->>'ingredient_id')::uuid, (e->>'qty')::integer from jsonb_array_elements(p_lines) e
              except select ingredient_id, qty from recipe_version_lines where version_id = v_last))
      into v_same;
    if v_same then raise exception 'RECIPE_UNCHANGED'; end if;
  end if;

  update recipe_versions set status = 'cancelled' where size_id = p_size and status = 'scheduled';
  select coalesce(max(version_no), 0) + 1 into v_no from recipe_versions where size_id = p_size;
  insert into recipe_versions (shop_id, size_id, version_no, status, effective_from, note, created_by)
  values (v_shop, p_size, v_no, 'scheduled', v_eff, nullif(btrim(coalesce(p_note, '')), ''), app_staff_id())
  returning id into v_id;
  insert into recipe_version_lines (version_id, ingredient_id, qty)
  select v_id, (e->>'ingredient_id')::uuid, (e->>'qty')::integer from jsonb_array_elements(p_lines) e;
  if v_eff <= now() then perform _recipe_activate(v_id); end if;
  select status into v_status from recipe_versions where id = v_id;

  perform _menu_event(v_ms.item_id, p_size, 'recipe',
    'Công thức size ' || v_ms.size_name || ' v' || v_no || case when v_status = 'active' then ' đang dùng' else ' đã lên lịch' end,
    jsonb_build_object('size_name', v_ms.size_name, 'version_no', v_no, 'status', v_status, 'effective_from', v_eff));
  return jsonb_build_object('version_id', v_id, 'version_no', v_no, 'status', v_status, 'effective_from', v_eff);
end $$;

create or replace function menu_recipe_cancel(p_version uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v recipe_versions%rowtype; v_ms menu_sizes%rowtype;
begin
  perform _require_owner();
  select * into v from recipe_versions where id = p_version and shop_id = app_shop_id() for update;
  if not found then raise exception 'RECIPE_VERSION_NOT_FOUND'; end if;
  if v.status <> 'scheduled' then raise exception 'RECIPE_VERSION_NOT_SCHEDULED'; end if;
  update recipe_versions set status = 'cancelled' where id = p_version;
  select * into v_ms from menu_sizes where id = v.size_id;
  perform _menu_event(v_ms.item_id, v.size_id, 'recipe', 'Hủy lịch công thức size ' || v_ms.size_name || ' v' || v.version_no);
end $$;

create or replace function menu_price_change(p_changes jsonb, p_effective timestamptz default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id(); v_eff timestamptz; v_c jsonb; v_ms menu_sizes%rowtype; v_new integer;
  v_now boolean; v_n integer := 0; v_item uuid; v_log jsonb := '[]'::jsonb;
begin
  perform _require_owner();
  perform _menu_apply_due(v_shop);
  if p_changes is null or jsonb_typeof(p_changes) <> 'array' or jsonb_array_length(p_changes) = 0 then
    raise exception 'PRICE_UNCHANGED';
  end if;
  v_eff := coalesce(p_effective, now());
  if v_eff > now() + interval '365 days' then raise exception 'EFFECTIVE_INVALID'; end if;
  if v_eff < now() then v_eff := now(); end if;
  v_now := v_eff <= now();

  for v_c in select * from jsonb_array_elements(p_changes) loop
    select * into v_ms from menu_sizes where id = (v_c->>'size_id')::uuid and shop_id = v_shop for update;
    if not found then raise exception 'MENU_SIZE_NOT_FOUND'; end if;
    v_new := (v_c->>'price')::integer;
    if v_new is null or v_new <= 0 then raise exception 'PRICE_INVALID'; end if;
    if v_new = v_ms.price and not exists (select 1 from price_changes where size_id = v_ms.id and status = 'scheduled') then
      continue;
    end if;
    update price_changes set status = 'cancelled' where size_id = v_ms.id and status = 'scheduled';
    if v_new = v_ms.price then continue; end if;
    insert into price_changes (shop_id, size_id, old_price, new_price, status, effective_from, applied_at, created_by)
    values (v_shop, v_ms.id, v_ms.price, v_new, case when v_now then 'applied' else 'scheduled' end, v_eff,
            case when v_now then now() end, app_staff_id());
    if v_now then update menu_sizes set price = v_new where id = v_ms.id; end if;
    v_n := v_n + 1; v_item := v_ms.item_id;
    v_log := v_log || jsonb_build_object('size_id', v_ms.id, 'size_name', v_ms.size_name, 'old', v_ms.price, 'new', v_new);
  end loop;
  if v_n = 0 then raise exception 'PRICE_UNCHANGED'; end if;
  perform _menu_event(v_item, null, 'price',
    case when v_now then 'Đổi giá bán' else 'Hẹn đổi giá bán' end,
    jsonb_build_object('changes', v_log, 'effective_from', v_eff, 'applied', v_now));
  return jsonb_build_object('applied', v_now, 'effective_from', v_eff, 'count', v_n);
end $$;

create or replace function menu_price_cancel(p_change uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v price_changes%rowtype; v_ms menu_sizes%rowtype;
begin
  perform _require_owner();
  select * into v from price_changes where id = p_change and shop_id = app_shop_id() for update;
  if not found then raise exception 'PRICE_CHANGE_NOT_FOUND'; end if;
  if v.status <> 'scheduled' then raise exception 'PRICE_CHANGE_NOT_SCHEDULED'; end if;
  update price_changes set status = 'cancelled' where id = p_change;
  select * into v_ms from menu_sizes where id = v.size_id;
  perform _menu_event(v_ms.item_id, v.size_id, 'price', 'Hủy lịch đổi giá size ' || v_ms.size_name);
end $$;

create or replace function set_ingredient_cost(p_ingredient uuid, p_cost numeric) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();
  if p_cost is not null and p_cost < 0 then raise exception 'COST_INVALID'; end if;
  update ingredients set unit_cost = p_cost, unit_cost_updated_at = now()
   where id = p_ingredient and shop_id = app_shop_id();
  if not found then raise exception 'INGREDIENT_NOT_FOUND'; end if;
end $$;

create or replace function menu_set_low_margin(p_pct integer) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();
  if p_pct is null or p_pct < 0 or p_pct > 90 then raise exception 'SETTING_INVALID'; end if;
  insert into app_settings (shop_id, key, value_int, description)
  values (app_shop_id(), 'menu_low_margin_pct', p_pct, 'Lãi gộp của một size thấp hơn mức % này thì cảnh báo "Lãi thấp"')
  on conflict (shop_id, key) do update set value_int = excluded.value_int;
end $$;

-- ---------- 7) Danh mục ----------
create or replace function menu_category_add(p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_name text := btrim(coalesce(p_name, '')); v_id uuid;
begin
  perform _require_owner();
  if v_name = '' then raise exception 'CATEGORY_NAME_REQUIRED'; end if;
  if exists (select 1 from menu_categories where shop_id = app_shop_id() and lower(btrim(name)) = lower(v_name)) then
    raise exception 'CATEGORY_DUPLICATE';
  end if;
  insert into menu_categories (shop_id, name, sort_order)
  values (app_shop_id(), v_name, coalesce((select max(sort_order) from menu_categories where shop_id = app_shop_id()), 0) + 1)
  returning id into v_id;
  return v_id;
end $$;

create or replace function menu_category_rename(p_id uuid, p_name text) returns void
language plpgsql security definer set search_path = public as $$
declare v_name text := btrim(coalesce(p_name, '')); v_old text; v_shop uuid := app_shop_id();
begin
  perform _require_owner();
  select name into v_old from menu_categories where id = p_id and shop_id = v_shop for update;
  if not found then raise exception 'CATEGORY_NOT_FOUND'; end if;
  if v_name = '' then raise exception 'CATEGORY_NAME_REQUIRED'; end if;
  if exists (select 1 from menu_categories where shop_id = v_shop and id <> p_id and lower(btrim(name)) = lower(v_name)) then
    raise exception 'CATEGORY_DUPLICATE';
  end if;
  update menu_categories set name = v_name where id = p_id;
  update menu_items set group_name = v_name where shop_id = v_shop and lower(btrim(group_name)) = lower(btrim(v_old));
end $$;

create or replace function menu_category_reorder(p_ids uuid[]) returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_total integer;
begin
  perform _require_owner();
  select count(*) into v_total from menu_categories where shop_id = v_shop;
  if p_ids is null or coalesce(array_length(p_ids, 1), 0) <> v_total
     or (select count(distinct x) from unnest(p_ids) x) <> v_total
     or exists (select 1 from unnest(p_ids) x where not exists (select 1 from menu_categories c where c.id = x and c.shop_id = v_shop)) then
    raise exception 'CATEGORY_ORDER_INVALID';
  end if;
  update menu_categories c set sort_order = o.n::integer
    from unnest(p_ids) with ordinality as o(id, n) where c.id = o.id;
end $$;

-- ---------- 8) Sao chép ----------
create or replace function _menu_copy_item(p_item uuid, p_to_shop uuid, p_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_from uuid; v_src menu_items%rowtype; v_new uuid; v_cat text; v_s record; v_size uuid; v_ver uuid;
  v_lines integer := 0; v_skipped text[] := '{}'; v_l record; v_ing uuid;
begin
  select * into v_src from menu_items where id = p_item;
  v_from := v_src.shop_id;
  if exists (select 1 from menu_items where shop_id = p_to_shop and lower(btrim(name)) = lower(btrim(p_name))) then
    raise exception 'MENU_NAME_DUPLICATE';
  end if;
  v_cat := v_src.group_name;
  if v_cat is not null and not exists (select 1 from menu_categories where shop_id = p_to_shop and lower(btrim(name)) = lower(btrim(v_cat))) then
    insert into menu_categories (shop_id, name, sort_order)
    values (p_to_shop, v_cat, coalesce((select max(sort_order) from menu_categories where shop_id = p_to_shop), 0) + 1);
  end if;
  insert into menu_items (shop_id, name, group_name, active, is_draft, description, image_path)
  values (p_to_shop, btrim(p_name), v_cat, false, true, v_src.description,
          case when p_to_shop = v_from then v_src.image_path end)
  returning id into v_new;
  for v_s in select * from menu_sizes where item_id = p_item and active order by price, size_name loop
    insert into menu_sizes (shop_id, item_id, size_name, price, active)
    values (p_to_shop, v_new, v_s.size_name, v_s.price, true) returning id into v_size;
    v_ver := null;
    for v_l in select rl.qty, i.name, i.unit, rl.ingredient_id from recipe_lines rl join ingredients i on i.id = rl.ingredient_id
                where rl.size_id = v_s.id loop
      if p_to_shop = v_from then v_ing := v_l.ingredient_id;
      else
        select id into v_ing from ingredients
         where shop_id = p_to_shop and active and unit = v_l.unit and lower(btrim(name)) = lower(btrim(v_l.name));
        if v_ing is null then v_skipped := array_append(v_skipped, v_l.name); continue; end if;
      end if;
      if v_ver is null then
        insert into recipe_versions (shop_id, size_id, version_no, status, effective_from, applied_at, created_by)
        values (p_to_shop, v_size, 1, 'active', now(), now(), app_staff_id()) returning id into v_ver;
      end if;
      insert into recipe_version_lines (version_id, ingredient_id, qty) values (v_ver, v_ing, v_l.qty);
      perform set_config('fore.recipe_apply', 'on', true);
      insert into recipe_lines (shop_id, size_id, ingredient_id, qty) values (p_to_shop, v_size, v_ing, v_l.qty);
      perform set_config('fore.recipe_apply', 'off', true);
      v_lines := v_lines + 1;
    end loop;
  end loop;
  return jsonb_build_object('item_id', v_new, 'copied_lines', v_lines, 'skipped_ingredients', to_jsonb(v_skipped));
end $$;

create or replace function menu_item_copy(p_item uuid, p_new_name text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_r jsonb; v_name text := btrim(coalesce(p_new_name, ''));
begin
  perform _require_owner();
  if not exists (select 1 from menu_items where id = p_item and shop_id = v_shop) then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if v_name = '' then raise exception 'MENU_NAME_REQUIRED'; end if;
  v_r := _menu_copy_item(p_item, v_shop, v_name);
  perform _menu_event((v_r->>'item_id')::uuid, null, 'copy', 'Tạo bản sao từ "' || (select name from menu_items where id = p_item) || '" (bản nháp)');
  return v_r;
end $$;

create or replace function menu_copy_targets() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return coalesce((select jsonb_agg(jsonb_build_object('shop_id', s.shop_id, 'name', sh.name) order by sh.name)
    from staff s join shops sh on sh.id = s.shop_id
   where s.auth_user_id = auth.uid() and s.active and s.role = 'owner' and s.shop_id <> app_shop_id()), '[]'::jsonb);
end $$;

create or replace function menu_item_copy_to_shop(p_item uuid, p_shop uuid, p_new_name text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_src menu_items%rowtype; v_r jsonb; v_name text;
begin
  perform _require_owner();
  select * into v_src from menu_items where id = p_item and shop_id = app_shop_id();
  if not found then raise exception 'MENU_ITEM_NOT_FOUND'; end if;
  if p_shop is null or p_shop = app_shop_id() or not exists (
       select 1 from staff s where s.auth_user_id = auth.uid() and s.active and s.role = 'owner' and s.shop_id = p_shop) then
    raise exception 'OWNER_ONLY';
  end if;
  v_name := coalesce(nullif(btrim(coalesce(p_new_name, '')), ''), v_src.name);
  v_r := _menu_copy_item(p_item, p_shop, v_name);
  insert into menu_events (shop_id, item_id, kind, summary, detail, actor)
  values (p_shop, (v_r->>'item_id')::uuid, 'copy', 'Sao chép từ quán khác (bản nháp)', v_r,
          (select s.id from staff s where s.auth_user_id = auth.uid() and s.shop_id = p_shop and s.active limit 1));
  perform _menu_event(p_item, null, 'copy', 'Sao chép sang quán khác');
  return v_r;
end $$;

-- ---------- 9) Ảnh món (Supabase Storage; bỏ qua nếu không có schema storage, ví dụ khi test) ----------
do $$
begin
  if to_regclass('storage.buckets') is not null and to_regclass('storage.objects') is not null then
    insert into storage.buckets (id, name, public) values ('menu-images', 'menu-images', true) on conflict (id) do nothing;
    execute 'drop policy if exists menu_images_read on storage.objects';
    execute 'create policy menu_images_read on storage.objects for select using (bucket_id = ''menu-images'')';
    execute 'drop policy if exists menu_images_write on storage.objects';
    execute 'create policy menu_images_write on storage.objects for all to authenticated
             using (bucket_id = ''menu-images'' and (storage.foldername(name))[1] = (select app_shop_id())::text and (select app_is_owner()))
             with check (bucket_id = ''menu-images'' and (storage.foldername(name))[1] = (select app_shop_id())::text and (select app_is_owner()))';
  end if;
end $$;

-- ---------- 10) Quyền gọi ----------
revoke all on function
  menu_ingredients(), menu_overview(), menu_item_detail(uuid), menu_recipe_versions(uuid), menu_item_history(uuid, integer),
  menu_categories_list(), menu_item_create(text, text, jsonb, boolean), menu_item_update(uuid, text, text, text),
  menu_size_add(uuid, text, integer), menu_size_remove(uuid), menu_item_set_active(uuid, boolean), menu_item_publish(uuid),
  menu_item_set_image(uuid, text), menu_recipe_save(uuid, jsonb, timestamptz, text),
  menu_recipe_cancel(uuid), menu_price_change(jsonb, timestamptz), menu_price_cancel(uuid), set_ingredient_cost(uuid, numeric),
  menu_set_low_margin(integer), menu_category_add(text), menu_category_rename(uuid, text), menu_category_reorder(uuid[]),
  menu_item_copy(uuid, text), menu_copy_targets(), menu_item_copy_to_shop(uuid, uuid, text)
  from public, anon;
grant execute on function
  menu_ingredients(), menu_overview(), menu_item_detail(uuid), menu_recipe_versions(uuid), menu_item_history(uuid, integer),
  menu_categories_list(), menu_item_create(text, text, jsonb, boolean), menu_item_update(uuid, text, text, text),
  menu_size_add(uuid, text, integer), menu_size_remove(uuid), menu_item_set_active(uuid, boolean), menu_item_publish(uuid),
  menu_item_set_image(uuid, text), menu_recipe_save(uuid, jsonb, timestamptz, text),
  menu_recipe_cancel(uuid), menu_price_change(jsonb, timestamptz), menu_price_cancel(uuid), set_ingredient_cost(uuid, numeric),
  menu_set_low_margin(integer), menu_category_add(text), menu_category_rename(uuid, text), menu_category_reorder(uuid[]),
  menu_item_copy(uuid, text), menu_copy_targets(), menu_item_copy_to_shop(uuid, uuid, text)
  to authenticated;
revoke all on function _menu_event(uuid, uuid, text, text, jsonb), _recipe_at(uuid, timestamptz), _recipe_activate(uuid),
  _menu_apply_due(uuid), _menu_recipe_json(uuid), _menu_copy_item(uuid, uuid, text) from public, anon, authenticated;
