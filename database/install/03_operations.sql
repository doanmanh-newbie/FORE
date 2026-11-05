-- Fore canonical install module: 03_operations.sql
-- Run modules in numeric order after database/dev/reset_schema.sql on a test project.

-- >>> Integrated source: database/003_actions.sql
-- =====================================================================
-- Fore · 003_actions.sql · Các thao tác nghiệp vụ (app gọi qua supabase.rpc)
-- Nhân viên KHÔNG ghi trực tiếp vào bảng bán hàng/kho; chỉ gọi các hàm này.
-- Lỗi nghiệp vụ trả về dạng mã chữ (ví dụ 'TABLE_HAS_OPEN_BILL') để app dịch ra tiếng Việt.
-- Chạy SAU 002_rules.sql.
-- =====================================================================

-- ---------- Hàm nội bộ ----------
create or replace function _require_staff() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid := app_staff_id();
begin
  if v is null then raise exception 'NOT_STAFF'; end if;
  return v;
end $$;

create or replace function _require_owner() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid := app_staff_id();
begin
  if v is null or not app_is_owner() then raise exception 'OWNER_ONLY'; end if;
  return v;
end $$;

create or replace function _open_shift_id() returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid;
begin
  select id into v from shifts where status = 'open' and shop_id = app_shop_id();
  if v is null then raise exception 'NO_OPEN_SHIFT'; end if;
  return v;
end $$;

create or replace function _audit(p_action text, p_entity text, p_id uuid, p_detail jsonb default null) returns void
language sql security definer set search_path = public as $$
  insert into audit_log (actor, action, entity, entity_id, detail)
  values (app_staff_id(), p_action, p_entity, p_id, p_detail)
$$;

-- ---------- PIN ----------
create or replace function set_staff_pin(p_staff uuid, p_pin text) returns void
language plpgsql security definer set search_path = public, extensions as $$
begin
  perform _require_owner();
  if p_pin !~ '^[0-9]{4,6}$' then raise exception 'PIN_FORMAT'; end if;
  update staff set pin_hash = crypt(p_pin, gen_salt('bf')) where id = p_staff and shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;
  perform _audit('set_pin', 'staff', p_staff);
end $$;

-- Kiểm tra PIN chủ. Trả về id chủ nếu đúng; NULL nếu sai.
-- Sai liên tiếp quá pin_max_attempts lần trong pin_lock_minutes phút thì khóa (cả hai là con số trong app_settings).
-- (Không raise lỗi khi sai PIN để lần thử sai vẫn được ghi lại, không bị rollback.)
create or replace function _check_owner_pin(p_pin text, out owner_id uuid, out result text)
language plpgsql security definer set search_path = public, extensions as $$
declare v_me uuid := _require_staff(); v_last_ok timestamptz; v_fail int;
        v_max int := _setting('pin_max_attempts', 3); v_lock int := _setting('pin_lock_minutes', 15);
begin
  select max(at) into v_last_ok from pin_attempts where staff_id = v_me and ok;
  select count(*) into v_fail from pin_attempts
   where staff_id = v_me and not ok and at > now() - make_interval(mins => v_lock)
     and (v_last_ok is null or at > v_last_ok);
  if v_fail >= v_max then result := 'PIN_LOCKED'; return; end if;

  select s.id into owner_id from staff s
   where s.shop_id = app_shop_id() and s.role = 'owner' and s.active and s.pin_hash is not null and s.pin_hash = crypt(p_pin, s.pin_hash)
   limit 1;
  insert into pin_attempts (staff_id, ok) values (v_me, owner_id is not null);
  result := case when owner_id is null then 'WRONG_PIN' else 'OK' end;
end $$;

-- ---------- Ca làm việc ----------
create or replace function open_shift(p_opening_cash integer default 0) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_id uuid;
begin
  if p_opening_cash is null or p_opening_cash < 0 then
    raise exception 'OPENING_CASH_INVALID';
  end if;
  begin
    insert into shifts (opened_by, opening_cash) values (v_me, p_opening_cash) returning id into v_id;
  exception when unique_violation then
    raise exception 'SHIFT_ALREADY_OPEN';
  end;
  perform _audit('open_shift', 'shifts', v_id, jsonb_build_object('opening_cash', p_opening_cash));
  return v_id;
end $$;

create or replace function close_shift(p_closing_cash integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_missing int;
begin
  if p_closing_cash is null or p_closing_cash < 0 then
    raise exception 'CLOSING_CASH_INVALID';
  end if;
  -- Khóa dòng ca (FOR UPDATE) trước khi kiểm tra: open_bill giữ khóa FOR SHARE cùng dòng này,
  -- nên không thể có bill mới chen vào giữa lúc kiểm tra và lúc đóng ca.
  perform 1 from shifts where id = v_shift and status = 'open' for update;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;   -- máy khác vừa đóng ca
  if exists (select 1 from bills where shift_id = v_shift and status = 'open') then
    raise exception 'OPEN_BILLS_REMAIN';   -- phải thanh toán hoặc hủy hết bill đang mở
  end if;
  -- Phải đếm kho cuối ca cho mọi nguyên liệu (trừ loại chỉ kiểm theo tuần)
  select count(*) into v_missing from ingredients i
   where i.shop_id = app_shop_id() and i.active and not i.weekly_check
     and not exists (select 1 from stock_counts c
                      where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = 'close');
  if v_missing > 0 then raise exception 'MISSING_CLOSE_COUNTS'; end if;

  update shifts set status = 'closed', closed_by = v_me, closed_at = now(), closing_cash = p_closing_cash
   where id = v_shift;
  perform _audit('close_shift', 'shifts', v_shift, jsonb_build_object('closing_cash', p_closing_cash));
  return v_shift;
end $$;

-- ---------- Bán hàng ----------
create or replace function open_bill(p_table uuid, p_type text, p_guests integer default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  -- Giữ khóa FOR SHARE trên ca và kiểm tra lại ca còn mở (đối ứng với FOR UPDATE trong close_shift)
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;
  if p_type = 'dine_in' and p_table is null then raise exception 'TABLE_REQUIRED'; end if;
  if p_table is not null and not exists (select 1 from dining_tables where id = p_table and shop_id = app_shop_id()) then
    raise exception 'TABLE_NOT_FOUND';
  end if;
  if p_type = 'take_away' then p_table := null; end if;
  begin
    insert into bills (shift_id, table_id, bill_type, guests, opened_by)
    values (v_shift, p_table, p_type, p_guests, v_me) returning id into v_id;
  exception when unique_violation then
    raise exception 'TABLE_HAS_OPEN_BILL';   -- bàn này đang có bill mở (máy khác vừa mở)
  end;
  return v_id;
end $$;

-- FIX 2: giới hạn qty (max_line_qty từ app_settings) + tổng bill dùng bigint; FIX 5: FOR SHARE trên ca
create or replace function add_bill_line(p_bill uuid, p_size uuid, p_qty integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me        uuid    := _require_staff();
  v_status    text;
  v_shift     uuid;
  v_price     integer;
  v_id        uuid;
  v_max_qty   integer;
  v_cur_total bigint;
begin
  select b.status, b.shift_id into v_status, v_shift
    from bills b where b.id = p_bill and b.shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;
  v_max_qty := _setting('max_line_qty', 99);
  if p_qty > v_max_qty then raise exception 'QTY_TOO_LARGE'; end if;

  select price into v_price from menu_sizes where id = p_size and active and shop_id = app_shop_id();
  if v_price is null then raise exception 'ITEM_UNAVAILABLE'; end if;

  select coalesce(sum(bl.qty::bigint * bl.unit_price), 0)
    into v_cur_total
    from bill_lines bl where bl.bill_id = p_bill and bl.voided_at is null;
  if v_cur_total + (p_qty::bigint * v_price) > 2000000000 then
    raise exception 'BILL_TOTAL_OVERFLOW';
  end if;

  insert into bill_lines (bill_id, size_id, qty, unit_price, created_by)
  values (p_bill, p_size, p_qty, v_price, v_me) returning id into v_id;
  return v_id;
end $$;

-- FIX 3: trả LINE_ALREADY_VOIDED khi dòng đã bị bỏ; FIX 5: FOR SHARE trên ca
create or replace function void_bill_line(p_line uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_me     uuid := _require_staff();
  v_bill   uuid;
  v_shift  uuid;
  v_status text;
  v_voided timestamptz;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;

  select bl.bill_id, bl.voided_at into v_bill, v_voided
    from bill_lines bl where bl.id = p_line and bl.shop_id = app_shop_id();
  if not found then raise exception 'NOT_FOUND'; end if;
  if v_voided is not null then raise exception 'LINE_ALREADY_VOIDED'; end if;

  select b.status, b.shift_id into v_status, v_shift
    from bills b where b.id = v_bill and b.shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  update bill_lines set voided_at = now(), voided_by = v_me, void_reason = p_reason
   where id = p_line;
  perform _audit('void_line', 'bill_lines', p_line, jsonb_build_object('reason', p_reason, 'bill', v_bill));
end $$;

create or replace function set_bill_discount(p_bill uuid, p_discount integer, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_status text; v_sub integer;
begin
  perform _require_staff();
  select status into v_status from bills where id = p_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  select coalesce(sum(qty * unit_price), 0) into v_sub from bill_lines where bill_id = p_bill and voided_at is null;
  if p_discount < 0 or p_discount > v_sub then raise exception 'DISCOUNT_INVALID'; end if;
  if p_discount > 0 and coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  update bills set discount = p_discount, discount_reason = p_reason where id = p_bill;
  perform _audit('discount', 'bills', p_bill, jsonb_build_object('discount', p_discount, 'reason', p_reason));
end $$;

-- Thanh toán. FIX 1: kiểm tra discount <= subtotal sau khi có thể đã bỏ dòng; dùng bigint tránh tràn số.
create or replace function pay_bill(p_bill uuid, p_method text default 'cash') returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := _require_staff();
  v_bill  bills%rowtype;
  v_sub   bigint;
  v_total bigint;
  v_n     integer;
begin
  if p_method is null or p_method not in ('cash', 'transfer') then
    raise exception 'PAYMENT_METHOD_INVALID';
  end if;
  select * into v_bill from bills where id = p_bill and shop_id = app_shop_id() for update;
  if not found or v_bill.status <> 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  select coalesce(sum(bl.qty::bigint * bl.unit_price), 0)
    into v_sub
    from bill_lines bl where bl.bill_id = p_bill and bl.voided_at is null;
  if v_sub = 0 then raise exception 'BILL_EMPTY'; end if;

  -- FIX 1: giảm giá có thể lớn hơn tổng nếu nhân viên bỏ dòng sau khi set discount
  if v_bill.discount > v_sub then raise exception 'DISCOUNT_INVALID'; end if;
  v_total := v_sub - v_bill.discount;

  update bills
     set status = 'paid', paid_at = now(), paid_by = v_me,
         payment_method = p_method, total_amount = v_total::integer
   where id = p_bill and status = 'open';
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'BILL_NOT_OPEN'; end if;

  -- Ghi sổ kho: mỗi dòng bán x công thức tại THỜI ĐIỂM bán (đổi công thức sau này không làm lệch ca cũ)
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, r.ingredient_id, 'sale',
         (-sum(bl.qty::bigint * r.qty))::integer, p_bill, v_me
    from bill_lines bl
    join recipe_lines r on r.size_id = bl.size_id
   where bl.bill_id = p_bill and bl.voided_at is null
   group by r.ingredient_id;

  perform _audit('pay', 'bills', p_bill, jsonb_build_object('total', v_total, 'method', p_method));
  return v_total::integer;
end $$;

-- Hủy bill CHƯA thanh toán (cần lý do, ghi nhật ký)
create or replace function cancel_open_bill(p_bill uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_status text;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select status into v_status from bills where id = p_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  update bills set status = 'cancelled', cancelled_by = v_me, cancelled_at = now(), cancel_reason = p_reason where id = p_bill;
  perform _audit('cancel_open', 'bills', p_bill, jsonb_build_object('reason', p_reason));
end $$;

-- Hủy bill ĐÃ thu tiền: chủ phải đứng đó nhập PIN trên máy nhân viên; chỉ trong ca hiện tại.
-- Trả về mã trạng thái: 'OK' | 'WRONG_PIN' | 'PIN_LOCKED'. Lỗi khác sẽ raise.
create or replace function cancel_paid_bill(p_bill uuid, p_owner_pin text, p_reason text) returns text
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_bill bills%rowtype; v_pin record;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select * into v_bill from bills where id = p_bill and shop_id = app_shop_id() for update;
  if not found or v_bill.status <> 'paid' then raise exception 'BILL_NOT_PAID'; end if;
  if v_bill.shift_id <> _open_shift_id() then raise exception 'ONLY_CURRENT_SHIFT'; end if;

  select * into v_pin from _check_owner_pin(p_owner_pin);
  if v_pin.result <> 'OK' then return v_pin.result; end if;

  update bills set status = 'cancelled', cancelled_by = v_me, cancelled_at = now(),
                   cancel_reason = p_reason, approved_by = v_pin.owner_id
   where id = p_bill;
  -- Hoàn lại sổ kho đúng bằng các dòng đã ghi lúc bán
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select shift_id, ingredient_id, 'void_sale', -qty_delta, p_bill, v_me
    from stock_ledger where kind = 'sale' and ref_id = p_bill;
  perform _audit('cancel_paid', 'bills', p_bill,
                 jsonb_build_object('reason', p_reason, 'approved_by', v_pin.owner_id, 'amount', v_bill.total_amount));
  return 'OK';
end $$;

-- Đơn mang đi: đánh dấu đã làm xong
create or replace function mark_prep_done(p_bill uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_staff();
  update bills set prep_done_at = now()
   where id = p_bill and shop_id = app_shop_id() and bill_type = 'take_away' and status <> 'cancelled' and prep_done_at is null;
end $$;

-- ---------- Kho ----------
-- FIX 4: kiểm tra qty > 0 (QTY_INVALID); FIX 5: FOR SHARE trên ca chống ghi vào ca đã đóng
create or replace function add_purchase(
  p_ingredient uuid,
  p_qty        integer,
  p_late       boolean default false,
  p_note       text    default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := _require_staff();
  v_shift uuid := _open_shift_id();
  v_id    uuid;
begin
  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then
    raise exception 'NOT_FOUND';
  end if;
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  insert into purchases (shift_id, ingredient_id, qty, is_late_entry, note, entered_by)
  values (v_shift, p_ingredient, p_qty, p_late, p_note, v_me) returning id into v_id;
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'purchase', p_qty, v_id, v_me);
  return v_id;
end $$;

-- Kiểm kê MÙ: nhân viên nhập số đo thực tế, hàm này không trả về số dự kiến.
-- FIX 5: FOR SHARE trên ca chống ghi vào ca đã đóng
create or replace function submit_stock_count(p_ingredient uuid, p_kind text, p_qty integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := _require_staff();
  v_shift uuid := _open_shift_id();
  v_id    uuid;
begin
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then
    raise exception 'NOT_FOUND';
  end if;
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  insert into stock_counts (shift_id, ingredient_id, kind, counted_qty, counted_by)
  values (v_shift, p_ingredient, p_kind, p_qty, v_me) returning id into v_id;
  return v_id;
end $$;

-- Hao hụt: phải CHỌN LOẠI trong bảng waste_types (+ ghi chú). Loại có requires_note thì bắt buộc ghi chú.
-- Nguyên liệu tính theo đơn vị gốc (trân châu: gram KHÔ quy đổi).
-- FIX 4: kiểm tra qty > 0 (QTY_INVALID); FIX 5: FOR SHARE trên ca chống ghi vào ca đã đóng
create or replace function add_waste(
  p_ingredient uuid,
  p_qty        integer,
  p_type       text,
  p_note       text default null
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := _require_staff();
  v_shift uuid := _open_shift_id();
  v_id    uuid;
  v_wt    waste_types;
begin
  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;

  select * into v_wt from waste_types where code = p_type and active and shop_id = app_shop_id();
  if not found then raise exception 'WASTE_TYPE_INVALID'; end if;
  if v_wt.requires_note and char_length(btrim(coalesce(p_note, ''))) < 5 then
    raise exception 'NOTE_REQUIRED';
  end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then
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
  return v_id;
end $$;

-- ---------- Cấp quyền chạy hàm ----------
-- Thu mọi quyền chạy hàm, rồi chỉ cấp cho các hàm app được gọi.
revoke all on all functions in schema public from public, anon, authenticated;
alter default privileges in schema public revoke execute on functions from public, anon, authenticated;

grant execute on function app_shop_id(), app_staff_id(), app_is_owner() to authenticated;   -- policy cần dùng
grant execute on function
  set_staff_pin(uuid, text),
  open_shift(integer), close_shift(integer),
  open_bill(uuid, text, integer), add_bill_line(uuid, uuid, integer), void_bill_line(uuid, text),
  set_bill_discount(uuid, integer, text), pay_bill(uuid, text),
  cancel_open_bill(uuid, text), cancel_paid_bill(uuid, text, text), mark_prep_done(uuid),
  add_purchase(uuid, integer, boolean, text), submit_stock_count(uuid, text, integer),
  add_waste(uuid, integer, text, text)
to authenticated;
