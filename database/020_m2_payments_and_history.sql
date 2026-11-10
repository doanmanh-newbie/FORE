-- Fore · 020_m2_payments_and_history.sql · THANH TOÁN NÂNG CAO VÀ LỊCH SỬ BILL (M2)
-- Chạy sau 019_m1_reliability.sql; không cần reset dữ liệu.
--
-- Nội dung:
--   1. Thêm cột tendered_amount, payment_ref vào bảng bills.
--   2. Bảng payment_settings: lưu thông tin QR/chuyển khoản (ngân hàng, stk, chủ tk, cú pháp).
--   3. Hàm payment_qr_info() (nhân viên đọc) và set_payment_info(...) (chủ sửa).
--   4. Nâng cấp pay_bill nhận thêm:
--      - p_tendered (tiền khách đưa): kiểm tra >= phải thu nếu là tiền mặt
--      - p_ref (mã giao dịch chuyển khoản): lưu đối soát
--   5. Hàm shift_bills(p_limit, p_before): danh sách bill của ca đang mở (phục vụ lịch sử/tìm lại bill).
--   6. Hàm owner_pin_status(): kiểm tra chủ quán đã cài mã PIN chưa.
-- =====================================================================

-- 1. Thêm cột lưu tiền khách đưa và mã giao dịch chuyển khoản vào bills
alter table bills add column if not exists tendered_amount integer check (tendered_amount >= 0);
alter table bills add column if not exists payment_ref text;

-- 2. Bảng cấu hình chuyển khoản/QR ngân hàng cho từng quán
create table if not exists payment_settings (
  shop_id        uuid primary key references shops(id),
  bank_code      text not null,                       -- ví dụ: VCB, MB, TCB, ACB, ICB...
  account_no     text not null,                       -- số tài khoản
  account_name   text not null,                       -- tên chủ tài khoản
  content_prefix text not null default 'FORE',        -- cú pháp nội dung ck (vd: FORE BILL84)
  updated_at     timestamptz not null default now(),
  updated_by     uuid references staff(id)
);

-- 3. API thông tin QR / Chuyển khoản
create or replace function payment_qr_info()
returns table (
  configured      boolean,
  bank_code       text,
  account_no      text,
  account_name    text,
  content_prefix  text
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
begin
  perform _require_staff();
  return query
    select
      exists(select 1 from payment_settings ps where ps.shop_id = v_shop),
      ps.bank_code,
      ps.account_no,
      ps.account_name,
      coalesce(ps.content_prefix, 'FORE')
    from (select 1) x
    left join payment_settings ps on ps.shop_id = v_shop;
end $$;

create or replace function set_payment_info(
  p_bank_code      text,
  p_account_no     text,
  p_account_name   text,
  p_content_prefix text default 'FORE'
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me   uuid := _require_owner();
  v_shop uuid := app_shop_id();
begin
  if coalesce(btrim(p_bank_code), '') = '' then raise exception 'BANK_CODE_REQUIRED'; end if;
  if coalesce(btrim(p_account_no), '') = '' then raise exception 'ACCOUNT_NO_REQUIRED'; end if;
  if coalesce(btrim(p_account_name), '') = '' then raise exception 'ACCOUNT_NAME_REQUIRED'; end if;

  insert into payment_settings (shop_id, bank_code, account_no, account_name, content_prefix, updated_at, updated_by)
  values (v_shop, btrim(p_bank_code), btrim(p_account_no), upper(btrim(p_account_name)),
          coalesce(nullif(btrim(p_content_prefix), ''), 'FORE'), now(), v_me)
  on conflict (shop_id) do update set
    bank_code      = excluded.bank_code,
    account_no     = excluded.account_no,
    account_name   = excluded.account_name,
    content_prefix = excluded.content_prefix,
    updated_at     = now(),
    updated_by     = excluded.updated_by;

  perform _audit('set_payment_info', 'payment_settings', v_shop,
                 jsonb_build_object('bank', p_bank_code, 'account', p_account_no));
end $$;

-- 4. Kiểm tra trạng thái PIN của chủ quán
create or replace function owner_pin_status()
returns boolean
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return exists (
    select 1 from staff s
     where s.shop_id = app_shop_id()
       and s.role = 'owner'
       and s.active
       and s.pin_hash is not null
  );
end $$;

-- 5. Nâng cấp pay_bill với p_tendered và p_ref
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
  -- Idempotency kiểm tra lại
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

  -- Kiểm tra tiền khách đưa (nếu có cung cấp)
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

  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, r.ingredient_id, 'sale',
         (-sum(bl.qty::bigint * r.qty))::integer, p_bill, v_me
    from bill_lines bl
    join recipe_lines r on r.size_id = bl.size_id
   where bl.bill_id = p_bill and bl.voided_at is null
   group by r.ingredient_id;

  perform _audit('pay', 'bills', p_bill,
    jsonb_build_object('total', v_total, 'method', p_method, 'tendered', p_tendered, 'ref', v_clean_ref));

  if p_request_id is not null then
    insert into client_requests (shop_id, request_id, action, response_int)
    values (v_shop, p_request_id, 'pay_bill', v_total::integer)
    on conflict (shop_id, request_id) do nothing;
  end if;

  return v_total::integer;
end $$;

-- 6. Xem danh sách bill của ca hiện tại (lịch sử hóa đơn trong ca)
create or replace function shift_bills(
  p_limit  integer     default 50,
  p_before timestamptz default null
)
returns table (
  bill_id         uuid,
  bill_no         bigint,
  bill_type       text,
  status          text,
  table_name      text,
  area_name       text,
  portions        integer,
  total_amount    integer,
  payment_method  text,
  payment_ref     text,
  opened_at       timestamptz,
  paid_at         timestamptz,
  cancelled_at    timestamptz,
  cancel_reason   text
)
language plpgsql stable security definer set search_path = public as $$
declare
  v_shift uuid;
begin
  perform _require_staff();
  v_shift := _open_shift_id();

  return query
    select
      b.id,
      b.bill_no,
      b.bill_type,
      b.status,
      t.name,
      a.name,
      coalesce((select sum(bl.qty)::integer from bill_lines bl where bl.bill_id = b.id and bl.voided_at is null), 0),
      b.total_amount,
      b.payment_method,
      b.payment_ref,
      b.opened_at,
      b.paid_at,
      b.cancelled_at,
      b.cancel_reason
    from bills b
    left join dining_tables t on t.id = b.table_id
    left join areas a on a.id = t.area_id
   where b.shop_id = app_shop_id()
     and b.shift_id = v_shift
     and (p_before is null or b.opened_at < p_before)
   order by b.opened_at desc
   limit greatest(1, least(coalesce(p_limit, 50), 200));
end $$;

-- 7. Nâng cấp bill_detail trả thêm tendered_amount, payment_ref, cancel_reason
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
                    'id', l.id, 'size_id', l.size_id, 'item_name', mi.name, 'size_name', ms.size_name,
                    'qty', l.qty, 'unit_price', l.unit_price, 'voided', l.voided_at is not null)
                  order by l.created_at, l.id), '[]'::jsonb),
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

-- 8. Phân quyền
revoke all on function
  payment_qr_info(),
  set_payment_info(text, text, text, text),
  owner_pin_status(),
  pay_bill(uuid, text, uuid, integer, text),
  shift_bills(integer, timestamptz),
  cancel_paid_bill(uuid, text, text)
from public, anon;

grant execute on function
  payment_qr_info(),
  set_payment_info(text, text, text, text),
  owner_pin_status(),
  pay_bill(uuid, text, uuid, integer, text),
  shift_bills(integer, timestamptz),
  cancel_paid_bill(uuid, text, text)
to authenticated;
