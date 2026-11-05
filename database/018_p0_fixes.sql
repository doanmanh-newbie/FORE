-- Fore · 018_p0_fixes.sql · Sửa lỗi P0 (đưa lại các fix đã có ở đợt 010 vào bản gộp install/)
-- Chạy sau 017_staff_invite_contact_fallback.sql; không cần reset dữ liệu.
--
-- Danh sách lỗi được sửa (theo lộ trình mục 2):
--   1. Giảm giá lớn hơn tổng SAU KHI bỏ dòng → pay_bill kiểm tra lại discount trước khi thu
--   2. Số lượng mỗi dòng không giới hạn → add_bill_line chặn > max_line_qty, tính tiền bằng bigint
--   3. Bỏ một dòng hai lần → void_bill_line trả LINE_ALREADY_VOIDED thay vì im lặng
--   4. Số lượng ≤ 0 khi nhập hàng / hao hụt → add_purchase và add_waste trả QTY_INVALID
--   5. Ghi vào ca vừa đóng → add_purchase, add_waste, submit_stock_count giữ khóa FOR SHARE trên ca
-- =====================================================================

-- Thêm cấu hình giới hạn số lượng mỗi dòng vào _seed_shop
-- (quán đã tạo chạy thêm insert bên dưới; quán mới sẽ tự có qua trigger)
insert into app_settings (shop_id, key, value_int, description)
  select id, 'max_line_qty', 99, 'Số lượng tối đa một dòng bill (mặc định 99); tránh gõ nhầm làm tràn tổng'
    from shops
  on conflict do nothing;

-- Cập nhật _seed_shop để quán mới tự có cấu hình max_line_qty
create or replace function _seed_shop(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into app_settings (shop_id, key, value_int, description) values
    (p_shop, 'important_warn_pct',    3, 'Nguyên liệu quan trọng: lệch từ mức % này trở lên thì cảnh báo vàng'),
    (p_shop, 'important_alert_pct',   5, 'Nguyên liệu quan trọng: lệch từ mức % này trở lên thì cảnh báo đỏ'),
    (p_shop, 'normal_warn_pct',      10, 'Nguyên liệu thường: cảnh báo vàng từ mức % này'),
    (p_shop, 'normal_alert_pct',     15, 'Nguyên liệu thường: cảnh báo đỏ từ mức % này'),
    (p_shop, 'waste_warn_pct',       10, 'Hao hụt có lý do vượt mức % này so với lượng dùng lý thuyết thì cảnh báo'),
    (p_shop, 'cash_warn_vnd',     20000, 'Lệch tiền mặt từ mức này (đồng): cảnh báo vàng'),
    (p_shop, 'cash_alert_vnd',    50000, 'Lệch tiền mặt từ mức này (đồng): cảnh báo đỏ'),
    (p_shop, 'opening_diff_warn_vnd', 1000, 'Tiền đầu ca lệch so với tiền cuối ca trước từ mức này (đồng): đáng chú ý'),
    (p_shop, 'recount_flag_after',    2, 'Một nguyên liệu bị đếm lại quá số lần này trong 1 ca thì đưa vào danh sách cần chú ý'),
    (p_shop, 'streak_shifts',         3, 'Số ca LIÊN TIẾP lệch cùng chiều thì gắn cờ xu hướng (tối thiểu 2)'),
    (p_shop, 'pin_max_attempts',      3, 'Số lần nhập sai PIN chủ liên tiếp thì khóa'),
    (p_shop, 'pin_lock_minutes',     15, 'Số phút khóa PIN sau khi sai quá số lần'),
    (p_shop, 'max_line_qty',         99, 'Số lượng tối đa một dòng bill (mặc định 99); tránh gõ nhầm làm tràn tổng')
  on conflict do nothing;
  insert into waste_types (shop_id, code, label_vi, requires_note, sort_order) values
    (p_shop, 'expired',    'Đổ bỏ (quá giờ/hết hạn)', false, 1),
    (p_shop, 'mistake',    'Làm sai, đổ ly',          false, 2),
    (p_shop, 'staff_meal', 'Cho nhân viên dùng',       false, 3),
    (p_shop, 'tasting',    'Thử vị',                   false, 4),
    (p_shop, 'other',      'Khác (ghi chú rõ)',        true,  9)
  on conflict do nothing;
end $$;

-- =====================================================================
-- FIX 1 & 2 & 3: add_bill_line – giới hạn qty, void_bill_line – chống bỏ 2 lần
-- =====================================================================

-- FIX 2: add_bill_line chặn qty > max_line_qty và tổng bill > 2 tỷ (dùng bigint)
create or replace function add_bill_line(p_bill uuid, p_size uuid, p_qty integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me       uuid    := _require_staff();
  v_status   text;
  v_shift    uuid;
  v_price    integer;
  v_id       uuid;
  v_max_qty  integer;
  v_cur_total bigint;
begin
  -- Khóa bill trước để kiểm tra tuần tự (tránh 2 máy cùng thêm vượt giới hạn)
  select b.status, b.shift_id into v_status, v_shift
    from bills b where b.id = p_bill and b.shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  -- Kiểm tra ca chưa đóng (FOR SHARE đối ứng với FOR UPDATE trong close_shift)
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  -- Kiểm tra số lượng hợp lệ
  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;

  v_max_qty := _setting('max_line_qty', 99);
  if p_qty > v_max_qty then raise exception 'QTY_TOO_LARGE'; end if;

  select price into v_price from menu_sizes where id = p_size and active and shop_id = app_shop_id();
  if v_price is null then raise exception 'ITEM_UNAVAILABLE'; end if;

  -- Kiểm tra tổng bill sau khi thêm không vượt 2 tỷ (tránh tràn integer)
  select coalesce(sum(bl.qty::bigint * bl.unit_price), 0)
    into v_cur_total
    from bill_lines bl
   where bl.bill_id = p_bill and bl.voided_at is null;
  if v_cur_total + (p_qty::bigint * v_price) > 2000000000 then
    raise exception 'BILL_TOTAL_OVERFLOW';
  end if;

  insert into bill_lines (bill_id, size_id, qty, unit_price, created_by)
  values (p_bill, p_size, p_qty, v_price, v_me) returning id into v_id;
  return v_id;
end $$;

-- FIX 3: void_bill_line trả LINE_ALREADY_VOIDED khi dòng đã bị bỏ
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
  -- FIX 3: trả lỗi rõ ràng khi dòng đã bị bỏ, thay vì im lặng
  if v_voided is not null then raise exception 'LINE_ALREADY_VOIDED'; end if;

  select b.status, b.shift_id into v_status, v_shift
    from bills b where b.id = v_bill and b.shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  -- Kiểm tra ca chưa đóng
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  update bill_lines set voided_at = now(), voided_by = v_me, void_reason = p_reason
   where id = p_line;
  perform _audit('void_line', 'bill_lines', p_line, jsonb_build_object('reason', p_reason, 'bill', v_bill));
end $$;

-- =====================================================================
-- FIX 1: pay_bill – kiểm tra discount <= subtotal SAU KHI có thể đã bỏ dòng
-- =====================================================================
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

  -- Dùng bigint cho v_total; ép về integer khi lưu (đã chặn > 2 tỷ ở add_bill_line)
  update bills
     set status = 'paid', paid_at = now(), paid_by = v_me,
         payment_method = p_method, total_amount = v_total::integer
   where id = p_bill and status = 'open';
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'BILL_NOT_OPEN'; end if;

  -- Ghi sổ kho: công thức tại thời điểm bán
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, r.ingredient_id, 'sale',
         (-sum(bl.qty::bigint * r.qty))::integer, p_bill, v_me
    from bill_lines bl
    join recipe_lines r on r.size_id = bl.size_id
   where bl.bill_id = p_bill and bl.voided_at is null
   group by r.ingredient_id;

  perform _audit('pay', 'bills', p_bill,
    jsonb_build_object('total', v_total, 'method', p_method));
  return v_total::integer;
end $$;

-- =====================================================================
-- FIX 4 & 5: add_purchase – kiểm tra qty > 0 và khóa FOR SHARE trên ca
-- =====================================================================
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
  -- FIX 4: kiểm tra số lượng hợp lệ
  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;

  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then
    raise exception 'NOT_FOUND';
  end if;

  -- FIX 5: giữ khóa FOR SHARE trên ca → không thể ghi vào ca vừa đóng (FOR UPDATE trong close_shift)
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  insert into purchases (shift_id, ingredient_id, qty, is_late_entry, note, entered_by)
  values (v_shift, p_ingredient, p_qty, p_late, p_note, v_me) returning id into v_id;

  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'purchase', p_qty, v_id, v_me);

  return v_id;
end $$;

-- =====================================================================
-- FIX 4 & 5: add_waste – kiểm tra qty > 0 và khóa FOR SHARE trên ca
-- =====================================================================
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
  -- FIX 4: kiểm tra số lượng hợp lệ
  if p_qty is null or p_qty <= 0 then raise exception 'QTY_INVALID'; end if;

  select * into v_wt from waste_types where code = p_type and active and shop_id = app_shop_id();
  if not found then raise exception 'WASTE_TYPE_INVALID'; end if;
  if v_wt.requires_note and char_length(btrim(coalesce(p_note, ''))) < 5 then
    raise exception 'NOTE_REQUIRED';
  end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then
    raise exception 'NOT_FOUND';
  end if;

  -- FIX 5: giữ khóa FOR SHARE trên ca
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

-- =====================================================================
-- FIX 5: submit_stock_count – khóa FOR SHARE trên ca
-- =====================================================================
create or replace function submit_stock_count(
  p_ingredient uuid,
  p_kind       text,
  p_qty        integer
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me    uuid := _require_staff();
  v_shift uuid := _open_shift_id();
  v_id    uuid;
begin
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then
    raise exception 'NOT_FOUND';
  end if;

  -- FIX 5: giữ khóa FOR SHARE trên ca → không ghi được vào ca đã đóng
  perform 1 from shifts where id = v_shift and status = 'open' for share;
  if not found then raise exception 'NO_OPEN_SHIFT'; end if;

  insert into stock_counts (shift_id, ingredient_id, kind, counted_qty, counted_by)
  values (v_shift, p_ingredient, p_kind, p_qty, v_me) returning id into v_id;
  return v_id;
end $$;

-- =====================================================================
-- Cấp quyền cho các hàm vừa sửa (signature không đổi → grant lại an toàn)
-- =====================================================================
revoke all on function
  add_bill_line(uuid, uuid, integer),
  void_bill_line(uuid, text),
  pay_bill(uuid, text),
  add_purchase(uuid, integer, boolean, text),
  add_waste(uuid, integer, text, text),
  submit_stock_count(uuid, text, integer)
from public, anon;

grant execute on function
  add_bill_line(uuid, uuid, integer),
  void_bill_line(uuid, text),
  pay_bill(uuid, text),
  add_purchase(uuid, integer, boolean, text),
  add_waste(uuid, integer, text, text),
  submit_stock_count(uuid, text, integer)
to authenticated;
