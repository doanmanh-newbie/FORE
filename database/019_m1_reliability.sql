-- Fore · 019_m1_reliability.sql · ĐỘ TIN CẬY VÀ ĐỒNG BỘ DỮ LIỆU (M1)
-- Chạy sau 018_p0_fixes.sql; không cần reset dữ liệu.
--
-- Nội dung:
--   1. Bảng client_requests lưu idempotency key (chống gửi trùng khi mất mạng/thử lại).
--   2. Hàm ops_settings(): trả các cấu hình nhân viên cần biết (max_line_qty, serving_label, server_now...).
--   3. Hàm ops_version(): trả số phiên bản tăng dần theo ca/bill của quán, phục vụ đồng bộ realtime polling giá rẻ.
--   4. Nâng cấp các hàm ghi nhận tham số p_request_id (open_bill, add_bill_line, pay_bill, add_purchase, add_waste).
-- =====================================================================

-- 1. Bảng lưu trữ idempotency request
create table if not exists client_requests (
  shop_id     uuid not null references shops(id),
  request_id  uuid not null,
  action      text not null,
  response_id uuid,
  response_int integer,
  created_at  timestamptz not null default now(),
  primary key (shop_id, request_id)
);

create index if not exists client_requests_created_idx
  on client_requests (created_at);

-- 2. Hàm ops_settings(): cấu hình vận hành cho ca nhân viên
create or replace function ops_settings()
returns table (
  shop_id            uuid,
  shop_name          text,
  max_line_qty       integer,
  serving_label      text,
  require_guests     boolean,
  discount_pin_threshold integer,
  server_now         timestamptz
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid;
  v_name text;
begin
  perform _require_staff();
  v_shop := app_shop_id();
  select name into v_name from shops where id = v_shop;

  return query select
    v_shop,
    v_name,
    _setting('max_line_qty', 99, v_shop),
    'phần'::text,
    false,
    _setting('discount_pin_above_pct', 0, v_shop),
    now();
end $$;

-- 3. Hàm ops_version(): đồng bộ nhanh giữa các thiết bị
create or replace function ops_version()
returns table (
  version     bigint,
  server_now  timestamptz
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid;
  v_ver  bigint;
begin
  perform _require_staff();
  v_shop := app_shop_id();

  select coalesce(
    (select extract(epoch from max(t))::bigint
       from (
         select max(opened_at) as t from shifts where shop_id = v_shop
         union all
         select max(closed_at) as t from shifts where shop_id = v_shop
         union all
         select max(opened_at) as t from bills where shop_id = v_shop
         union all
         select max(paid_at) as t from bills where shop_id = v_shop
         union all
         select max(cancelled_at) as t from bills where shop_id = v_shop
         union all
         select max(prep_done_at) as t from bills where shop_id = v_shop
         union all
         select max(created_at) as t from bill_lines where shop_id = v_shop
         union all
         select max(voided_at) as t from bill_lines where shop_id = v_shop
       ) x),
    0
  ) into v_ver;

  return query select v_ver, now();
end $$;

-- 4. Bổ sung server_now vào current_shift()
drop function if exists current_shift();

create or replace function current_shift()
returns table (
  shift_id        uuid,
  opened_by_name  text,
  opened_at       timestamptz,
  opened_by_me    boolean,
  open_bills      integer,
  server_now      timestamptz
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_me uuid := _require_staff();
begin
  return query
    select s.id,
           st.full_name,
           s.opened_at,
           s.opened_by = v_me,
           (select count(*)::integer from bills b where b.shift_id = s.id and b.status = 'open'),
           now()
      from shifts s
      join staff st on st.id = s.opened_by
     where s.status = 'open' and s.shop_id = app_shop_id();
end $$;

-- 5. Cập nhật các hàm ghi kèm p_request_id (idempotency)

-- open_bill
create or replace function open_bill(
  p_table      uuid,
  p_type       text,
  p_guests     integer default null,
  p_request_id uuid    default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me       uuid := _require_staff();
  v_shift    uuid := _open_shift_id();
  v_shop     uuid := app_shop_id();
  v_id       uuid;
  v_existing uuid;
begin
  if p_request_id is not null then
    select response_id into v_existing
      from client_requests
     where shop_id = v_shop and request_id = p_request_id and action = 'open_bill';
    if v_existing is not null then
      return v_existing;
    end if;
  end if;

  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;
  if p_type = 'dine_in' and p_table is null then raise exception 'TABLE_REQUIRED'; end if;
  if p_table is not null and not exists (select 1 from dining_tables where id = p_table and shop_id = v_shop) then
    raise exception 'TABLE_NOT_FOUND';
  end if;
  if p_type = 'take_away' then p_table := null; end if;

  begin
    insert into bills (shift_id, table_id, bill_type, guests, opened_by)
    values (v_shift, p_table, p_type, p_guests, v_me) returning id into v_id;
  exception when unique_violation then
    raise exception 'TABLE_HAS_OPEN_BILL';
  end;

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_id)
    values (v_shop, p_request_id, 'open_bill', v_id)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_id;
end $$;

-- add_bill_line
create or replace function add_bill_line(
  p_bill       uuid,
  p_size       uuid,
  p_qty        integer,
  p_request_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me        uuid    := _require_staff();
  v_shop      uuid    := app_shop_id();
  v_status    text;
  v_shift     uuid;
  v_price     integer;
  v_id        uuid;
  v_existing  uuid;
  v_max_qty   integer;
  v_cur_total bigint;
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

  select price into v_price from menu_sizes where id = p_size and active and shop_id = v_shop;
  if v_price is null then raise exception 'ITEM_UNAVAILABLE'; end if;

  select coalesce(sum(bl.qty::bigint * bl.unit_price), 0)
    into v_cur_total
    from bill_lines bl where bl.bill_id = p_bill and bl.voided_at is null;
  if v_cur_total + (p_qty::bigint * v_price) > 2000000000 then
    raise exception 'BILL_TOTAL_OVERFLOW';
  end if;

  insert into bill_lines (bill_id, size_id, qty, unit_price, created_by)
  values (p_bill, p_size, p_qty, v_price, v_me) returning id into v_id;

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_id)
    values (v_shop, p_request_id, 'add_bill_line', v_id)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_id;
end $$;

-- pay_bill
create or replace function pay_bill(
  p_bill       uuid,
  p_method     text default 'cash',
  p_request_id uuid default null
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

  update bills
     set status = 'paid', paid_at = now(), paid_by = v_me,
         payment_method = p_method, total_amount = v_total::integer
   where id = p_bill and status = 'open';
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'BILL_NOT_OPEN'; end if;

  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, r.ingredient_id, 'sale',
         (-sum(bl.qty::bigint * r.qty))::integer, p_bill, v_me
    from bill_lines bl
    join recipe_lines r on r.size_id = bl.size_id
   where bl.bill_id = p_bill and bl.voided_at is null
   group by r.ingredient_id;

  perform _audit('pay', 'bills', p_bill, jsonb_build_object('total', v_total, 'method', p_method));

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_int)
    values (v_shop, p_request_id, 'pay_bill', v_total::integer)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_total::integer;
end $$;

-- add_purchase
create or replace function add_purchase(
  p_ingredient uuid,
  p_qty        integer,
  p_late       boolean default false,
  p_note       text    default null,
  p_request_id uuid    default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me       uuid := _require_staff();
  v_shop     uuid := app_shop_id();
  v_shift    uuid := _open_shift_id();
  v_id       uuid;
  v_existing uuid;
begin
  if p_request_id is not null then
    select response_id into v_existing
      from client_requests
     where shop_id = v_shop and request_id = p_request_id and action = 'add_purchase';
    if v_existing is not null then
      return v_existing;
    end if;
  end if;

  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = v_shop) then
    raise exception 'NOT_FOUND';
  end if;
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  insert into purchases (shift_id, ingredient_id, qty, is_late_entry, note, entered_by)
  values (v_shift, p_ingredient, p_qty, p_late, p_note, v_me) returning id into v_id;
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'purchase', p_qty, v_id, v_me);

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_id)
    values (v_shop, p_request_id, 'add_purchase', v_id)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_id;
end $$;

-- add_waste
create or replace function add_waste(
  p_ingredient uuid,
  p_qty        integer,
  p_type       text,
  p_note       text default null,
  p_request_id uuid default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me       uuid := _require_staff();
  v_shop     uuid := app_shop_id();
  v_shift    uuid := _open_shift_id();
  v_id       uuid;
  v_wt       waste_types;
  v_existing uuid;
begin
  if p_request_id is not null then
    select response_id into v_existing
      from client_requests
     where shop_id = v_shop and request_id = p_request_id and action = 'add_waste';
    if v_existing is not null then
      return v_existing;
    end if;
  end if;

  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;
  select * into v_wt from waste_types where code = p_type and active and shop_id = v_shop;
  if not found then raise exception 'WASTE_TYPE_INVALID'; end if;
  if v_wt.requires_note and char_length(btrim(coalesce(p_note, ''))) < 5 then
    raise exception 'NOTE_REQUIRED';
  end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = v_shop) then
    raise exception 'NOT_FOUND';
  end if;

  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  insert into waste_logs (shift_id, ingredient_id, qty, reason_type, reason, entered_by)
  values (v_shift, p_ingredient, p_qty, p_type,
          coalesce(nullif(btrim(p_note), ''), v_wt.label_vi), v_me)
  returning id into v_id;
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'waste', -p_qty, v_id, v_me);

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_id)
    values (v_shop, p_request_id, 'add_waste', v_id)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_id;
end $$;

-- 6. Phân quyền thực thi
revoke all on function
  ops_settings(),
  ops_version(),
  current_shift(),
  open_bill(uuid, text, integer, uuid),
  add_bill_line(uuid, uuid, integer, uuid),
  pay_bill(uuid, text, uuid),
  add_purchase(uuid, integer, boolean, text, uuid),
  add_waste(uuid, integer, text, text, uuid)
from public, anon;

grant execute on function
  ops_settings(),
  ops_version(),
  current_shift(),
  open_bill(uuid, text, integer, uuid),
  add_bill_line(uuid, uuid, integer, uuid),
  pay_bill(uuid, text, uuid),
  add_purchase(uuid, integer, boolean, text, uuid),
  add_waste(uuid, integer, text, text, uuid)
to authenticated;
