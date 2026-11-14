-- Fore · 07_inventory.sql
-- Module KHO v2: nhóm nguyên liệu, nhà cung cấp, lô hàng + hạn dùng, phiếu nhập nhiều dòng,
-- giá nhập / giá bình quân, kiểm kê có duyệt, hao hụt theo lô, gợi ý nhập hàng, tổng quan kho.
-- Chạy SAU 06_menu_options.sql và TRƯỚC 08_settings.sql (một số hàm đọc quyền theo vai trò từ 08: _require_perm).
-- Chạy lại nhiều lần không hỏng (idempotent).
--
-- NGUYÊN TẮC (giữ đúng tinh thần các module trước):
--   · Sổ kho (stock_ledger) vẫn là nguồn sự thật duy nhất của tồn kho. Không có cột "tồn" để sửa tay.
--   · Tồn dự kiến = lần đếm gần nhất (stock_counts) + các dòng sổ kho sau đó (giống v_expected_stock),
--     nhưng nguyên liệu CHƯA TỪNG ĐẾM vẫn có tồn (= tổng sổ kho) để phiếu nhập đầu tiên hiện được.
--   · Nhân viên KHÔNG BAO GIỜ nhận số tồn hệ thống hay giá (đếm mù). Chỉ chủ xem.
--   · Mọi thay đổi tồn đều có phiếu và người ghi: PN-xxxx nhập, KK-xxxx kiểm kê, HH-xxxx hao hụt.
--   · Giá nhập MỚI khác giá BÌNH QUÂN: giá bình quân gia quyền cập nhật khi xác nhận phiếu nhập;
--     giá bán KHÔNG tự đổi.
--   · Mã tiền là số nguyên đồng; đơn giá lưu theo ĐƠN VỊ GỐC (ml, g, cái) → 50.000đ/lít = 50đ/ml.

-- ======================================================================
-- 1) Mở rộng bảng có sẵn
-- ======================================================================
alter table ingredients add column if not exists default_supplier_id uuid;
alter table ingredients add column if not exists storage_note text;
alter table ingredients add column if not exists last_purchase_cost numeric(14,4) check (last_purchase_cost is null or last_purchase_cost >= 0);
alter table ingredients add column if not exists last_purchase_at timestamptz;

-- Sổ kho thêm loại "adjust" (điều chỉnh sau kiểm kê được chủ duyệt) và cho phép ngoài ca
alter table stock_ledger drop constraint if exists stock_ledger_kind_check;
alter table stock_ledger add constraint stock_ledger_kind_check
  check (kind in ('purchase', 'sale', 'void_sale', 'waste', 'adjust'));
alter table stock_ledger alter column shift_id drop not null;

alter table waste_logs add column if not exists code text;
alter table waste_logs add column if not exists lot_id uuid;

-- ======================================================================
-- 2) Bảng mới
-- ======================================================================
create table if not exists inv_code_counters (
  shop_id  uuid not null references shops(id),
  prefix   text not null,
  day_key  text not null,
  n        integer not null default 0,
  primary key (shop_id, prefix, day_key)
);

create table if not exists ingredient_groups (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null default app_shop_id() references shops(id),
  name        text not null check (char_length(btrim(name)) between 1 and 60),
  sort_order  integer not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (shop_id, id)
);
create unique index if not exists ingredient_groups_name_uq on ingredient_groups (shop_id, lower(btrim(name)));

create table if not exists suppliers (
  id               uuid primary key default gen_random_uuid(),
  shop_id          uuid not null default app_shop_id() references shops(id),
  name             text not null check (char_length(btrim(name)) between 1 and 80),
  contact_name     text,
  phone            text,
  email            text,
  address          text,
  lead_days        integer not null default 1 check (lead_days between 0 and 30),
  delivery_window  text,                 -- "07:00–10:00"
  order_cutoff     text,                 -- "16:00" (giờ chốt đặt hàng trong ngày)
  note             text,
  active           boolean not null default true,
  created_at       timestamptz not null default now(),
  unique (shop_id, id)
);
create unique index if not exists suppliers_name_uq on suppliers (shop_id, lower(btrim(name)));

create table if not exists purchase_orders (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null default app_shop_id() references shops(id),
  code           text not null,
  supplier_id    uuid,
  status         text not null default 'draft' check (status in ('draft', 'confirmed', 'cancelled')),
  source         text not null default 'owner' check (source in ('owner', 'staff', 'suggestion')),
  note           text,
  vat_included   boolean not null default true,
  shipping_fee   integer not null default 0 check (shipping_fee >= 0),
  received_at    timestamptz,
  needs_pricing  boolean not null default false,   -- nhân viên nhận hàng, chủ chưa bổ sung giá
  total_amount   bigint,
  cancel_reason  text,
  created_by     uuid references staff(id),
  confirmed_by   uuid references staff(id),
  confirmed_at   timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  unique (shop_id, id),
  unique (shop_id, code)
);
create index if not exists purchase_orders_status_idx on purchase_orders (shop_id, status, created_at desc);

create table if not exists purchase_order_lines (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null default app_shop_id() references shops(id),
  order_id       uuid not null references purchase_orders(id) on delete cascade,
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),                       -- đơn vị gốc
  unit_price     numeric(14,4) check (unit_price is null or unit_price >= 0),  -- đồng / đơn vị gốc
  lot_code       text,
  expiry_date    date,
  lot_id         uuid,
  created_at     timestamptz not null default now()
);
create index if not exists purchase_order_lines_order_idx on purchase_order_lines (order_id);

create table if not exists stock_lots (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null default app_shop_id() references shops(id),
  ingredient_id  uuid not null references ingredients(id),
  code           text not null,
  received_at    timestamptz not null,
  expiry_date    date,
  qty_received   integer not null check (qty_received > 0),
  unit_cost      numeric(14,4),
  order_line_id  uuid,
  created_at     timestamptz not null default now(),
  unique (shop_id, id)
);
create index if not exists stock_lots_ing_idx on stock_lots (ingredient_id, received_at desc);

create table if not exists ingredient_cost_events (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null default app_shop_id() references shops(id),
  ingredient_id  uuid not null references ingredients(id),
  at             timestamptz not null default now(),
  kind           text not null check (kind in ('purchase', 'manual')),
  price          numeric(14,4),        -- giá nhập của lần này (đồng / đơn vị gốc)
  avg_before     numeric(14,4),
  avg_after      numeric(14,4),
  qty            integer,
  order_id       uuid,
  created_by     uuid references staff(id)
);
create index if not exists ingredient_cost_events_ing_idx on ingredient_cost_events (ingredient_id, at desc);

create table if not exists stocktakes (
  id             uuid primary key default gen_random_uuid(),
  shop_id        uuid not null default app_shop_id() references shops(id),
  code           text not null,
  status         text not null default 'draft' check (status in ('draft', 'submitted', 'recount', 'approved')),
  started_by     uuid not null references staff(id),
  started_at     timestamptz not null default now(),
  saved_at       timestamptz,
  submitted_at   timestamptz,
  reviewed_by    uuid references staff(id),
  reviewed_at    timestamptz,
  review_reason  text,
  review_note    text,
  unique (shop_id, id),
  unique (shop_id, code)
);
create unique index if not exists stocktakes_one_draft_uq on stocktakes (shop_id, started_by) where status in ('draft', 'recount');

create table if not exists stocktake_lines (
  id                 uuid primary key default gen_random_uuid(),
  shop_id            uuid not null default app_shop_id() references shops(id),
  stocktake_id       uuid not null references stocktakes(id) on delete cascade,
  ingredient_id      uuid not null references ingredients(id),
  counted_qty        integer check (counted_qty is null or counted_qty >= 0),
  counted_at         timestamptz,
  system_qty         integer,                 -- chụp lúc ĐẾM (st_save); không bao giờ trả cho nhân viên
  unit_cost          numeric(14,4),
  recount_requested  boolean not null default false,
  recount_prev_qty   integer,
  decision           text check (decision is null or decision in ('adjust', 'keep')),
  unique (stocktake_id, ingredient_id)
);

create table if not exists inventory_requests (
  id           uuid primary key default gen_random_uuid(),
  shop_id      uuid not null default app_shop_id() references shops(id),
  kind         text not null check (kind in ('waste', 'purchase')),
  ref_id       uuid not null,
  note         text not null check (char_length(btrim(note)) >= 3),
  status       text not null default 'open' check (status in ('open', 'resolved')),
  created_by   uuid references staff(id),
  created_at   timestamptz not null default now(),
  resolved_at  timestamptz
);

-- Dữ liệu cũ: dựng nhóm từ group_name hiện có; thêm loại hao hụt cho các quán đang chạy
insert into ingredient_groups (shop_id, name, sort_order)
select i.shop_id, i.group_name, row_number() over (partition by i.shop_id order by i.group_name)
  from (select distinct shop_id, btrim(group_name) as group_name
          from ingredients where group_name is not null and btrim(group_name) <> '') i
on conflict do nothing;

insert into waste_types (shop_id, code, label_vi, requires_note, sort_order)
select s.id, t.code, t.label, false, t.ord
  from shops s
  cross join (values ('spill', 'Đổ vỡ / rơi vãi', 5), ('calibration', 'Căn chỉnh máy', 6)) as t(code, label, ord)
on conflict do nothing;

-- Quán mới: có sẵn hai loại hao hụt bổ sung
create or replace function inv_seed_trg() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into waste_types (shop_id, code, label_vi, requires_note, sort_order) values
    (new.id, 'spill', 'Đổ vỡ / rơi vãi', false, 5),
    (new.id, 'calibration', 'Căn chỉnh máy', false, 6)
  on conflict do nothing;
  return new;
end $$;
drop trigger if exists shops_seed_inventory on shops;
create trigger shops_seed_inventory after insert on shops for each row execute function inv_seed_trg();

-- ======================================================================
-- 3) Hàm nội bộ (không cấp cho app)
-- ======================================================================
create or replace function _inv_code(p_prefix text) returns text
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_day text := to_char(now() at time zone 'Asia/Ho_Chi_Minh', 'DDMM'); v_n integer;
begin
  insert into inv_code_counters (shop_id, prefix, day_key, n) values (v_shop, p_prefix, v_day, 1)
  on conflict (shop_id, prefix, day_key) do update set n = inv_code_counters.n + 1
  returning n into v_n;
  return p_prefix || '-' || v_day || case when v_n > 1 then '-' || v_n::text else '' end;
end $$;

-- Tồn của MỌI nguyên liệu trong một quán (lần đếm gần nhất + sổ kho sau đó)
create or replace function _inv_stock_all(p_shop uuid)
returns table (ingredient_id uuid, stock integer, last_count_at timestamptz)
language sql stable security definer set search_path = public as $$
  select i.id,
         (coalesce(c.counted_qty, 0) + coalesce((select sum(l.qty_delta) from stock_ledger l
                                                  where l.ingredient_id = i.id
                                                    and l.at > coalesce(c.counted_at, '-infinity'::timestamptz)), 0))::integer,
         c.counted_at
    from ingredients i
    left join lateral (select counted_qty, counted_at from stock_counts
                        where ingredient_id = i.id order by counted_at desc limit 1) c on true
   where i.shop_id = p_shop
$$;

create or replace function _inv_stock(p_ing uuid) returns integer
language sql stable security definer set search_path = public as $$
  select (coalesce(c.counted_qty, 0) + coalesce((select sum(l.qty_delta) from stock_ledger l
                                                  where l.ingredient_id = p_ing
                                                    and l.at > coalesce(c.counted_at, '-infinity'::timestamptz)), 0))::integer
    from (select 1) x
    left join lateral (select counted_qty, counted_at from stock_counts
                        where ingredient_id = p_ing order by counted_at desc limit 1) c on true
$$;

-- Mức dùng trung bình mỗi ngày (bán + hao hụt) trong p_days ngày gần nhất
create or replace function _inv_daily_use(p_shop uuid, p_days integer default 7)
returns table (ingredient_id uuid, per_day numeric)
language sql stable security definer set search_path = public as $$
  select l.ingredient_id, (-sum(l.qty_delta))::numeric / greatest(p_days, 1)
    from stock_ledger l
   where l.shop_id = p_shop and l.kind in ('sale', 'void_sale', 'waste')
     and l.at >= now() - make_interval(days => greatest(p_days, 1))
   group by l.ingredient_id
  having -sum(l.qty_delta) > 0
$$;

-- Lô còn lại: tồn được "xếp" vào các lô mới nhất trước (lô cũ dùng trước)
create or replace function _inv_lots_all(p_shop uuid)
returns table (lot_id uuid, ingredient_id uuid, code text, received_at timestamptz, expiry_date date,
               qty_received integer, qty_remaining integer, unit_cost numeric)
language sql stable security definer set search_path = public as $$
  with st as (select s.ingredient_id as iid, greatest(s.stock, 0) as stock from _inv_stock_all(p_shop) s),
  l as (
    select sl.id, sl.ingredient_id as iid, sl.code, sl.received_at, sl.expiry_date, sl.qty_received, sl.unit_cost,
           sum(sl.qty_received) over (partition by sl.ingredient_id order by sl.received_at desc, sl.id desc) as cum
      from stock_lots sl where sl.shop_id = p_shop)
  select l.id, l.iid, l.code, l.received_at, l.expiry_date, l.qty_received,
         greatest(least(l.qty_received::bigint, st.stock - (l.cum - l.qty_received)), 0)::integer,
         l.unit_cost
    from l join st on st.iid = l.iid
$$;

create or replace function _vn_day(p_ts timestamptz) returns date
language sql immutable as $$ select (p_ts at time zone 'Asia/Ho_Chi_Minh')::date $$;

-- Ngày kinh doanh bắt đầu 06:00 giờ Việt Nam (khớp màn Tổng quan): 02:00 sáng thuộc ngày hôm trước
create or replace function _biz_day(p_ts timestamptz) returns date
language sql immutable as $$ select ((p_ts at time zone 'Asia/Ho_Chi_Minh') - interval '6 hours')::date $$;
create or replace function _biz_start(p_day date) returns timestamptz
language sql immutable as $$ select (p_day + time '06:00') at time zone 'Asia/Ho_Chi_Minh' $$;

create or replace function _inv_status(p_stock integer, p_min integer) returns text
language sql immutable as $$
  select case when p_stock <= 0 then 'out'
              when p_min > 0 and p_stock <= p_min then 'low'
              else 'ok' end
$$;

-- ======================================================================
-- 4) Nhóm nguyên liệu
-- ======================================================================
create or replace function inv_groups() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', g.id, 'name', g.name, 'active', g.active,
             'ingredient_count', (select count(*) from ingredients i
                                   where i.shop_id = v_shop and i.active and lower(btrim(i.group_name)) = lower(btrim(g.name))),
             'menu_item_count', (select count(distinct ms.item_id) from ingredients i
                                   join recipe_lines rl on rl.ingredient_id = i.id
                                   join menu_sizes ms on ms.id = rl.size_id and ms.active
                                  where i.shop_id = v_shop and lower(btrim(i.group_name)) = lower(btrim(g.name))))
           order by g.active desc, g.sort_order, g.name)
      from ingredient_groups g where g.shop_id = v_shop), '[]'::jsonb);
end $$;

create or replace function inv_group_save(p_id uuid, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_id uuid := p_id; v_old text; v_name text := btrim(coalesce(p_name, ''));
begin
  perform _require_owner(); v_shop := app_shop_id();
  if v_name = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_id is null then
    insert into ingredient_groups (name, sort_order)
    values (v_name, coalesce((select max(sort_order) + 1 from ingredient_groups where shop_id = v_shop), 1))
    returning id into v_id;
  else
    select name into v_old from ingredient_groups where id = v_id and shop_id = v_shop;
    if not found then raise exception 'NOT_FOUND'; end if;
    update ingredient_groups set name = v_name where id = v_id;
    update ingredients set group_name = v_name
     where shop_id = v_shop and lower(btrim(group_name)) = lower(btrim(v_old));
  end if;
  return v_id;
exception when unique_violation then raise exception 'NAME_EXISTS';
end $$;

create or replace function inv_group_set_active(p_id uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_name text;
begin
  perform _require_owner(); v_shop := app_shop_id();
  select name into v_name from ingredient_groups where id = p_id and shop_id = v_shop;
  if not found then raise exception 'NOT_FOUND'; end if;
  if not p_active and exists (select 1 from ingredients i
                               where i.shop_id = v_shop and i.active and lower(btrim(i.group_name)) = lower(btrim(v_name))) then
    raise exception 'GROUP_NOT_EMPTY';
  end if;
  update ingredient_groups set active = p_active where id = p_id;
end $$;

-- ======================================================================
-- 5) Nhà cung cấp
-- ======================================================================
create or replace function sup_save(p_id uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_id uuid := p_id; v_name text := btrim(coalesce(p->>'name', ''));
  v_lead integer := coalesce(nullif(p->>'lead_days', '')::integer, 1);
begin
  perform _require_owner(); v_shop := app_shop_id();
  if v_name = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_lead < 0 or v_lead > 30 then raise exception 'LEAD_DAYS_INVALID'; end if;
  if coalesce(p->>'email', '') <> '' and (p->>'email') !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if v_id is null then
    insert into suppliers (name, contact_name, phone, email, address, lead_days, delivery_window, order_cutoff, note)
    values (v_name, nullif(btrim(p->>'contact_name'), ''), nullif(btrim(p->>'phone'), ''), nullif(lower(btrim(p->>'email')), ''),
            nullif(btrim(p->>'address'), ''), v_lead, nullif(btrim(p->>'delivery_window'), ''),
            nullif(btrim(p->>'order_cutoff'), ''), nullif(btrim(p->>'note'), ''))
    returning id into v_id;
  else
    update suppliers set name = v_name, contact_name = nullif(btrim(p->>'contact_name'), ''),
           phone = nullif(btrim(p->>'phone'), ''), email = nullif(lower(btrim(p->>'email')), ''),
           address = nullif(btrim(p->>'address'), ''), lead_days = v_lead,
           delivery_window = nullif(btrim(p->>'delivery_window'), ''),
           order_cutoff = nullif(btrim(p->>'order_cutoff'), ''), note = nullif(btrim(p->>'note'), '')
     where id = v_id and shop_id = v_shop;
    if not found then raise exception 'NOT_FOUND'; end if;
  end if;
  return v_id;
exception when unique_violation then raise exception 'NAME_EXISTS';
end $$;

create or replace function sup_set_active(p_id uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();
  update suppliers set active = p_active where id = p_id and shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;
end $$;

-- Danh sách nhà cung cấp (chủ): kèm mặt hàng và lần nhập gần nhất
create or replace function sup_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', s.id, 'name', s.name, 'contact_name', s.contact_name, 'phone', s.phone, 'active', s.active,
      'lead_days', s.lead_days,
      'items', coalesce((select jsonb_agg(i.name order by i.name) from ingredients i
                          where i.shop_id = v_shop and i.active and i.default_supplier_id = s.id), '[]'::jsonb),
      'last_order_at', (select max(po.received_at) from purchase_orders po
                         where po.shop_id = v_shop and po.supplier_id = s.id and po.status = 'confirmed'))
      order by s.active desc, s.name)
    from suppliers s where s.shop_id = v_shop), '[]'::jsonb);
end $$;

-- Danh sách chọn nhà cung cấp cho cả nhân viên (chỉ tên)
create or replace function sup_options() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return coalesce((select jsonb_agg(jsonb_build_object('id', s.id, 'name', s.name) order by s.name)
                     from suppliers s where s.shop_id = app_shop_id() and s.active), '[]'::jsonb);
end $$;

create or replace function sup_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; s suppliers;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  select * into s from suppliers where id = p_id and shop_id = v_shop;
  if not found then raise exception 'NOT_FOUND'; end if;
  return jsonb_build_object(
    'id', s.id, 'name', s.name, 'contact_name', s.contact_name, 'phone', s.phone, 'email', s.email,
    'address', s.address, 'lead_days', s.lead_days, 'delivery_window', s.delivery_window,
    'order_cutoff', s.order_cutoff, 'note', s.note, 'active', s.active, 'created_at', s.created_at,
    'items', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ingredient_id', i.id, 'name', i.name, 'unit', i.unit,
               'last_price', i.last_purchase_cost, 'last_at', i.last_purchase_at) order by i.name)
        from ingredients i where i.shop_id = v_shop and i.active and i.default_supplier_id = s.id), '[]'::jsonb),
    'orders', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', po.id, 'code', po.code, 'received_at', po.received_at, 'total_amount', po.total_amount,
               'line_count', (select count(*) from purchase_order_lines l where l.order_id = po.id),
               'needs_pricing', po.needs_pricing) order by po.received_at desc)
        from (select * from purchase_orders x where x.shop_id = v_shop and x.supplier_id = s.id and x.status = 'confirmed'
               order by x.received_at desc limit 10) po), '[]'::jsonb),
    'draft_count', (select count(*) from purchase_orders x where x.shop_id = v_shop and x.supplier_id = s.id and x.status = 'draft'));
end $$;

-- ======================================================================
-- 6) Nguyên liệu: lưu, danh mục, hồ sơ, lịch sử
-- ======================================================================
create or replace function inv_ingredient_save(p_id uuid, p jsonb) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_id uuid := p_id; v_name text := btrim(coalesce(p->>'name', ''));
  v_unit text := p->>'unit'; v_group text; v_gid uuid := nullif(p->>'group_id', '')::uuid;
  v_sup uuid := nullif(p->>'default_supplier_id', '')::uuid;
  v_min integer := coalesce(nullif(p->>'min_stock_qty', '')::integer, 0);
  v_imp text := coalesce(nullif(p->>'importance', ''), 'normal');
  v_old ingredients;
begin
  perform _require_owner(); v_shop := app_shop_id();
  if v_name = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_min < 0 then raise exception 'QTY_INVALID'; end if;
  if v_imp not in ('important', 'normal') then raise exception 'IMPORTANCE_INVALID'; end if;
  if v_gid is not null then
    select name into v_group from ingredient_groups where id = v_gid and shop_id = v_shop and active;
    if not found then raise exception 'GROUP_REQUIRED'; end if;
  end if;
  if v_sup is not null and not exists (select 1 from suppliers where id = v_sup and shop_id = v_shop) then
    raise exception 'NOT_FOUND';
  end if;
  if v_id is null then
    if v_unit is null or v_unit not in ('ml', 'g', 'piece') then raise exception 'UNIT_INVALID'; end if;
    if v_group is null then raise exception 'GROUP_REQUIRED'; end if;
    insert into ingredients (name, group_name, unit, importance, min_stock_qty, default_supplier_id, storage_note)
    values (v_name, v_group, v_unit, v_imp, v_min, v_sup, nullif(btrim(p->>'storage_note'), ''))
    returning id into v_id;
    perform _audit('ingredient_create', 'ingredient', v_id, jsonb_build_object('name', v_name));
  else
    select * into v_old from ingredients where id = v_id and shop_id = v_shop;
    if not found then raise exception 'NOT_FOUND'; end if;
    if v_unit is not null and v_unit <> v_old.unit then
      if exists (select 1 from stock_ledger where ingredient_id = v_id) or exists (select 1 from recipe_lines where ingredient_id = v_id) then
        raise exception 'UNIT_LOCKED';
      end if;
    else
      v_unit := v_old.unit;
    end if;
    update ingredients set name = v_name, unit = v_unit, group_name = coalesce(v_group, group_name),
           importance = v_imp, min_stock_qty = v_min, default_supplier_id = v_sup,
           storage_note = nullif(btrim(p->>'storage_note'), '')
     where id = v_id;
    perform _audit('ingredient_update', 'ingredient', v_id, jsonb_build_object('name', v_name));
  end if;
  return v_id;
exception when unique_violation then raise exception 'NAME_EXISTS';
end $$;

-- Ngừng dùng: không xóa; chỉ được khi tồn = 0 và không còn trong công thức đang dùng
create or replace function inv_ingredient_set_active(p_id uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_owner(); v_shop := app_shop_id();
  if not exists (select 1 from ingredients where id = p_id and shop_id = v_shop) then raise exception 'NOT_FOUND'; end if;
  if not p_active then
    if exists (select 1 from recipe_lines rl join menu_sizes ms on ms.id = rl.size_id and ms.active
                join menu_items mi on mi.id = ms.item_id and mi.active
               where rl.ingredient_id = p_id) then
      raise exception 'INGREDIENT_IN_RECIPE';
    end if;
    if _inv_stock(p_id) > 0 then raise exception 'STOCK_NOT_EMPTY'; end if;
  end if;
  update ingredients set active = p_active where id = p_id;
  perform _audit('ingredient_set_active', 'ingredient', p_id, jsonb_build_object('active', p_active));
end $$;

create or replace function inv_catalog(p_group text default null, p_search text default null, p_include_inactive boolean default false)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_q text := lower(btrim(coalesce(p_search, '')));
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  return coalesce((
    with st as (select * from _inv_stock_all(v_shop)),
         us as (select * from _inv_daily_use(v_shop, 7))
    select jsonb_agg(jsonb_build_object(
             'id', i.id, 'name', i.name, 'group_name', i.group_name, 'unit', i.unit, 'active', i.active,
             'stock', st.stock, 'unit_cost', i.unit_cost,
             'value', case when i.unit_cost is null then null else round(greatest(st.stock, 0) * i.unit_cost)::bigint end,
             'min_stock_qty', i.min_stock_qty,
             'status', _inv_status(st.stock, i.min_stock_qty),
             'days_left', case when us.per_day > 0 then round(greatest(st.stock, 0) / us.per_day, 1) end,
             'default_supplier_id', i.default_supplier_id,
             'supplier_name', (select s.name from suppliers s where s.id = i.default_supplier_id),
             'menu_item_count', (select count(distinct ms.item_id) from recipe_lines rl
                                  join menu_sizes ms on ms.id = rl.size_id and ms.active
                                 where rl.ingredient_id = i.id))
           order by i.active desc, (_inv_status(st.stock, i.min_stock_qty) = 'ok'), i.group_name nulls last, i.name)
      from ingredients i
      join st on st.ingredient_id = i.id
      left join us on us.ingredient_id = i.id
     where i.shop_id = v_shop and (i.active or p_include_inactive)
       and (p_group is null or lower(btrim(i.group_name)) = lower(btrim(p_group)))
       and (v_q = '' or lower(i.name) like '%' || v_q || '%')
  ), '[]'::jsonb);
end $$;

create or replace function inv_ingredient_profile(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; i ingredients; v_stock integer; v_use numeric; v_sup text;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  select * into i from ingredients where id = p_id and shop_id = v_shop;
  if not found then raise exception 'NOT_FOUND'; end if;
  select s.stock into v_stock from _inv_stock_all(v_shop) s where s.ingredient_id = p_id;
  select u.per_day into v_use from _inv_daily_use(v_shop, 7) u where u.ingredient_id = p_id;
  select s.name into v_sup from suppliers s where s.id = i.default_supplier_id;
  return jsonb_build_object(
    'id', i.id, 'name', i.name, 'group_name', i.group_name, 'unit', i.unit, 'importance', i.importance,
    'active', i.active, 'storage_note', i.storage_note,
    'stock', v_stock, 'stock_at', now(),
    'last_count_at', (select max(c.counted_at) from stock_counts c where c.ingredient_id = p_id),
    'unit_cost', i.unit_cost, 'last_purchase_cost', i.last_purchase_cost, 'last_purchase_at', i.last_purchase_at,
    'value', case when i.unit_cost is null then null else round(greatest(v_stock, 0) * i.unit_cost)::bigint end,
    'min_stock_qty', i.min_stock_qty,
    'status', _inv_status(v_stock, i.min_stock_qty),
    'per_day', round(v_use, 2),
    'days_left', case when v_use > 0 then round(greatest(v_stock, 0) / v_use, 1) end,
    'default_supplier_id', i.default_supplier_id, 'supplier_name', v_sup,
    'supplier_lead_days', (select s.lead_days from suppliers s where s.id = i.default_supplier_id),
    'lots', coalesce((select jsonb_agg(jsonb_build_object(
                 'id', l.lot_id, 'code', l.code, 'received_at', l.received_at, 'expiry_date', l.expiry_date,
                 'qty_received', l.qty_received, 'qty_remaining', l.qty_remaining, 'unit_cost', l.unit_cost)
               order by l.expiry_date nulls last, l.received_at)
               from _inv_lots_all(v_shop) l where l.ingredient_id = p_id and l.qty_remaining > 0), '[]'::jsonb),
    'used_in', coalesce((select jsonb_agg(jsonb_build_object(
                 'item_name', mi.name, 'size_name', ms.size_name, 'qty', rl.qty) order by mi.name, ms.size_name)
               from recipe_lines rl join menu_sizes ms on ms.id = rl.size_id and ms.active
               join menu_items mi on mi.id = ms.item_id and mi.active
              where rl.ingredient_id = p_id), '[]'::jsonb));
end $$;

-- Sổ biến động + lịch sử giá nhập của một nguyên liệu
create or replace function inv_ingredient_history(p_id uuid, p_kind text default null, p_limit integer default 40)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_lim integer := least(greatest(coalesce(p_limit, 40), 1), 200);
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  if not exists (select 1 from ingredients where id = p_id and shop_id = v_shop) then raise exception 'NOT_FOUND'; end if;
  if p_kind is not null and p_kind not in ('purchase', 'waste', 'adjust', 'sale') then raise exception 'KIND_INVALID'; end if;
  return jsonb_build_object(
    'movements', coalesce((
      select jsonb_agg(m order by (m->>'at') desc) from (
        select jsonb_build_object(
                 'at', x.at, 'kind', x.kind, 'qty_delta', x.qty_delta, 'ref_code', x.ref_code,
                 'actor_name', x.actor_name, 'note', x.note) as m
          from (
            -- nhập / hao hụt / điều chỉnh: từng dòng, có mã phiếu và người ghi
            select l.at, l.kind, l.qty_delta::bigint as qty_delta,
                   case l.kind
                     when 'purchase' then (select po.code from purchase_order_lines pl join purchase_orders po on po.id = pl.order_id where pl.id = l.ref_id)
                     when 'waste' then (select w.code from waste_logs w where w.id = l.ref_id)
                     when 'adjust' then (select k.code from stocktakes k where k.id = l.ref_id)
                   end as ref_code,
                   (select s.full_name from staff s where s.id = l.created_by) as actor_name,
                   l.note
              from stock_ledger l
             where l.ingredient_id = p_id and l.shop_id = v_shop and l.kind in ('purchase', 'waste', 'adjust')
               and (p_kind is null or p_kind = l.kind)
            union all
            -- bán theo công thức: gộp theo ngày để sổ không dài vô tận
            select max(l.at), 'sale', sum(l.qty_delta)::bigint, null, null, null
              from stock_ledger l
             where l.ingredient_id = p_id and l.shop_id = v_shop and l.kind in ('sale', 'void_sale')
               and (p_kind is null or p_kind = 'sale')
             group by _biz_day(l.at)
          ) x
         order by x.at desc limit v_lim) q), '[]'::jsonb),
    'price_events', coalesce((
      select jsonb_agg(jsonb_build_object(
               'at', e.at, 'kind', e.kind, 'price', e.price, 'avg_before', e.avg_before, 'avg_after', e.avg_after,
               'qty', e.qty, 'order_code', (select po.code from purchase_orders po where po.id = e.order_id),
               'actor_name', (select s.full_name from staff s where s.id = e.created_by)) order by e.at desc)
        from (select * from ingredient_cost_events where ingredient_id = p_id and shop_id = v_shop
               order by at desc limit 20) e), '[]'::jsonb));
end $$;

-- Danh sách chọn nguyên liệu cho phiếu nhập (nhân viên cũng dùng, KHÔNG có tồn/giá)
create or replace function inv_picker() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return coalesce((select jsonb_agg(jsonb_build_object(
            'id', i.id, 'name', i.name, 'unit', i.unit, 'group_name', i.group_name,
            'default_supplier_id', i.default_supplier_id) order by i.group_name nulls last, i.name)
         from ingredients i where i.shop_id = app_shop_id() and i.active), '[]'::jsonb);
end $$;

-- Lô còn dùng được của một nguyên liệu: nhân viên chỉ thấy mã lô + hạn dùng, KHÔNG thấy số lượng
create or replace function inv_lots_for_staff(p_ingredient uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_staff(); v_shop := app_shop_id();
  return coalesce((select jsonb_agg(jsonb_build_object(
            'id', l.lot_id, 'code', l.code, 'expiry_date', l.expiry_date, 'received_at', l.received_at)
            order by l.expiry_date nulls last, l.received_at)
         from _inv_lots_all(v_shop) l where l.ingredient_id = p_ingredient and l.qty_remaining > 0), '[]'::jsonb);
end $$;

-- ======================================================================
-- 7) Phiếu nhập hàng (PN)
-- ======================================================================
-- Áp giá nhập vào giá bình quân gia quyền. p_stock_before = tồn TRƯỚC khi hàng này vào kho.
create or replace function _inv_apply_cost(p_ing uuid, p_price numeric, p_qty integer, p_stock_before integer,
                                            p_at timestamptz, p_order uuid, p_by uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_avg numeric; v_new numeric; v_before integer := greatest(coalesce(p_stock_before, 0), 0);
begin
  select unit_cost into v_avg from ingredients where id = p_ing;
  if v_avg is null or v_before = 0 then
    v_new := p_price;
  else
    v_new := (v_before * v_avg + p_qty * p_price) / (v_before + p_qty);
  end if;
  update ingredients set unit_cost = round(v_new, 2), unit_cost_updated_at = now(),
         last_purchase_cost = p_price,
         last_purchase_at = greatest(coalesce(last_purchase_at, p_at), p_at)
   where id = p_ing;
  insert into ingredient_cost_events (ingredient_id, at, kind, price, avg_before, avg_after, qty, order_id, created_by)
  values (p_ing, p_at, 'purchase', p_price, v_avg, round(v_new, 2), p_qty, p_order, p_by);
end $$;

create or replace function _po_json(p_id uuid, p_prices boolean) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare o purchase_orders;
begin
  select * into o from purchase_orders where id = p_id and shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;
  return jsonb_build_object(
    'id', o.id, 'code', o.code, 'status', o.status, 'source', o.source, 'note', o.note,
    'supplier_id', o.supplier_id, 'supplier_name', (select s.name from suppliers s where s.id = o.supplier_id),
    'vat_included', o.vat_included, 'received_at', o.received_at, 'created_at', o.created_at, 'updated_at', o.updated_at,
    'needs_pricing', o.needs_pricing, 'cancel_reason', o.cancel_reason,
    'created_by_name', (select s.full_name from staff s where s.id = o.created_by),
    'shipping_fee', case when p_prices then o.shipping_fee end,
    'total_amount', case when p_prices then o.total_amount end,
    'lines', coalesce((select jsonb_agg(jsonb_build_object(
               'id', l.id, 'ingredient_id', l.ingredient_id, 'name', i.name, 'unit', i.unit, 'qty', l.qty,
               'unit_price', case when p_prices then l.unit_price end,
               'line_total', case when p_prices and l.unit_price is not null then round(l.qty * l.unit_price)::bigint end,
               'lot_code', coalesce(l.lot_code, (select sl.code from stock_lots sl where sl.id = l.lot_id)),
               'expiry_date', l.expiry_date,
               'last_price', case when p_prices then i.last_purchase_cost end)
             order by l.created_at, l.id)
             from purchase_order_lines l join ingredients i on i.id = l.ingredient_id
            where l.order_id = o.id), '[]'::jsonb));
end $$;

-- Ghi hàng vào kho: tạo lô, dòng sổ kho, cập nhật giá bình quân
create or replace function _po_apply(p_order uuid, p_by uuid) returns void
language plpgsql security definer set search_path = public as $$
declare o purchase_orders; l purchase_order_lines; v_lot uuid; v_code text; v_shift uuid; v_before integer; v_at timestamptz;
begin
  select * into o from purchase_orders where id = p_order;
  v_at := least(coalesce(o.received_at, now()), now());
  select s.id into v_shift from shifts s
   where s.shop_id = o.shop_id and s.opened_at <= v_at and (s.closed_at is null or s.closed_at >= v_at)
   order by s.opened_at desc limit 1;
  for l in select * from purchase_order_lines where order_id = p_order order by created_at, id loop
    v_before := _inv_stock(l.ingredient_id);
    v_code := coalesce(nullif(btrim(l.lot_code), ''), _inv_code('ST'));
    insert into stock_lots (ingredient_id, code, received_at, expiry_date, qty_received, unit_cost, order_line_id)
    values (l.ingredient_id, v_code, v_at, l.expiry_date, l.qty, l.unit_price, l.id)
    returning id into v_lot;
    update purchase_order_lines set lot_id = v_lot where id = l.id;
    insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, at, note)
    values (v_shift, l.ingredient_id, 'purchase', l.qty, l.id, p_by, v_at, o.code);
    if l.unit_price is not null then
      perform _inv_apply_cost(l.ingredient_id, l.unit_price, l.qty, v_before, v_at, p_order, p_by);
    end if;
  end loop;
end $$;

create or replace function po_save(p_id uuid, p jsonb, p_confirm boolean default false) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := _require_perm('inventory.record'); v_shop uuid := app_shop_id(); v_owner boolean := app_is_owner();
  o purchase_orders; v_id uuid := p_id; e jsonb; v_ing uuid; v_qty integer; v_price numeric; v_exp date;
  v_sup uuid := nullif(p->>'supplier_id', '')::uuid; v_n integer := 0; v_total numeric := 0;
  v_ship integer := coalesce(nullif(p->>'shipping_fee', '')::integer, 0);
  v_recv timestamptz := coalesce(nullif(p->>'received_at', '')::timestamptz, now());
  v_unpriced boolean := false;
begin
  if v_recv > now() + interval '5 minutes' then raise exception 'DATE_INVALID'; end if;
  if v_ship < 0 then raise exception 'AMOUNT_INVALID'; end if;
  if v_sup is not null and not exists (select 1 from suppliers where id = v_sup and shop_id = v_shop and active) then
    raise exception 'NOT_FOUND';
  end if;
  if not v_owner then v_ship := 0; end if;

  if v_id is null then
    insert into purchase_orders (code, supplier_id, source, created_by)
    values (_inv_code('PN'), v_sup, case when v_owner then 'owner' else 'staff' end, v_me)
    returning id into v_id;
  end if;
  select * into o from purchase_orders where id = v_id and shop_id = v_shop for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.status <> 'draft' then raise exception 'ORDER_NOT_DRAFT'; end if;
  if not v_owner and o.created_by is distinct from v_me then raise exception 'OWNER_ONLY'; end if;

  delete from purchase_order_lines where order_id = v_id;
  for e in select * from jsonb_array_elements(coalesce(p->'lines', '[]'::jsonb)) loop
    v_ing := (e->>'ingredient_id')::uuid;
    if not exists (select 1 from ingredients where id = v_ing and shop_id = v_shop and active) then raise exception 'NOT_FOUND'; end if;
    begin v_qty := (e->>'qty')::integer; exception when others then raise exception 'QTY_INVALID'; end;
    if v_qty is null or v_qty <= 0 or v_qty > 1000000000 then raise exception 'QTY_INVALID'; end if;
    v_price := case when v_owner then nullif(e->>'unit_price', '')::numeric end;
    if v_price is not null and v_price < 0 then raise exception 'AMOUNT_INVALID'; end if;
    v_exp := nullif(e->>'expiry_date', '')::date;
    insert into purchase_order_lines (order_id, ingredient_id, qty, unit_price, lot_code, expiry_date)
    values (v_id, v_ing, v_qty, v_price, nullif(btrim(e->>'lot_code'), ''), v_exp);
    v_n := v_n + 1;
    if v_price is null then v_unpriced := true; else v_total := v_total + v_qty * v_price; end if;
  end loop;

  update purchase_orders set supplier_id = v_sup, note = nullif(btrim(p->>'note'), ''),
         vat_included = coalesce((p->>'vat_included')::boolean, true), shipping_fee = v_ship, received_at = v_recv,
         total_amount = case when v_n > 0 and not v_unpriced then round(v_total)::bigint + v_ship end,
         updated_at = now()
   where id = v_id;

  if p_confirm then
    if v_sup is null then raise exception 'SUPPLIER_REQUIRED'; end if;
    if v_n = 0 then raise exception 'LINES_REQUIRED'; end if;
    if v_owner and v_unpriced then raise exception 'PRICE_REQUIRED'; end if;
    if not v_owner then perform _open_shift_id(); end if;   -- nhân viên chỉ nhận hàng trong ca đang mở
    update purchase_orders set status = 'confirmed', confirmed_by = v_me, confirmed_at = now(),
           needs_pricing = v_unpriced, received_at = case when v_owner then v_recv else now() end,
           updated_at = now()
     where id = v_id;
    perform _po_apply(v_id, v_me);
    perform _audit('po_confirm', 'purchase_order', v_id, jsonb_build_object('code', o.code, 'lines', v_n));
  end if;
  return _po_json(v_id, v_owner);
exception when invalid_text_representation or invalid_datetime_format or datetime_field_overflow then
  raise exception 'INPUT_INVALID';
end $$;

create or replace function po_cancel(p_id uuid, p_reason text default null) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); o purchase_orders;
begin
  select * into o from purchase_orders where id = p_id and shop_id = app_shop_id() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.status <> 'draft' then raise exception 'ORDER_NOT_DRAFT'; end if;
  if not app_is_owner() and o.created_by is distinct from v_me then raise exception 'OWNER_ONLY'; end if;
  update purchase_orders set status = 'cancelled', cancel_reason = nullif(btrim(p_reason), ''), updated_at = now() where id = p_id;
end $$;

-- Chủ bổ sung giá cho phiếu nhân viên đã nhận hàng
create or replace function po_set_prices(p_id uuid, p_lines jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); o purchase_orders; e jsonb; l purchase_order_lines; v_price numeric; v_before integer;
  v_unpriced boolean; v_total numeric;
begin
  select * into o from purchase_orders where id = p_id and shop_id = app_shop_id() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if o.status <> 'confirmed' or not o.needs_pricing then raise exception 'ORDER_NOT_PRICEABLE'; end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_price := nullif(e->>'unit_price', '')::numeric;
    if v_price is null or v_price < 0 then raise exception 'AMOUNT_INVALID'; end if;
    select * into l from purchase_order_lines where id = (e->>'line_id')::uuid and order_id = p_id for update;
    if not found then raise exception 'NOT_FOUND'; end if;
    if l.unit_price is not null then continue; end if;
    update purchase_order_lines set unit_price = v_price where id = l.id;
    update stock_lots set unit_cost = v_price where id = l.lot_id;
    -- tồn trước khi lô này vào kho ≈ tồn hiện tại trừ lượng lô (không âm)
    v_before := greatest(_inv_stock(l.ingredient_id) - l.qty, 0);
    perform _inv_apply_cost(l.ingredient_id, v_price, l.qty, v_before, coalesce(o.received_at, now()), p_id, v_me);
  end loop;
  select bool_or(unit_price is null), sum(qty * coalesce(unit_price, 0)) into v_unpriced, v_total
    from purchase_order_lines where order_id = p_id;
  update purchase_orders set needs_pricing = coalesce(v_unpriced, false),
         total_amount = case when coalesce(v_unpriced, false) then null else round(v_total)::bigint + shipping_fee end,
         updated_at = now()
   where id = p_id;
  perform _audit('po_set_prices', 'purchase_order', p_id, jsonb_build_object('code', o.code));
  return _po_json(p_id, true);
end $$;

create or replace function po_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff(); o purchase_orders;
begin
  select * into o from purchase_orders where id = p_id and shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;
  if not app_is_owner() and o.created_by is distinct from v_me then raise exception 'OWNER_ONLY'; end if;
  return _po_json(p_id, app_is_owner());
end $$;

-- Danh sách phiếu: chủ thấy hết; nhân viên chỉ thấy phiếu của mình (không có giá)
create or replace function po_list(p_status text default null, p_limit integer default 30) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_owner boolean := app_is_owner(); v_lim integer := least(greatest(coalesce(p_limit, 30), 1), 100);
begin
  if p_status is not null and p_status not in ('draft', 'confirmed', 'cancelled') then raise exception 'KIND_INVALID'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', o.id, 'code', o.code, 'status', o.status, 'source', o.source,
             'supplier_name', (select s.name from suppliers s where s.id = o.supplier_id),
             'received_at', o.received_at, 'updated_at', o.updated_at, 'needs_pricing', o.needs_pricing,
             'total_amount', case when v_owner then o.total_amount end,
             'line_count', (select count(*) from purchase_order_lines l where l.order_id = o.id))
           order by o.updated_at desc)
      from (select * from purchase_orders x
             where x.shop_id = app_shop_id() and (p_status is null or x.status = p_status)
               and (v_owner or x.created_by = v_me)
             order by x.updated_at desc limit v_lim) o), '[]'::jsonb);
end $$;

-- Tác động giá của một phiếu NHÁP: giá bình quân mới và giá vốn các size dùng nguyên liệu đó.
-- Giá bán không đổi: chỉ cho chủ thấy biên lợi nhuận nếu giữ nguyên giá bán.
create or replace function po_impact(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; o purchase_orders; v_items jsonb; v_sizes jsonb;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  select * into o from purchase_orders where id = p_id and shop_id = v_shop;
  if not found then raise exception 'NOT_FOUND'; end if;
  select coalesce(jsonb_agg(jsonb_build_object(
           'ingredient_id', q.id, 'name', q.name, 'unit', q.unit, 'qty', q.qty, 'price', q.price,
           'stock_before', q.stock_before, 'stock_after', q.stock_before + q.qty,
           'avg_before', q.unit_cost, 'last_price', q.last_purchase_cost,
           'avg_after', round(case when q.unit_cost is null or q.stock_pos = 0 then q.price
                                   else (q.stock_pos * q.unit_cost + q.qty * q.price) / (q.stock_pos + q.qty) end, 2),
           'price_change_pct', case when q.last_purchase_cost > 0 then round((q.price - q.last_purchase_cost) / q.last_purchase_cost * 100, 1) end,
           'avg_change_pct', case when q.unit_cost > 0 and q.stock_pos > 0
                                  then round(((q.stock_pos * q.unit_cost + q.qty * q.price) / (q.stock_pos + q.qty) - q.unit_cost) / q.unit_cost * 100, 1) end)
           order by q.name), '[]'::jsonb)
    into v_items
    from (
      select i.id, i.name, i.unit, i.unit_cost, i.last_purchase_cost,
             sum(l.qty)::integer as qty, (sum(l.qty * l.unit_price) / sum(l.qty)) as price,
             _inv_stock(i.id) as stock_before,
             greatest(_inv_stock(i.id), 0) as stock_pos
        from purchase_order_lines l join ingredients i on i.id = l.ingredient_id
       where l.order_id = p_id and l.unit_price is not null
       group by i.id, i.name, i.unit, i.unit_cost, i.last_purchase_cost) q;

  select coalesce(jsonb_agg(jsonb_build_object(
           'size_id', z.sid, 'item_name', z.item_name, 'size_name', z.size_name, 'sell_price', z.price,
           'cost_before', z.cost_before, 'cost_after', z.cost_after) order by (z.cost_after - z.cost_before) desc nulls last), '[]'::jsonb)
    into v_sizes
    from (
      select ms.id as sid, mi.name as item_name, ms.size_name, ms.price,
             case when bool_and(i.unit_cost is not null) then round(sum(rl.qty * i.unit_cost))::integer end as cost_before,
             round(sum(rl.qty * coalesce((c.e->>'avg_after')::numeric, i.unit_cost)))::integer as cost_after
        from menu_sizes ms
        join menu_items mi on mi.id = ms.item_id and mi.active
        join recipe_lines rl on rl.size_id = ms.id
        join ingredients i on i.id = rl.ingredient_id
        left join lateral (select e from jsonb_array_elements(v_items) e where (e->>'ingredient_id')::uuid = i.id limit 1) c on true
       where ms.shop_id = v_shop and ms.active
       group by ms.id, mi.name, ms.size_name, ms.price
      having bool_or(c.e is not null) and bool_and(i.unit_cost is not null or c.e is not null)
    ) z;
  return jsonb_build_object('order_id', p_id, 'code', o.code, 'items', v_items, 'sizes', v_sizes);
end $$;

-- ======================================================================
-- 8) Gợi ý nhập hàng
-- ======================================================================
create or replace function po_suggestions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_items jsonb;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  with st as (select * from _inv_stock_all(v_shop)),
       us as (select * from _inv_daily_use(v_shop, 7)),
  base as (
    select i.id, i.name, i.unit, i.group_name, i.min_stock_qty, i.last_purchase_cost, i.default_supplier_id,
           greatest(st.stock, 0) as stock, coalesce(us.per_day, 0) as per_day,
           coalesce(s.lead_days, 1) as lead_days, s.name as supplier_name, s.order_cutoff
      from ingredients i
      join st on st.ingredient_id = i.id
      left join us on us.ingredient_id = i.id
      left join suppliers s on s.id = i.default_supplier_id and s.active
     where i.shop_id = v_shop and i.active),
  need as (
    select b.*,
           ceil(greatest(b.per_day * (b.lead_days + 4) - b.stock, b.min_stock_qty * 2 - b.stock, 0)) as raw_qty
      from base b
     where (b.min_stock_qty > 0 and b.stock <= b.min_stock_qty)
        or (b.per_day > 0 and b.stock / b.per_day < b.lead_days + 2))
  select coalesce(jsonb_agg(jsonb_build_object(
           'ingredient_id', n.id, 'name', n.name, 'unit', n.unit, 'stock', n.stock,
           'per_day', round(n.per_day, 1),
           'days_left', case when n.per_day > 0 then round(n.stock / n.per_day, 1) end,
           'suggested_qty', case when n.unit = 'piece' then n.raw_qty::integer else (ceil(n.raw_qty / 500.0) * 500)::integer end,
           'supplier_id', n.default_supplier_id, 'supplier_name', n.supplier_name,
           'lead_days', n.lead_days, 'order_cutoff', n.order_cutoff, 'last_price', n.last_purchase_cost)
           order by n.supplier_name nulls last, (case when n.per_day > 0 then n.stock / n.per_day end) nulls last, n.name), '[]'::jsonb)
    into v_items
    from need n where n.raw_qty > 0;
  return jsonb_build_object(
    'generated_at', now(), 'window_days', 7, 'items', v_items,
    'draft_codes', coalesce((select jsonb_agg(po.code order by po.created_at) from purchase_orders po
                              where po.shop_id = v_shop and po.status = 'draft'), '[]'::jsonb));
end $$;

-- Tạo phiếu NHÁP từ gợi ý (mỗi nhà cung cấp một phiếu). Không gửi đơn đi đâu cả.
create or replace function po_from_suggestions(p_items jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_shop uuid := app_shop_id(); g record; v_id uuid; v_out jsonb := '[]'::jsonb;
begin
  if jsonb_typeof(coalesce(p_items, 'null'::jsonb)) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'LINES_REQUIRED'; end if;
  for g in
    select nullif(e->>'supplier_id', '')::uuid as sup, jsonb_agg(e) as items
      from jsonb_array_elements(p_items) e group by 1
  loop
    if g.sup is not null and not exists (select 1 from suppliers where id = g.sup and shop_id = v_shop) then raise exception 'NOT_FOUND'; end if;
    insert into purchase_orders (code, supplier_id, source, created_by, note)
    values (_inv_code('PN'), g.sup, 'suggestion', v_me, 'Tạo từ gợi ý nhập hàng')
    returning id into v_id;
    insert into purchase_order_lines (order_id, ingredient_id, qty, unit_price)
    select v_id, (x->>'ingredient_id')::uuid, (x->>'qty')::integer,
           (select i.last_purchase_cost from ingredients i where i.id = (x->>'ingredient_id')::uuid)
      from jsonb_array_elements(g.items) x
     where exists (select 1 from ingredients i where i.id = (x->>'ingredient_id')::uuid and i.shop_id = v_shop and i.active)
       and (x->>'qty')::integer > 0;
    v_out := v_out || jsonb_build_object('id', v_id, 'code', (select code from purchase_orders where id = v_id));
  end loop;
  return v_out;
exception when invalid_text_representation then raise exception 'QTY_INVALID';
end $$;

-- ======================================================================
-- 9) Kiểm kê có duyệt (KK)
-- ======================================================================
create or replace function st_start() returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_perm('inventory.record'); v_shop uuid := app_shop_id(); v_id uuid; v_code text;
begin
  select id, code into v_id, v_code from stocktakes
   where shop_id = v_shop and started_by = v_me and status in ('draft', 'recount') order by started_at desc limit 1;
  if found then return jsonb_build_object('id', v_id, 'code', v_code, 'resumed', true); end if;
  v_code := _inv_code('KK');
  insert into stocktakes (code, started_by) values (v_code, v_me) returning id into v_id;
  insert into stocktake_lines (stocktake_id, ingredient_id)
  select v_id, i.id from ingredients i where i.shop_id = v_shop and i.active;
  return jsonb_build_object('id', v_id, 'code', v_code, 'resumed', false);
end $$;

-- Phiếu đếm MÙ: không có số hệ thống, không có giá
create or replace function st_sheet(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff(); k stocktakes;
begin
  select * into k from stocktakes where id = p_id and shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;
  if not app_is_owner() and k.started_by <> v_me then raise exception 'OWNER_ONLY'; end if;
  return jsonb_build_object(
    'id', k.id, 'code', k.code, 'status', k.status, 'started_at', k.started_at, 'saved_at', k.saved_at,
    'submitted_at', k.submitted_at, 'review_note', case when k.status = 'recount' then k.review_note end,
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ingredient_id', l.ingredient_id, 'name', i.name, 'unit', i.unit, 'group_name', i.group_name,
               'counted_qty', l.counted_qty, 'recount_requested', l.recount_requested,
               'editable', (k.status = 'draft' or (k.status = 'recount' and l.recount_requested)))
             order by i.group_name nulls last, i.name)
        from stocktake_lines l join ingredients i on i.id = l.ingredient_id
       where l.stocktake_id = k.id), '[]'::jsonb));
end $$;

create or replace function st_save(p_id uuid, p_lines jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_perm('inventory.record'); k stocktakes; e jsonb; v_qty integer; v_ing uuid; l stocktake_lines;
begin
  select * into k from stocktakes where id = p_id and shop_id = app_shop_id() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if k.started_by <> v_me then raise exception 'OWNER_ONLY'; end if;
  if k.status not in ('draft', 'recount') then raise exception 'STOCKTAKE_LOCKED'; end if;
  for e in select * from jsonb_array_elements(coalesce(p_lines, '[]'::jsonb)) loop
    v_ing := (e->>'ingredient_id')::uuid;
    v_qty := nullif(e->>'counted_qty', '')::integer;
    if v_qty is not null and (v_qty < 0 or v_qty > 1000000000) then raise exception 'QTY_INVALID'; end if;
    select * into l from stocktake_lines where stocktake_id = p_id and ingredient_id = v_ing for update;
    if not found then raise exception 'NOT_FOUND'; end if;
    if k.status = 'recount' and not l.recount_requested then continue; end if;
    -- Lưu nháp lại cùng số thì giữ nguyên thời điểm đếm và số hệ thống đã chụp
    if v_qty is not distinct from l.counted_qty and l.system_qty is not null then continue; end if;
    -- Chụp tồn hệ thống NGAY LÚC ĐẾM: hàng bán/nhập giữa lúc đếm và lúc gửi không tạo lệch giả
    update stocktake_lines set
           recount_prev_qty = case when k.status = 'recount' and recount_prev_qty is null then counted_qty else recount_prev_qty end,
           counted_qty = v_qty, counted_at = case when v_qty is null then null else now() end,
           system_qty = case when v_qty is null then null else _inv_stock(v_ing) end,
           unit_cost = case when v_qty is null then null else (select i.unit_cost from ingredients i where i.id = v_ing) end
     where id = l.id;
  end loop;
  update stocktakes set saved_at = now() where id = p_id;
exception when invalid_text_representation then raise exception 'QTY_INVALID';
end $$;

create or replace function st_submit(p_id uuid) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_perm('inventory.record'); k stocktakes; l stocktake_lines; v_shop uuid := app_shop_id();
begin
  select * into k from stocktakes where id = p_id and shop_id = v_shop for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if k.started_by <> v_me then raise exception 'OWNER_ONLY'; end if;
  if k.status not in ('draft', 'recount') then raise exception 'STOCKTAKE_LOCKED'; end if;
  if exists (select 1 from stocktake_lines x where x.stocktake_id = p_id and x.counted_qty is null
                and (k.status = 'draft' or x.recount_requested)) then
    raise exception 'COUNT_INCOMPLETE';
  end if;
  -- số hệ thống đã chụp lúc đếm (st_save); dòng nào còn thiếu thì chụp bây giờ
  update stocktake_lines x set
         system_qty = coalesce(x.system_qty, _inv_stock(x.ingredient_id)),
         unit_cost = coalesce(x.unit_cost, (select i.unit_cost from ingredients i where i.id = x.ingredient_id)),
         recount_requested = false
   where x.stocktake_id = p_id and (k.status = 'draft' or x.recount_requested);
  update stocktakes set status = 'submitted', submitted_at = now(), saved_at = now() where id = p_id;
  return jsonb_build_object('id', p_id, 'code', k.code, 'status', 'submitted',
                            'line_count', (select count(*) from stocktake_lines where stocktake_id = p_id));
end $$;

-- Chủ: danh sách phiếu kiểm kê
create or replace function st_list(p_status text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_perm('inventory.approve'); v_shop := app_shop_id();
  if p_status is not null and p_status not in ('draft', 'submitted', 'recount', 'approved') then raise exception 'KIND_INVALID'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'id', k.id, 'code', k.code, 'status', k.status, 'submitted_at', k.submitted_at, 'reviewed_at', k.reviewed_at,
             'staff_name', (select s.full_name from staff s where s.id = k.started_by),
             'line_count', (select count(*) from stocktake_lines l where l.stocktake_id = k.id),
             'variance_lines', (select count(*) from stocktake_lines l where l.stocktake_id = k.id and l.system_qty is not null and l.counted_qty <> l.system_qty),
             'net_value', (select round(sum((l.counted_qty - l.system_qty) * coalesce(l.unit_cost, 0)))::bigint
                             from stocktake_lines l where l.stocktake_id = k.id and l.system_qty is not null))
           order by coalesce(k.submitted_at, k.started_at) desc)
      from (select * from stocktakes x where x.shop_id = v_shop and (p_status is null or x.status = p_status)
             order by coalesce(x.submitted_at, x.started_at) desc limit 30) k), '[]'::jsonb);
end $$;

-- Chủ: chi tiết một phiếu, có số hệ thống và chênh lệch
create or replace function st_detail(p_id uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; k stocktakes;
begin
  perform _require_perm('inventory.approve'); v_shop := app_shop_id();
  select * into k from stocktakes where id = p_id and shop_id = v_shop;
  if not found then raise exception 'NOT_FOUND'; end if;
  return jsonb_build_object(
    'id', k.id, 'code', k.code, 'status', k.status, 'started_at', k.started_at, 'submitted_at', k.submitted_at,
    'reviewed_at', k.reviewed_at, 'review_reason', k.review_reason, 'review_note', k.review_note,
    'staff_name', (select s.full_name from staff s where s.id = k.started_by),
    'reviewer_name', (select s.full_name from staff s where s.id = k.reviewed_by),
    'stock_value_now', coalesce((select round(sum(greatest(s.stock, 0) * i.unit_cost))::bigint
                                   from ingredients i join _inv_stock_all(v_shop) s on s.ingredient_id = i.id
                                  where i.shop_id = v_shop and i.active and i.unit_cost is not null), 0),
    'lines', coalesce((
      select jsonb_agg(jsonb_build_object(
               'ingredient_id', l.ingredient_id, 'name', i.name, 'unit', i.unit, 'group_name', i.group_name,
               'counted_qty', l.counted_qty, 'system_qty', l.system_qty, 'unit_cost', l.unit_cost,
               'variance', case when l.system_qty is null then null else l.counted_qty - l.system_qty end,
               'variance_value', case when l.system_qty is null then null
                                      else round((l.counted_qty - l.system_qty) * coalesce(l.unit_cost, 0))::bigint end,
               'recount_prev_qty', l.recount_prev_qty, 'recount_requested', l.recount_requested, 'decision', l.decision,
               'counted_at', l.counted_at)
             order by abs(coalesce(l.counted_qty - l.system_qty, 0)) desc, i.name)
        from stocktake_lines l join ingredients i on i.id = l.ingredient_id
       where l.stocktake_id = k.id), '[]'::jsonb));
end $$;

create or replace function st_request_recount(p_id uuid, p_ingredients uuid[], p_note text default null) returns void
language plpgsql security definer set search_path = public as $$
declare k stocktakes; v_n integer;
begin
  perform _require_perm('inventory.approve');
  select * into k from stocktakes where id = p_id and shop_id = app_shop_id() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if k.status <> 'submitted' then raise exception 'STOCKTAKE_LOCKED'; end if;
  if p_ingredients is null or array_length(p_ingredients, 1) is null then raise exception 'LINES_REQUIRED'; end if;
  -- xóa số hệ thống cũ: lần đếm lại sẽ chụp số mới lúc đếm
  update stocktake_lines set recount_requested = true, system_qty = null, unit_cost = null
   where stocktake_id = p_id and ingredient_id = any (p_ingredients);
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'NOT_FOUND'; end if;
  update stocktakes set status = 'recount', review_note = nullif(btrim(p_note), '') where id = p_id;
  perform _audit('st_recount', 'stocktake', p_id, jsonb_build_object('code', k.code, 'lines', v_n));
end $$;

-- Duyệt: dòng nào chọn 'adjust' thì ghi 1 dòng điều chỉnh vào sổ kho (KHÔNG tạo hao hụt). Phải có lý do.
create or replace function st_approve(p_id uuid, p_decisions jsonb, p_reason text, p_note text default null) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_perm('inventory.approve'); k stocktakes; e jsonb; l stocktake_lines; v_adj integer := 0; v_net numeric := 0;
  v_reason text := btrim(coalesce(p_reason, ''));
begin
  select * into k from stocktakes where id = p_id and shop_id = app_shop_id() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if k.status <> 'submitted' then raise exception 'STOCKTAKE_LOCKED'; end if;
  if char_length(v_reason) < 3 then raise exception 'REASON_REQUIRED'; end if;
  update stocktake_lines set decision = 'keep' where stocktake_id = p_id;
  for e in select * from jsonb_array_elements(coalesce(p_decisions, '[]'::jsonb)) loop
    if coalesce(e->>'decision', '') not in ('adjust', 'keep') then raise exception 'DECISION_INVALID'; end if;
    select * into l from stocktake_lines where stocktake_id = p_id and ingredient_id = (e->>'ingredient_id')::uuid for update;
    if not found then raise exception 'NOT_FOUND'; end if;
    update stocktake_lines set decision = e->>'decision' where id = l.id;
    if e->>'decision' = 'adjust' and l.counted_qty <> l.system_qty then
      insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, is_correction, note)
      values (null, l.ingredient_id, 'adjust', l.counted_qty - l.system_qty, p_id, v_me, true, v_reason);
      v_adj := v_adj + 1;
      v_net := v_net + (l.counted_qty - l.system_qty) * coalesce(l.unit_cost, 0);
    end if;
  end loop;
  update stocktakes set status = 'approved', reviewed_by = v_me, reviewed_at = now(),
         review_reason = v_reason, review_note = nullif(btrim(p_note), '') where id = p_id;
  perform _audit('st_approve', 'stocktake', p_id, jsonb_build_object('code', k.code, 'adjusted', v_adj, 'net_value', round(v_net)));
  return jsonb_build_object('id', p_id, 'code', k.code, 'adjusted_lines', v_adj, 'net_value', round(v_net)::bigint);
exception when invalid_text_representation then raise exception 'INPUT_INVALID';
end $$;

-- ======================================================================
-- 10) Hao hụt theo lô (HH) + yêu cầu sửa
-- ======================================================================
create or replace function inv_waste_add(p_ingredient uuid, p_qty integer, p_type text, p_note text default null, p_lot uuid default null)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_perm('inventory.record'); v_shift uuid := _open_shift_id(); v_shop uuid := app_shop_id();
  v_wt waste_types; v_id uuid; v_code text;
begin
  if p_qty is null or p_qty <= 0 or p_qty > 1000000000 then raise exception 'QTY_INVALID'; end if;
  select * into v_wt from waste_types where code = p_type and active and shop_id = v_shop;
  if not found then raise exception 'WASTE_TYPE_INVALID'; end if;
  if v_wt.requires_note and char_length(btrim(coalesce(p_note, ''))) < 5 then raise exception 'NOTE_REQUIRED'; end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = v_shop and active) then raise exception 'NOT_FOUND'; end if;
  if p_lot is not null and not exists (select 1 from stock_lots where id = p_lot and ingredient_id = p_ingredient and shop_id = v_shop) then
    raise exception 'NOT_FOUND';
  end if;
  v_code := _inv_code('HH');
  insert into waste_logs (shift_id, ingredient_id, qty, reason_type, reason, entered_by, code, lot_id)
  values (v_shift, p_ingredient, p_qty, p_type, coalesce(nullif(btrim(p_note), ''), v_wt.label_vi), v_me, v_code, p_lot)
  returning id into v_id;
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'waste', -p_qty, v_id, v_me);
  return jsonb_build_object('id', v_id, 'code', v_code, 'at', now());
end $$;

create or replace function inv_request_correction(p_kind text, p_ref uuid, p_note text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_id uuid;
begin
  if p_kind not in ('waste', 'purchase') then raise exception 'KIND_INVALID'; end if;
  if char_length(btrim(coalesce(p_note, ''))) < 3 then raise exception 'NOTE_REQUIRED'; end if;
  if p_kind = 'waste' and not exists (select 1 from waste_logs where id = p_ref and shop_id = app_shop_id() and entered_by = v_me) then
    raise exception 'NOT_FOUND';
  end if;
  if p_kind = 'purchase' and not exists (select 1 from purchase_orders where id = p_ref and shop_id = app_shop_id() and created_by = v_me) then
    raise exception 'NOT_FOUND';
  end if;
  insert into inventory_requests (kind, ref_id, note, created_by) values (p_kind, p_ref, btrim(p_note), v_me) returning id into v_id;
  return v_id;
end $$;

create or replace function inv_requests() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_perm('inventory.costs');
  return coalesce((select jsonb_agg(jsonb_build_object(
            'id', r.id, 'kind', r.kind, 'ref_id', r.ref_id, 'note', r.note, 'created_at', r.created_at,
            'staff_name', (select s.full_name from staff s where s.id = r.created_by),
            'ref_code', case r.kind when 'waste' then (select w.code from waste_logs w where w.id = r.ref_id)
                                    else (select po.code from purchase_orders po where po.id = r.ref_id) end)
            order by r.created_at desc)
          from inventory_requests r where r.shop_id = app_shop_id() and r.status = 'open'), '[]'::jsonb);
end $$;

create or replace function inv_request_resolve(p_id uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();
  update inventory_requests set status = 'resolved', resolved_at = now() where id = p_id and shop_id = app_shop_id() and status = 'open';
  if not found then raise exception 'NOT_FOUND'; end if;
end $$;

-- Hao hụt bằng tiền (chủ): theo lý do, theo nguyên liệu, theo ngày; so với kỳ trước cùng độ dài
create or replace function inv_waste_overview(p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_days integer; v_prev_from date; v_from_ts timestamptz; v_to_ts timestamptz;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then raise exception 'DATE_RANGE_INVALID'; end if;
  v_days := p_to - p_from + 1; v_prev_from := p_from - v_days;
  v_from_ts := _biz_start(p_from);
  v_to_ts := _biz_start(p_to + 1);
  return (
    with w as (
      select w.id, w.code, w.ingredient_id, w.reason_type, w.qty, w.entered_at, i.name, i.unit, i.unit_cost,
             round(w.qty * coalesce(i.unit_cost, 0))::bigint as value
        from waste_logs w join ingredients i on i.id = w.ingredient_id
       where w.shop_id = v_shop and w.entered_at >= _biz_start(v_prev_from) and w.entered_at < v_to_ts),
    cur as (select * from w where entered_at >= v_from_ts),
    prv as (select * from w where entered_at < v_from_ts)
    select jsonb_build_object(
      'from', p_from, 'to', p_to, 'updated_at', now(),
      'total_value', coalesce((select sum(value) from cur), 0),
      'prev_value', coalesce((select sum(value) from prv), 0),
      'entry_count', (select count(*) from cur),
      'unpriced_count', (select count(*) from cur where unit_cost is null),
      'by_reason', coalesce((
        select jsonb_agg(jsonb_build_object(
                 'code', r.code, 'label', coalesce(t.label_vi, r.code), 'value', r.v, 'prev_value', r.pv, 'count', r.n) order by r.v desc)
          from (select c.reason_type as code, sum(c.value) as v, count(*) as n,
                       coalesce((select sum(p.value) from prv p where p.reason_type = c.reason_type), 0) as pv
                  from cur c group by c.reason_type) r
          left join waste_types t on t.shop_id = v_shop and t.code = r.code), '[]'::jsonb),
      'by_ingredient', coalesce((
        select jsonb_agg(jsonb_build_object('ingredient_id', g.ingredient_id, 'name', g.name, 'unit', g.unit,
                                            'qty', g.q, 'value', g.v) order by g.v desc, g.name)
          from (select c.ingredient_id, c.name, c.unit, sum(c.qty) as q, sum(c.value) as v from cur c
                 group by c.ingredient_id, c.name, c.unit) g), '[]'::jsonb),
      'daily', coalesce((
        select jsonb_agg(jsonb_build_object('date', d.day, 'value', coalesce(x.v, 0)) order by d.day)
          from (select p_from + g as day from generate_series(0, p_to - p_from) g) d
          left join (select _biz_day(c.entered_at) as day, sum(c.value) as v from cur c group by 1) x on x.day = d.day), '[]'::jsonb)));
end $$;

-- ======================================================================
-- 11) Tổng quan kho, tuần nhìn lại, đổi quán, trang chủ kho của nhân viên
-- ======================================================================
create or replace function _inv_shop_numbers(p_shop uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'stock_value', coalesce((select round(sum(greatest(s.stock, 0) * i.unit_cost))::bigint
                               from ingredients i join _inv_stock_all(p_shop) s on s.ingredient_id = i.id
                              where i.shop_id = p_shop and i.active and i.unit_cost is not null), 0),
    'waste_7d', coalesce((select round(sum(-l.qty_delta * coalesce(i.unit_cost, 0)))::bigint
                            from stock_ledger l join ingredients i on i.id = l.ingredient_id
                           where l.shop_id = p_shop and l.kind = 'waste' and l.at >= now() - interval '7 days'), 0))
$$;

create or replace function inv_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_res jsonb; v_sug jsonb;
begin
  perform _require_perm('inventory.costs'); v_shop := app_shop_id();
  v_sug := po_suggestions();
  with st as (select * from _inv_stock_all(v_shop)),
       us as (select * from _inv_daily_use(v_shop, 7)),
  base as (
    select i.id, i.name, i.unit, i.group_name, i.unit_cost, i.min_stock_qty, greatest(st.stock, 0) as stock, st.stock as raw_stock,
           us.per_day, round(greatest(st.stock, 0) * i.unit_cost)::bigint as value
      from ingredients i join st on st.ingredient_id = i.id left join us on us.ingredient_id = i.id
     where i.shop_id = v_shop and i.active),
  lots as (select * from _inv_lots_all(v_shop) where qty_remaining > 0 and expiry_date is not null)
  select jsonb_build_object(
    'updated_at', now(),
    'stock_value', coalesce((select sum(value) from base where unit_cost is not null), 0),
    'unpriced_count', (select count(*) from base where unit_cost is null and stock > 0),
    'top_items', coalesce((select jsonb_agg(jsonb_build_object('id', t.id, 'name', t.name, 'value', t.value) order by t.value desc)
                             from (select * from base where value > 0 order by value desc limit 3) t), '[]'::jsonb),
    'low_items', coalesce((select jsonb_agg(jsonb_build_object(
                    'id', b.id, 'name', b.name, 'unit', b.unit, 'stock', b.raw_stock,
                    'days_left', case when b.per_day > 0 then round(b.stock / b.per_day, 1) end,
                    'status', _inv_status(b.raw_stock, b.min_stock_qty))
                    order by (case when b.per_day > 0 then b.stock / b.per_day end) nulls last, b.name)
                    from base b where _inv_status(b.raw_stock, b.min_stock_qty) <> 'ok'
                      and (b.min_stock_qty > 0 or b.per_day > 0)), '[]'::jsonb),
    'expiring_lots', coalesce((select jsonb_agg(jsonb_build_object(
                    'ingredient_id', l.ingredient_id, 'name', (select n.name from base n where n.id = l.ingredient_id),
                    'code', l.code, 'expiry_date', l.expiry_date, 'qty_remaining', l.qty_remaining)
                    order by l.expiry_date)
                    from lots l where l.expiry_date <= _vn_day(now()) + 3), '[]'::jsonb),
    'pending_stocktakes', coalesce((select jsonb_agg(jsonb_build_object(
                    'id', k.id, 'code', k.code, 'submitted_at', k.submitted_at,
                    'staff_name', (select s.full_name from staff s where s.id = k.started_by),
                    'variance_lines', (select count(*) from stocktake_lines l where l.stocktake_id = k.id and l.counted_qty <> l.system_qty))
                    order by k.submitted_at)
                    from stocktakes k where k.shop_id = v_shop and k.status = 'submitted'), '[]'::jsonb),
    'needs_pricing_count', (select count(*) from purchase_orders where shop_id = v_shop and status = 'confirmed' and needs_pricing),
    'draft_order_count', (select count(*) from purchase_orders where shop_id = v_shop and status = 'draft'),
    'open_request_count', (select count(*) from inventory_requests where shop_id = v_shop and status = 'open'),
    'suggestion_count', jsonb_array_length(v_sug->'items'),
    'waste_7d', coalesce((select round(sum(-l.qty_delta * coalesce(i.unit_cost, 0)))::bigint
                            from stock_ledger l join ingredients i on i.id = l.ingredient_id
                           where l.shop_id = v_shop and l.kind = 'waste' and l.at >= now() - interval '7 days'), 0),
    'waste_prev_7d', coalesce((select round(sum(-l.qty_delta * coalesce(i.unit_cost, 0)))::bigint
                            from stock_ledger l join ingredients i on i.id = l.ingredient_id
                           where l.shop_id = v_shop and l.kind = 'waste'
                             and l.at >= now() - interval '14 days' and l.at < now() - interval '7 days'), 0),
    'ingredient_count', (select count(*) from base))
    into v_res;
  return v_res;
end $$;

create or replace function inv_week_review(p_from date, p_to date) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_days integer; v_from_ts timestamptz; v_to_ts timestamptz; v_stable integer := 0; v_total integer := 0; r record;
begin
  perform _require_owner(); v_shop := app_shop_id();
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 62 then raise exception 'DATE_RANGE_INVALID'; end if;
  v_days := p_to - p_from + 1;
  v_from_ts := _biz_start(p_from);
  v_to_ts := _biz_start(p_to + 1);
  -- một ngày "kho ổn" = mọi ca đóng trong ngày đó không có nguyên liệu lệch vàng/đỏ khi đối soát
  for r in
    select _biz_day(s.closed_at) as day,
           bool_and(not exists (select 1 from reconcile_shift(s.id) x where x.status in ('warn', 'alert'))) as ok
      from shifts s
     where s.shop_id = v_shop and s.status = 'closed' and s.closed_at >= v_from_ts and s.closed_at < v_to_ts
     group by 1
  loop
    v_total := v_total + 1;
    if r.ok then v_stable := v_stable + 1; end if;
  end loop;
  return jsonb_build_object(
    'from', p_from, 'to', p_to, 'days', v_days,
    'stock_value', (_inv_shop_numbers(v_shop)->>'stock_value')::bigint,
    'waste_value', coalesce((select round(sum(-l.qty_delta * coalesce(i.unit_cost, 0)))::bigint
                               from stock_ledger l join ingredients i on i.id = l.ingredient_id
                              where l.shop_id = v_shop and l.kind = 'waste' and l.at >= v_from_ts and l.at < v_to_ts), 0),
    'stable_days', v_stable, 'counted_days', v_total,
    'stocktakes_approved', (select count(*) from stocktakes where shop_id = v_shop and status = 'approved'
                              and reviewed_at >= v_from_ts and reviewed_at < v_to_ts),
    'orders_confirmed', (select count(*) from purchase_orders where shop_id = v_shop and status = 'confirmed'
                           and confirmed_at >= v_from_ts and confirmed_at < v_to_ts),
    'pending_stocktakes', (select count(*) from stocktakes where shop_id = v_shop and status = 'submitted'));
end $$;

-- Các quán mà người dùng là CHỦ: số liệu kho từng quán (dùng cho màn Đổi quán)
create or replace function inv_shops_snapshot() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_out jsonb := '[]'::jsonb; r record; v_n jsonb;
begin
  perform _require_owner();
  for r in
    select s.shop_id, sh.name, s.full_name, (s.shop_id = app_shop_id()) as is_current
      from staff s join shops sh on sh.id = s.shop_id
     where s.auth_user_id = auth.uid() and s.active and s.role = 'owner'
     order by s.created_at
  loop
    v_n := _inv_shop_numbers(r.shop_id);
    v_out := v_out || jsonb_build_object('shop_id', r.shop_id, 'shop_name', r.name, 'owner_name', r.full_name,
                                         'is_current', r.is_current, 'stock_value', v_n->'stock_value',
                                         'waste_7d', v_n->'waste_7d', 'updated_at', now());
  end loop;
  return v_out;
end $$;

-- Trang chủ Kho của nhân viên: việc cần làm, KHÔNG có số tồn/giá
create or replace function inv_staff_home() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shop uuid := app_shop_id(); v_shift shifts; k stocktakes; v_hint jsonb;
begin
  select * into v_shift from shifts where shop_id = v_shop and status = 'open' limit 1;
  select * into k from stocktakes where shop_id = v_shop and started_by = v_me
   order by (status in ('draft', 'recount')) desc, coalesce(submitted_at, started_at) desc limit 1;
  select jsonb_build_object('ingredient_name', i.name, 'lot_code', l.code, 'expiry_date', l.expiry_date)
    into v_hint
    from _inv_lots_all(v_shop) l join ingredients i on i.id = l.ingredient_id
   where l.qty_remaining > 0 and l.expiry_date is not null and l.expiry_date <= _vn_day(now()) + 7
   order by l.expiry_date limit 1;
  return jsonb_build_object(
    'staff_name', (select full_name from staff where id = v_me),
    'shift_opened_at', v_shift.opened_at,
    'shift_open', v_shift.id is not null,
    'stocktake', case when k.id is null then null else jsonb_build_object(
        'id', k.id, 'code', k.code, 'status', k.status, 'saved_at', k.saved_at, 'submitted_at', k.submitted_at,
        'counted', (select count(*) from stocktake_lines l where l.stocktake_id = k.id and l.counted_qty is not null),
        'total', (select count(*) from stocktake_lines l where l.stocktake_id = k.id),
        'review_note', case when k.status = 'recount' then k.review_note end) end,
    'hint', v_hint);
end $$;

-- ======================================================================
-- 12) Bảo mật: RLS (chủ đọc), không ai ghi trực tiếp; chỉ chạy qua hàm
-- ======================================================================
alter table inv_code_counters      enable row level security;
alter table ingredient_groups      enable row level security;
alter table suppliers              enable row level security;
alter table purchase_orders        enable row level security;
alter table purchase_order_lines   enable row level security;
alter table stock_lots             enable row level security;
alter table ingredient_cost_events enable row level security;
alter table stocktakes             enable row level security;
alter table stocktake_lines        enable row level security;
alter table inventory_requests     enable row level security;

grant select on ingredient_groups, suppliers, purchase_orders, purchase_order_lines, stock_lots,
                ingredient_cost_events, stocktakes, stocktake_lines, inventory_requests to authenticated;

do $$
declare t text;
begin
  foreach t in array array['ingredient_groups', 'suppliers', 'purchase_orders', 'purchase_order_lines', 'stock_lots',
                           'ingredient_cost_events', 'stocktakes', 'stocktake_lines', 'inventory_requests'] loop
    execute format('drop policy if exists %I on %I', t || '_owner_read', t);
    execute format('create policy %I on %I for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()))',
                   t || '_owner_read', t);
  end loop;
end $$;

-- Phiếu nhập / kiểm kê / hao hụt là chứng từ: đã chốt thì không sửa, không xóa bằng đường tắt
create or replace function inv_lock_confirmed() returns trigger
language plpgsql as $$
begin
  if tg_op = 'DELETE' and old.status <> 'draft' then raise exception 'ORDER_NOT_DRAFT' using errcode = '42501'; end if;
  return old;
end $$;
drop trigger if exists purchase_orders_no_delete on purchase_orders;
create trigger purchase_orders_no_delete before delete on purchase_orders for each row execute function inv_lock_confirmed();
drop trigger if exists stocktakes_no_delete on stocktakes;
create trigger stocktakes_no_delete before delete on stocktakes for each row execute function inv_lock_confirmed();
drop trigger if exists stock_lots_no_change on stock_lots;
create trigger stock_lots_no_change before delete on stock_lots for each row execute function prevent_mutation();


-- Tenant integrity: business references must never cross shop boundaries.
-- Preflight reports legacy bad rows and does not rewrite or delete any data.
do $tenant_preflight$
begin
  if exists (select 1 from ingredients x left join suppliers p on p.id=x.default_supplier_id and p.shop_id=x.shop_id where x.default_supplier_id is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT ingredients.default_supplier_id: cross-shop or missing supplier rows'; end if;
  if exists (select 1 from stock_ledger x left join shifts p on p.id=x.shift_id and p.shop_id=x.shop_id where x.shift_id is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stock_ledger.shift_id: cross-shop or missing shift rows'; end if;
  if exists (select 1 from stock_ledger x left join ingredients p on p.id=x.ingredient_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stock_ledger.ingredient_id: cross-shop or missing ingredient rows'; end if;
  if exists (select 1 from stock_ledger x left join staff p on p.id=x.created_by and p.shop_id=x.shop_id where x.created_by is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stock_ledger.created_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from waste_logs x left join shifts p on p.id=x.shift_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT waste_logs.shift_id: cross-shop or missing shift rows'; end if;
  if exists (select 1 from waste_logs x left join ingredients p on p.id=x.ingredient_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT waste_logs.ingredient_id: cross-shop or missing ingredient rows'; end if;
  if exists (select 1 from waste_logs x left join staff p on p.id=x.entered_by and p.shop_id=x.shop_id where x.entered_by is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT waste_logs.entered_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from purchase_orders x left join suppliers p on p.id=x.supplier_id and p.shop_id=x.shop_id where x.supplier_id is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT purchase_orders.supplier_id: cross-shop or missing supplier rows'; end if;
  if exists (select 1 from purchase_orders x left join staff p on p.id=x.created_by and p.shop_id=x.shop_id where x.created_by is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT purchase_orders.created_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from purchase_orders x left join staff p on p.id=x.confirmed_by and p.shop_id=x.shop_id where x.confirmed_by is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT purchase_orders.confirmed_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from purchase_order_lines x left join purchase_orders p on p.id=x.order_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT purchase_order_lines.order_id: cross-shop or missing order rows'; end if;
  if exists (select 1 from purchase_order_lines x left join ingredients p on p.id=x.ingredient_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT purchase_order_lines.ingredient_id: cross-shop or missing ingredient rows'; end if;
  if exists (select 1 from purchase_order_lines x left join stock_lots p on p.id=x.lot_id and p.shop_id=x.shop_id where x.lot_id is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT purchase_order_lines.lot_id: cross-shop or missing lot rows'; end if;
  if exists (select 1 from stock_lots x left join ingredients p on p.id=x.ingredient_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stock_lots.ingredient_id: cross-shop or missing ingredient rows'; end if;
  if exists (select 1 from stock_lots x left join purchase_order_lines p on p.id=x.order_line_id and p.shop_id=x.shop_id where x.order_line_id is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stock_lots.order_line_id: cross-shop or missing order line rows'; end if;
  if exists (select 1 from ingredient_cost_events x left join ingredients p on p.id=x.ingredient_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT ingredient_cost_events.ingredient_id: cross-shop or missing ingredient rows'; end if;
  if exists (select 1 from ingredient_cost_events x left join purchase_orders p on p.id=x.order_id and p.shop_id=x.shop_id where x.order_id is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT ingredient_cost_events.order_id: cross-shop or missing order rows'; end if;
  if exists (select 1 from ingredient_cost_events x left join staff p on p.id=x.created_by and p.shop_id=x.shop_id where x.created_by is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT ingredient_cost_events.created_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from stocktakes x left join staff p on p.id=x.started_by and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stocktakes.started_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from stocktakes x left join staff p on p.id=x.reviewed_by and p.shop_id=x.shop_id where x.reviewed_by is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stocktakes.reviewed_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from stocktake_lines x left join stocktakes p on p.id=x.stocktake_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stocktake_lines.stocktake_id: cross-shop or missing stocktake rows'; end if;
  if exists (select 1 from stocktake_lines x left join ingredients p on p.id=x.ingredient_id and p.shop_id=x.shop_id where p.id is null) then raise exception 'TENANT_FK_PREFLIGHT stocktake_lines.ingredient_id: cross-shop or missing ingredient rows'; end if;
  if exists (select 1 from inventory_requests x left join staff p on p.id=x.created_by and p.shop_id=x.shop_id where x.created_by is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT inventory_requests.created_by: cross-shop or missing staff rows'; end if;
  if exists (select 1 from waste_logs x left join stock_lots p on p.id=x.lot_id and p.shop_id=x.shop_id where x.lot_id is not null and p.id is null) then raise exception 'TENANT_FK_PREFLIGHT waste_logs.lot_id: cross-shop or missing lot rows'; end if;
end
$tenant_preflight$;

-- A referenced composite key is required for purchase_order_lines.lot_id / stock_lots.order_line_id.
create unique index if not exists purchase_order_lines_shop_id_id_key
  on purchase_order_lines (shop_id, id);

do $tenant_constraints$
declare
  r record;
begin
  for r in
    select * from (values
      ('purchase_orders', 'purchase_orders_supplier_same_shop_fk', 'shop_id, supplier_id', 'suppliers', 'shop_id, id'),
      ('ingredients', 'ingredients_default_supplier_same_shop_fk', 'shop_id, default_supplier_id', 'suppliers', 'shop_id, id'),
      ('stock_ledger', 'stock_ledger_shift_same_shop_fk', 'shop_id, shift_id', 'shifts', 'shop_id, id'),
      ('stock_ledger', 'stock_ledger_ingredient_same_shop_fk', 'shop_id, ingredient_id', 'ingredients', 'shop_id, id'),
      ('stock_ledger', 'stock_ledger_actor_same_shop_fk', 'shop_id, created_by', 'staff', 'shop_id, id'),
      ('waste_logs', 'waste_logs_shift_same_shop_fk', 'shop_id, shift_id', 'shifts', 'shop_id, id'),
      ('waste_logs', 'waste_logs_ingredient_same_shop_fk', 'shop_id, ingredient_id', 'ingredients', 'shop_id, id'),
      ('waste_logs', 'waste_logs_actor_same_shop_fk', 'shop_id, entered_by', 'staff', 'shop_id, id'),
      ('purchase_orders', 'purchase_orders_created_by_same_shop_fk', 'shop_id, created_by', 'staff', 'shop_id, id'),
      ('purchase_orders', 'purchase_orders_confirmed_by_same_shop_fk', 'shop_id, confirmed_by', 'staff', 'shop_id, id'),
      ('purchase_order_lines', 'purchase_order_lines_order_same_shop_fk', 'shop_id, order_id', 'purchase_orders', 'shop_id, id'),
      ('purchase_order_lines', 'purchase_order_lines_ingredient_same_shop_fk', 'shop_id, ingredient_id', 'ingredients', 'shop_id, id'),
      ('purchase_order_lines', 'purchase_order_lines_lot_same_shop_fk', 'shop_id, lot_id', 'stock_lots', 'shop_id, id'),
      ('stock_lots', 'stock_lots_ingredient_same_shop_fk', 'shop_id, ingredient_id', 'ingredients', 'shop_id, id'),
      ('stock_lots', 'stock_lots_order_line_same_shop_fk', 'shop_id, order_line_id', 'purchase_order_lines', 'shop_id, id'),
      ('ingredient_cost_events', 'ingredient_cost_events_ingredient_same_shop_fk', 'shop_id, ingredient_id', 'ingredients', 'shop_id, id'),
      ('ingredient_cost_events', 'ingredient_cost_events_order_same_shop_fk', 'shop_id, order_id', 'purchase_orders', 'shop_id, id'),
      ('ingredient_cost_events', 'ingredient_cost_events_actor_same_shop_fk', 'shop_id, created_by', 'staff', 'shop_id, id'),
      ('stocktakes', 'stocktakes_started_by_same_shop_fk', 'shop_id, started_by', 'staff', 'shop_id, id'),
      ('stocktakes', 'stocktakes_reviewed_by_same_shop_fk', 'shop_id, reviewed_by', 'staff', 'shop_id, id'),
      ('stocktake_lines', 'stocktake_lines_stocktake_same_shop_fk', 'shop_id, stocktake_id', 'stocktakes', 'shop_id, id'),
      ('stocktake_lines', 'stocktake_lines_ingredient_same_shop_fk', 'shop_id, ingredient_id', 'ingredients', 'shop_id, id'),
      ('inventory_requests', 'inventory_requests_actor_same_shop_fk', 'shop_id, created_by', 'staff', 'shop_id, id'),
      ('waste_logs', 'waste_logs_lot_same_shop_fk', 'shop_id, lot_id', 'stock_lots', 'shop_id, id')
    ) as constraints(table_name, constraint_name, source_columns, target_table, target_columns)
  loop
    if not exists (
      select 1 from pg_constraint c
       where c.conrelid = format('%I', r.table_name)::regclass
         and c.conname = r.constraint_name
    ) then
      execute format('alter table %I add constraint %I foreign key (%s) references %I (%s)%s',
        r.table_name, r.constraint_name, r.source_columns, r.target_table, r.target_columns,
        case when r.constraint_name in (
          'purchase_order_lines_order_same_shop_fk',
          'stocktake_lines_stocktake_same_shop_fk'
        ) then ' on delete cascade' else '' end);
    end if;
  end loop;
end
$tenant_constraints$;

-- ======================================================================
-- 13) Quyền gọi
-- ======================================================================
revoke all on function
  inv_groups(), inv_group_save(uuid, text), inv_group_set_active(uuid, boolean),
  sup_save(uuid, jsonb), sup_set_active(uuid, boolean), sup_list(), sup_options(), sup_detail(uuid),
  inv_ingredient_save(uuid, jsonb), inv_ingredient_set_active(uuid, boolean), inv_catalog(text, text, boolean),
  inv_ingredient_profile(uuid), inv_ingredient_history(uuid, text, integer), inv_picker(), inv_lots_for_staff(uuid),
  po_save(uuid, jsonb, boolean), po_cancel(uuid, text), po_set_prices(uuid, jsonb), po_detail(uuid), po_list(text, integer),
  po_impact(uuid), po_suggestions(), po_from_suggestions(jsonb),
  st_start(), st_sheet(uuid), st_save(uuid, jsonb), st_submit(uuid), st_list(text), st_detail(uuid),
  st_request_recount(uuid, uuid[], text), st_approve(uuid, jsonb, text, text),
  inv_waste_add(uuid, integer, text, text, uuid), inv_request_correction(text, uuid, text), inv_requests(),
  inv_request_resolve(uuid), inv_waste_overview(date, date), inv_overview(), inv_week_review(date, date),
  inv_shops_snapshot(), inv_staff_home()
  from public, anon, authenticated;
grant execute on function
  inv_groups(), inv_group_save(uuid, text), inv_group_set_active(uuid, boolean),
  sup_save(uuid, jsonb), sup_set_active(uuid, boolean), sup_list(), sup_options(), sup_detail(uuid),
  inv_ingredient_save(uuid, jsonb), inv_ingredient_set_active(uuid, boolean), inv_catalog(text, text, boolean),
  inv_ingredient_profile(uuid), inv_ingredient_history(uuid, text, integer), inv_picker(), inv_lots_for_staff(uuid),
  po_save(uuid, jsonb, boolean), po_cancel(uuid, text), po_set_prices(uuid, jsonb), po_detail(uuid), po_list(text, integer),
  po_impact(uuid), po_suggestions(), po_from_suggestions(jsonb),
  st_start(), st_sheet(uuid), st_save(uuid, jsonb), st_submit(uuid), st_list(text), st_detail(uuid),
  st_request_recount(uuid, uuid[], text), st_approve(uuid, jsonb, text, text),
  inv_waste_add(uuid, integer, text, text, uuid), inv_request_correction(text, uuid, text), inv_requests(),
  inv_request_resolve(uuid), inv_waste_overview(date, date), inv_overview(), inv_week_review(date, date),
  inv_shops_snapshot(), inv_staff_home()
  to authenticated;
-- Hàm nội bộ: không ai gọi trực tiếp từ app
revoke all on function
  _inv_code(text), _inv_stock_all(uuid), _inv_stock(uuid), _inv_daily_use(uuid, integer), _inv_lots_all(uuid),
  _vn_day(timestamptz), _biz_day(timestamptz), _biz_start(date), _inv_status(integer, integer), _inv_apply_cost(uuid, numeric, integer, integer, timestamptz, uuid, uuid),
  _po_json(uuid, boolean), _po_apply(uuid, uuid), _inv_shop_numbers(uuid), inv_seed_trg(), inv_lock_confirmed()
  from public, anon, authenticated;
