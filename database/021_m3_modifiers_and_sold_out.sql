-- Fore · 021_m3_modifiers_and_sold_out.sql · TÙY CHỌN, GHI CHÚ VÀ BÁO HẾT MÓN (M3)
-- Chạy sau 020_m2_payments_and_history.sql; không cần reset dữ liệu.
--
-- Nội dung:
--   1. Bảng modifier_groups, modifier_options, menu_item_modifier_groups.
--   2. Bảng modifier_recipe_lines: định lượng nguyên liệu cho từng topping/tùy chọn (đối soát kho chính xác).
--   3. Cột bill_lines.note và bảng bill_line_modifiers (lưu snapshot tên & giá tùy chọn tại lúc bán).
--   4. Bảng sold_out_items_in_shift: báo hết món tạm thời trong ca, tự động hết hiệu lực khi đóng ca.
--   5. Hàm menu_modifiers(): lấy danh sách nhóm và tùy chọn món theo quán/món.
--   6. Hàm set_item_sold_out(p_item, p_sold_out, p_reason): nhân viên báo hết / có lại món trong ca.
--   7. Cập nhật menu_for_sale(): thêm cột sold_out boolean.
--   8. Cập nhật add_bill_line():
--      - Kiểm tra món chưa bị báo hết trong ca (nếu hết -> raise ITEM_SOLD_OUT).
--      - Nhận thêm p_options uuid[] default '{}' và p_note text default null.
--      - Tính đơn giá tổng = size price + sum(option price_delta).
--      - Lưu snapshot vào bill_line_modifiers.
--   9. Cập nhật pay_bill():
--      - Ghi sổ kho không chỉ recipe của size mà cả modifier_recipe_lines của các options đã chọn!
--   10. Cập nhật cancel_paid_bill():
--      - Hoàn lại sổ kho chính xác theo ledger đã ghi.
--   11. Cập nhật bill_detail():
--      - Trả thêm 'note' và danh sách 'modifiers' cho từng dòng bill_lines.
-- =====================================================================

-- 1. Bảng nhóm tùy chọn (vd: Độ ngọt, Lượng đá, Topping)
create table if not exists modifier_groups (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null default app_shop_id() references shops(id),
  name        text not null check (char_length(btrim(name)) >= 1),
  min_select  integer not null default 0 check (min_select >= 0),
  max_select  integer not null default 1 check (max_select >= min_select),
  sort_order  integer not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (shop_id, id)
);

-- Bảng các lựa chọn trong nhóm (vd: 50% đường, Ít đá, Trân châu đen +5.000đ)
create table if not exists modifier_options (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null default app_shop_id() references shops(id),
  group_id    uuid not null references modifier_groups(id),
  name        text not null check (char_length(btrim(name)) >= 1),
  price_delta integer not null default 0 check (price_delta >= 0), -- phụ thu (đồng)
  is_default  boolean not null default false,
  sort_order  integer not null default 0,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (shop_id, id)
);

-- Liên kết món với nhóm tùy chọn
create table if not exists menu_item_modifier_groups (
  shop_id     uuid not null default app_shop_id() references shops(id),
  item_id     uuid not null references menu_items(id),
  group_id    uuid not null references modifier_groups(id),
  sort_order  integer not null default 0,
  primary key (item_id, group_id)
);

-- 2. Định lượng nguyên liệu cho tùy chọn (topping tiêu hao nguyên liệu)
create table if not exists modifier_recipe_lines (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null default app_shop_id() references shops(id),
  option_id     uuid not null references modifier_options(id),
  ingredient_id uuid not null references ingredients(id),
  qty           integer not null check (qty > 0),
  unique (option_id, ingredient_id)
);

-- 3. Cột ghi chú trong bill_lines và bảng lưu tùy chọn đã chọn lúc bán
alter table bill_lines add column if not exists note text;

create table if not exists bill_line_modifiers (
  id           uuid primary key default gen_random_uuid(),
  shop_id      uuid not null default app_shop_id() references shops(id),
  bill_line_id uuid not null references bill_lines(id),
  option_id    uuid not null references modifier_options(id),
  option_name  text not null,                       -- snapshot tên lúc bán
  price_delta  integer not null default 0,          -- snapshot phụ thu lúc bán
  created_at   timestamptz not null default now()
);
create index if not exists bill_line_mod_idx on bill_line_modifiers (bill_line_id);

-- 4. Báo hết món tạm thời trong ca
create table if not exists sold_out_items_in_shift (
  shop_id     uuid not null default app_shop_id() references shops(id),
  shift_id    uuid not null references shifts(id),
  item_id     uuid not null references menu_items(id),
  marked_by   uuid not null references staff(id),
  marked_at   timestamptz not null default now(),
  reason      text,
  primary key (shift_id, item_id)
);

-- 5. API đọc danh sách tùy chọn của thực đơn
create or replace function menu_modifiers()
returns table (
  group_id      uuid,
  group_name    text,
  min_select    integer,
  max_select    integer,
  option_id     uuid,
  option_name   text,
  price_delta   integer,
  is_default    boolean,
  item_ids      uuid[]
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
begin
  perform _require_staff();

  return query
    select
      g.id,
      g.name,
      g.min_select,
      g.max_select,
      o.id,
      o.name,
      o.price_delta,
      o.is_default,
      coalesce((select array_agg(mimg.item_id)
                  from menu_item_modifier_groups mimg
                 where mimg.group_id = g.id and mimg.shop_id = v_shop), '{}'::uuid[])
    from modifier_groups g
    join modifier_options o on o.group_id = g.id
   where g.active and o.active and g.shop_id = v_shop and o.shop_id = v_shop
   order by g.sort_order, g.name, o.sort_order, o.price_delta, o.name;
end $$;

-- 6. API nhân viên báo hết / mở lại món trong ca
create or replace function set_item_sold_out(
  p_item     uuid,
  p_sold_out boolean,
  p_reason   text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := _require_staff();
  v_shift uuid := _open_shift_id();
  v_shop  uuid := app_shop_id();
begin
  if not exists (select 1 from menu_items where id = p_item and shop_id = v_shop) then
    raise exception 'NOT_FOUND';
  end if;

  if p_sold_out then
    insert into sold_out_items_in_shift (shop_id, shift_id, item_id, marked_by, marked_at, reason)
    values (v_shop, v_shift, p_item, v_me, now(), nullif(btrim(p_reason), ''))
    on conflict (shift_id, item_id) do update set
      marked_by = excluded.marked_by,
      marked_at = now(),
      reason    = excluded.reason;

    perform _audit('sold_out', 'menu_items', p_item,
                   jsonb_build_object('shift', v_shift, 'reason', p_reason));
  else
    delete from sold_out_items_in_shift
     where shift_id = v_shift and item_id = p_item and shop_id = v_shop;

    perform _audit('available', 'menu_items', p_item, jsonb_build_object('shift', v_shift));
  end if;
end $$;

-- 7. Cập nhật menu_for_sale() kèm cờ sold_out
drop function if exists menu_for_sale();

create or replace function menu_for_sale()
returns table (
  item_id     uuid,
  item_name   text,
  group_name  text,
  size_id     uuid,
  size_name   text,
  price       integer,
  sold_out    boolean
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_shift uuid;
  v_shop  uuid := app_shop_id();
begin
  perform _require_staff();
  select id into v_shift from shifts where status = 'open' and shop_id = v_shop;

  return query
    select
      mi.id,
      mi.name,
      mi.group_name,
      ms.id,
      ms.size_name,
      ms.price,
      exists(select 1 from sold_out_items_in_shift so
              where so.shift_id = v_shift and so.item_id = mi.id) as sold_out
    from menu_items mi
    join menu_sizes ms on ms.item_id = mi.id
   where mi.active and ms.active and mi.shop_id = v_shop and ms.shop_id = v_shop
   order by mi.group_name nulls last, mi.name, ms.price, ms.size_name;
end $$;

-- 8. Cập nhật add_bill_line() hỗ trợ options, ghi chú và kiểm tra sold_out
create or replace function add_bill_line(
  p_bill       uuid,
  p_size       uuid,
  p_qty        integer,
  p_request_id uuid    default null,
  p_options    uuid[]  default '{}',
  p_note       text    default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me         uuid    := _require_staff();
  v_shop       uuid    := app_shop_id();
  v_status     text;
  v_shift      uuid;
  v_item_id    uuid;
  v_base_price integer;
  v_opt_delta  integer := 0;
  v_unit_price integer;
  v_id         uuid;
  v_existing   uuid;
  v_max_qty    integer;
  v_cur_total  bigint;
  v_clean_note text    := nullif(btrim(p_note), '');
  v_opt        record;
begin
  if p_request_id is not null then
    select response_id into v_existing
      from client_requests
     where shop_id = v_shop and request_id = p_request_id and action = 'add_bill_line';
    if v_existing is not null then
      return v_existing;
    end if;
  end if;

  select b.status, b.shift_id into v_status, v_shift
    from bills b where b.id = p_bill and b.shop_id = v_shop for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;
  v_max_qty := _setting('max_line_qty', 99);
  if p_qty > v_max_qty then raise exception 'QTY_TOO_LARGE'; end if;

  select ms.price, ms.item_id into v_base_price, v_item_id
    from menu_sizes ms where ms.id = p_size and ms.active and ms.shop_id = v_shop;
  if v_base_price is null then raise exception 'ITEM_UNAVAILABLE'; end if;

  -- Kiểm tra món có đang bị báo hết trong ca không
  if exists (select 1 from sold_out_items_in_shift where shift_id = v_shift and item_id = v_item_id) then
    raise exception 'ITEM_SOLD_OUT';
  end if;

  -- Tính tổng phụ thu từ các options hợp lệ
  if p_options is not null and array_length(p_options, 1) > 0 then
    select coalesce(sum(price_delta), 0)::integer into v_opt_delta
      from modifier_options
     where id = any(p_options) and active and shop_id = v_shop;
  end if;

  v_unit_price := v_base_price + v_opt_delta;

  select coalesce(sum(bl.qty::bigint * bl.unit_price), 0)
    into v_cur_total
    from bill_lines bl where bl.bill_id = p_bill and bl.voided_at is null;
  if v_cur_total + (p_qty::bigint * v_unit_price) > 2000000000 then
    raise exception 'BILL_TOTAL_OVERFLOW';
  end if;

  insert into bill_lines (bill_id, size_id, qty, unit_price, note, created_by)
  values (p_bill, p_size, p_qty, v_unit_price, v_clean_note, v_me)
  returning id into v_id;

  -- Lưu snapshot modifiers cho dòng này
  if p_options is not null and array_length(p_options, 1) > 0 then
    for v_opt in
      select id, name, price_delta from modifier_options
       where id = any(p_options) and active and shop_id = v_shop
    loop
      insert into bill_line_modifiers (shop_id, bill_line_id, option_id, option_name, price_delta)
      values (v_shop, v_id, v_opt.id, v_opt.name, v_opt.price_delta);
    end loop;
  end if;

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_id)
    values (v_shop, p_request_id, 'add_bill_line', v_id)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_id;
end $$;

-- 9. Cập nhật pay_bill(): ghi sổ kho cho cả recipe của size VÀ topping (modifier_recipe_lines)
create or replace function pay_bill(
  p_bill       uuid,
  p_method     text    default 'cash',
  p_request_id uuid    default null,
  p_tendered   integer default null,
  p_ref        text    default null
) returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_me       uuid := _require_staff();
  v_shop     uuid := app_shop_id();
  v_bill     bills%rowtype;
  v_sub      bigint;
  v_total    bigint;
  v_n        integer;
  v_existing integer;
  v_clean_ref text := nullif(btrim(p_ref), '');
begin
  if p_request_id is not null then
    select response_int into v_existing
      from client_requests
     where shop_id = v_shop and request_id = p_request_id and action = 'pay_bill';
    if v_existing is not null then
      return v_existing;
    end if;
  end if;

  if p_method is null or p_method not in ('cash', 'transfer') then
    raise exception 'PAYMENT_METHOD_INVALID';
  end if;

  select * into v_bill from bills where id = p_bill and shop_id = v_shop for update;
  if not found or v_bill.status <> 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  select coalesce(sum(bl.qty::bigint * bl.unit_price), 0)
    into v_sub
    from bill_lines bl where bl.bill_id = p_bill and bl.voided_at is null;
  if v_sub = 0 then raise exception 'BILL_EMPTY'; end if;

  if v_bill.discount > v_sub then raise exception 'DISCOUNT_INVALID'; end if;
  v_total := v_sub - v_bill.discount;

  if p_tendered is not null and p_tendered < v_total then
    raise exception 'TENDERED_INSUFFICIENT';
  end if;

  update bills
     set status          = 'paid',
         paid_at         = now(),
         paid_by         = v_me,
         payment_method  = p_method,
         total_amount    = v_total::integer,
         tendered_amount = p_tendered,
         payment_ref     = v_clean_ref
   where id = p_bill and status = 'open';
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'BILL_NOT_OPEN'; end if;

  -- Ghi sổ kho 1: Nguyên liệu theo recipe của size
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, r.ingredient_id, 'sale',
         (-sum(bl.qty::bigint * r.qty))::integer, p_bill, v_me
    from bill_lines bl
    join recipe_lines r on r.size_id = bl.size_id
   where bl.bill_id = p_bill and bl.voided_at is null
   group by r.ingredient_id;

  -- Ghi sổ kho 2: Nguyên liệu tiêu hao theo topping / options (nếu có công thức)
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, mr.ingredient_id, 'sale',
         (-sum(bl.qty::bigint * mr.qty))::integer, p_bill, v_me
    from bill_lines bl
    join bill_line_modifiers blm on blm.bill_line_id = bl.id
    join modifier_recipe_lines mr on mr.option_id = blm.option_id
   where bl.bill_id = p_bill and bl.voided_at is null
   group by mr.ingredient_id;

  perform _audit('pay', 'bills', p_bill,
    jsonb_build_object('total', v_total, 'method', p_method, 'tendered', p_tendered, 'ref', v_clean_ref));

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_int)
    values (v_shop, p_request_id, 'pay_bill', v_total::integer)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_total::integer;
end $$;

-- 10. Cập nhật bill_detail() trả thêm note và modifiers
create or replace function bill_detail(p_bill uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_bill record;
  v_lines jsonb;
  v_sub bigint;
  v_payable bigint;
begin
  perform _require_staff();
  select b.id, b.bill_no, b.status, b.bill_type, b.table_id, b.guests, b.opened_at, b.discount, b.discount_reason,
         b.total_amount, b.payment_method, b.tendered_amount, b.payment_ref,
         b.cancelled_at, b.cancel_reason, b.approved_by,
         b.prep_done_at, t.name as table_name, a.name as area_name
    into v_bill
    from bills b
    left join dining_tables t on t.id = b.table_id
    left join areas a on a.id = t.area_id
   where b.id = p_bill and b.shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;

  select coalesce(jsonb_agg(jsonb_build_object(
                    'id', l.id,
                    'size_id', l.size_id,
                    'item_name', mi.name,
                    'size_name', ms.size_name,
                    'qty', l.qty,
                    'unit_price', l.unit_price,
                    'note', l.note,
                    'voided', l.voided_at is not null,
                    'modifiers', coalesce((
                      select jsonb_agg(jsonb_build_object(
                        'name', m.option_name,
                        'price_delta', m.price_delta
                      ) order by m.created_at)
                      from bill_line_modifiers m
                      where m.bill_line_id = l.id
                    ), '[]'::jsonb)
                  ) order by l.created_at, l.id), '[]'::jsonb),
         coalesce(sum(l.qty::bigint * l.unit_price) filter (where l.voided_at is null), 0)
    into v_lines, v_sub
    from bill_lines l
    join menu_sizes ms on ms.id = l.size_id
    join menu_items mi on mi.id = ms.item_id
   where l.bill_id = p_bill;

  v_payable := case when v_bill.status = 'open' then greatest(v_sub - v_bill.discount, 0)
                    else coalesce(v_bill.total_amount, 0) end;
  return jsonb_build_object(
    'id', v_bill.id, 'bill_no', v_bill.bill_no, 'status', v_bill.status, 'bill_type', v_bill.bill_type,
    'table_id', v_bill.table_id, 'table_name', v_bill.table_name, 'area_name', v_bill.area_name,
    'guests', v_bill.guests, 'opened_at', v_bill.opened_at, 'discount', v_bill.discount,
    'discount_reason', v_bill.discount_reason, 'payment_method', v_bill.payment_method,
    'tendered_amount', v_bill.tendered_amount, 'payment_ref', v_bill.payment_ref,
    'cancelled_at', v_bill.cancelled_at, 'cancel_reason', v_bill.cancel_reason,
    'prep_done', v_bill.prep_done_at is not null,
    'lines', v_lines, 'subtotal', v_sub, 'payable', v_payable);
end $$;

-- 11. Phân quyền
revoke all on function
  menu_modifiers(),
  set_item_sold_out(uuid, boolean, text),
  menu_for_sale(),
  add_bill_line(uuid, uuid, integer, uuid, uuid[], text),
  pay_bill(uuid, text, uuid, integer, text),
  bill_detail(uuid)
from public, anon;

grant execute on function
  menu_modifiers(),
  set_item_sold_out(uuid, boolean, text),
  menu_for_sale(),
  add_bill_line(uuid, uuid, integer, uuid, uuid[], text),
  pay_bill(uuid, text, uuid, integer, text),
  bill_detail(uuid)
to authenticated;
