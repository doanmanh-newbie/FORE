-- Fore · 03_read_apis.sql
-- Grouped install module. Apply after the previous numbered module.
-- Generated from the former ordered SQL sources; preserve source order within this file.

-- >>> 010_current_shift.sql
-- =====================================================================
-- Fore · 010_current_shift.sql · Xem ca đang mở (cho MỌI nhân viên)
-- Cả quán chỉ có tối đa 1 ca mở. Người đến sau cần biết "ca đang mở, ai mở, lúc nào,
-- có phải mình mở không, còn mấy bill đang mở" để bấm "Vào ca" thay vì "Mở ca".
-- Nhân viên không đọc được bảng staff nên cần hàm này. Hàm KHÔNG trả số tiền đầu ca
-- và không trả doanh thu (nhân viên không cần thấy).
-- Chạy SAU 009. Gọi từ app: supabase.rpc('current_shift'). Không có ca mở thì trả 0 dòng.
-- Chạy lại nhiều lần được (drop trước khi tạo, vì đổi số cột trả về).
-- =====================================================================

drop function if exists current_shift();

create function current_shift()
returns table (
  shift_id        uuid,
  opened_by_name  text,
  opened_at       timestamptz,   -- giờ máy chủ
  opened_by_me    boolean,       -- người gọi chính là người mở ca
  open_bills      integer        -- số bill đang mở trong ca (trước khi đóng ca phải xử lý hết)
)
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff();   -- NOT_STAFF nếu không phải nhân viên đang hoạt động
begin
  return query
    select s.id,
           st.full_name,
           s.opened_at,
           s.opened_by = v_me,
           (select count(*)::integer from bills b where b.shift_id = s.id and b.status = 'open')
      from shifts s
      join staff st on st.id = s.opened_by
     where s.status = 'open' and s.shop_id = app_shop_id();
end $$;

revoke all on function current_shift() from public, anon;
grant execute on function current_shift() to authenticated;


-- >>> 011_app_read_api.sql
-- =====================================================================
-- Fore · 011_app_read_api.sql · API đọc cho app nhiều quán
-- Chạy SAU 010_current_shift.sql, MỘT lần trong SQL Editor. Chạy lại cũng an toàn.
--
-- Vì sao cần: các màn hình thiết kế (bản đồ bàn, đơn mang đi, đóng ca) cần dữ liệu mà bảng gốc không trả
-- trực tiếp hoặc trả không an toàn cho nhân viên:
--   · tên quán theo quán đang chọn                               -> shop_info()
--   · "Ca của An, mở lúc 8:02" (RLS chỉ cho nhân viên thấy tên mình) -> current_shift()  (KHÔNG trả tiền)
--   · số phần đang gọi trên từng bàn                            -> table_map()
--   · danh sách đơn mang đi chưa xong, cũ nhất ở trên           -> takeaway_orders()
--   · danh sách việc trước khi đóng ca (đếm mù: chỉ trả SỐ LƯỢNG, không trả số đo) -> shift_close_status()
--   · thực đơn, chi tiết bill, phiếu kiểm kê, danh mục nhập/hao hụt -> menu_for_sale(), bill_detail(), count_sheet(), ...
-- Mọi hàm đọc là security definer: app không phụ thuộc quyền đọc bảng, nên sau này siết quyền đọc của nhân viên
-- (đợt rà soát A1/A2) cũng không làm app hỏng. Không hàm nào trả công thức, tồn kho, ngưỡng cảnh báo hay tiền két.
--
-- Luồng tạo/chọn quán đã có trong 008_staff_setup.sql; migration này chỉ thêm API đọc cho app.
-- =====================================================================

-- ---------- Sắp xếp khu và bàn ----------
alter table areas         add column if not exists sort_order integer not null default 0;
alter table dining_tables add column if not exists sort_order integer not null default 0;

-- Hồ sơ quán theo quán đang chọn; giữ nguyên mô hình nhiều quán của dự án.
create or replace function shop_info()
returns table (shop_name text, shop_type text, serving_label text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query select sh.name, 'drink'::text, 'phần'::text from shops sh where sh.id = app_shop_id();
end $$;
-- Việc còn thiếu trước khi đóng ca. Chỉ trả SỐ LƯỢNG; không lộ nguyên liệu nào đã đếm bao nhiêu.
create or replace function shift_close_status()
returns table (open_bills integer, missing_counts integer)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  v_shift := _open_shift_id();
  return query select
    (select count(*)::integer from bills b where b.shift_id = v_shift and b.status = 'open'),
    (select count(*)::integer from ingredients i
      where i.active and i.shop_id = app_shop_id() and not i.weekly_check
        and not exists (select 1 from stock_counts c
                         where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = 'close'));
end $$;

-- Bản đồ bàn: mỗi bàn đang dùng được một bill (nếu có) kèm tổng số phần đang gọi.
create or replace function table_map()
returns table (area_id uuid, area_name text, table_id uuid, table_name text,
               bill_id uuid, bill_no bigint, portions integer, guests integer, bill_opened_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select a.id, a.name, t.id, t.name, b.id, b.bill_no, coalesce(l.portions, 0)::integer, b.guests, b.opened_at
      from dining_tables t
      join areas a on a.id = t.area_id
      left join bills b on b.table_id = t.id and b.status = 'open'
      left join lateral (select sum(bl.qty) as portions from bill_lines bl
                          where bl.bill_id = b.id and bl.voided_at is null) l on true
     where t.active and a.active and t.shop_id = app_shop_id() and a.shop_id = app_shop_id()
     order by a.sort_order, a.name, t.sort_order,
              nullif(left(regexp_replace(t.name, '\D', '', 'g'), 9), '')::integer nulls last, t.name;
end $$;

-- Đơn mang đi của ca đang mở mà chưa làm xong (đã thu tiền hay chưa đều hiện). Cũ nhất ở trên.
create or replace function takeaway_orders()
returns table (bill_id uuid, bill_no bigint, status text, opened_at timestamptz, portions integer, items text)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  select s.id into v_shift from shifts s where s.status = 'open' and s.shop_id = app_shop_id();
  return query
    select b.id, b.bill_no, b.status, b.opened_at,
           coalesce((select sum(bl.qty) from bill_lines bl where bl.bill_id = b.id and bl.voided_at is null), 0)::integer,
           coalesce((select string_agg(x.name, ', ' order by x.first_at)
                       from (select mi.name, min(bl.created_at) as first_at
                               from bill_lines bl
                               join menu_sizes ms on ms.id = bl.size_id
                               join menu_items mi on mi.id = ms.item_id
                              where bl.bill_id = b.id and bl.voided_at is null
                              group by mi.name) x), '')
      from bills b
     where b.shop_id = app_shop_id() and b.shift_id = v_shift and b.bill_type = 'take_away'
       and b.prep_done_at is null and b.status <> 'cancelled'
     order by b.opened_at, b.bill_no;
end $$;

-- Thực đơn đang bán (món và size đều đang bật). Không có công thức.
create or replace function menu_for_sale()
returns table (item_id uuid, item_name text, group_name text, size_id uuid, size_name text, price integer)
language plpgsql volatile security definer set search_path = public as $$
begin
  perform _require_staff();
  perform _menu_apply_due();     -- giá hẹn tới giờ thì áp dụng
  return query
    select mi.id, mi.name, mi.group_name, ms.id, ms.size_name, ms.price
      from menu_items mi join menu_sizes ms on ms.item_id = mi.id
      left join menu_categories mc on mc.shop_id = mi.shop_id and lower(btrim(mc.name)) = lower(btrim(mi.group_name))
     where mi.active and not mi.is_draft and ms.active and mi.shop_id = app_shop_id() and ms.shop_id = app_shop_id()
     order by coalesce(mc.sort_order, 9999), mi.group_name nulls last, mi.name, ms.price, ms.size_name;
end $$;

-- Chi tiết một bill (màn gọi món / thanh toán). Số tiền tính ở database, app chỉ hiển thị.
create or replace function bill_detail(p_bill uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_bill record; v_lines jsonb; v_sub bigint; v_payable bigint;
begin
  perform _require_staff();
  select b.id, b.bill_no, b.status, b.bill_type, b.table_id, b.guests, b.opened_at, b.discount, b.discount_reason,
         b.total_amount, b.payment_method, b.prep_done_at, t.name as table_name, a.name as area_name
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
    'prep_done', v_bill.prep_done_at is not null,
    'lines', v_lines, 'subtotal', v_sub, 'payable', v_payable);
end $$;

-- Phiếu kiểm kê: danh sách nguyên liệu cần đếm. ĐẾM MÙ: chỉ có cờ "đã đếm", KHÔNG có số đã nhập, số dự kiến hay tồn.
create or replace function count_sheet(p_kind text)
returns table (ingredient_id uuid, name text, unit text, importance text, weekly_check boolean, group_name text, counted boolean)
language plpgsql stable security definer set search_path = public as $$
declare v_shift uuid;
begin
  perform _require_staff();
  if p_kind is null or p_kind not in ('open', 'close') then raise exception 'KIND_INVALID'; end if;
  v_shift := _open_shift_id();
  return query
    select i.id, i.name, i.unit, i.importance, i.weekly_check, i.group_name,
           exists (select 1 from stock_counts c
                    where c.shift_id = v_shift and c.ingredient_id = i.id and c.kind = p_kind)
      from ingredients i
     where i.active and i.shop_id = app_shop_id()
     order by (i.importance = 'important') desc, i.weekly_check, i.group_name nulls last, i.name;
end $$;

-- Danh mục cho phiếu nhập hàng / ghi hao hụt.
create or replace function ingredient_list()
returns table (ingredient_id uuid, name text, unit text, importance text, group_name text)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select i.id, i.name, i.unit, i.importance, i.group_name
      from ingredients i where i.active and i.shop_id = app_shop_id()
     order by i.group_name nulls last, i.name;
end $$;

create or replace function waste_type_list()
returns table (code text, label_vi text, requires_note boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_staff();
  return query
    select w.code, w.label_vi, w.requires_note from waste_types w where w.active and w.shop_id = app_shop_id() order by w.sort_order, w.label_vi;
end $$;

-- Các truy vấn có SECURITY DEFINER đều lọc theo quán đang chọn.
revoke all on function shop_info(), shift_close_status(), table_map(), takeaway_orders(),
  menu_for_sale(), bill_detail(uuid), count_sheet(text), ingredient_list(), waste_type_list()
  from public, anon;
grant execute on function shop_info(), shift_close_status(), table_map(), takeaway_orders(),
  menu_for_sale(), bill_detail(uuid), count_sheet(text), ingredient_list(), waste_type_list()
  to authenticated;


-- >>> 012_owner_dashboard.sql
-- =====================================================================

-- Ngưỡng tồn thấp là dữ liệu cấu hình mới; thêm an toàn cho project đã cài 001–011.
alter table ingredients
  add column if not exists min_stock_qty integer not null default 0
  check (min_stock_qty >= 0);
-- Fore · 012_owner_dashboard.sql · Tổng quan chỉ dành cho chủ quán
-- Chạy sau 011_app_read_api.sql. Dữ liệu doanh thu và báo cáo không được đọc
-- trực tiếp từ app: hàm kiểm tra vai trò chủ trước khi trả dữ liệu tổng hợp.
-- =====================================================================

create table if not exists owner_shift_reviews (
  shop_id    uuid not null references shops(id),
  shift_id   uuid not null,
  handled    boolean not null default false,
  note       text check (note is null or char_length(note) <= 1000),
  updated_by uuid not null,
  updated_at timestamptz not null default now(),
  primary key (shop_id, shift_id),
  foreign key (shop_id, shift_id) references shifts (shop_id, id),
  foreign key (shop_id, updated_by) references staff (shop_id, id)
);
revoke all on owner_shift_reviews from public, anon, authenticated;

create table if not exists owner_notification_reads (
  shop_id uuid not null references shops(id),
  notification_key text not null check (char_length(notification_key) <= 80),
  read_by uuid not null,
  read_at timestamptz not null default now(),
  primary key (shop_id, notification_key),
  foreign key (shop_id, read_by) references staff (shop_id, id)
);
revoke all on owner_notification_reads from public, anon, authenticated;

create or replace function set_shift_review(
  p_shift uuid, p_handled boolean, p_note text default null
) returns void
language plpgsql security definer set search_path = public as $$
declare v_shop uuid := app_shop_id(); v_me uuid := app_staff_id();
begin
  if v_shop is null or v_me is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if p_handled is null then raise exception 'REVIEW_STATUS_INVALID'; end if;
  if char_length(coalesce(btrim(p_note), '')) > 1000 then
    raise exception 'NOTE_TOO_LONG';
  end if;
  if not exists (select 1 from shifts s
                  where s.id = p_shift and s.shop_id = v_shop and s.status = 'closed') then
    raise exception 'NOT_FOUND';
  end if;
  insert into owner_shift_reviews (shop_id, shift_id, handled, note, updated_by)
  values (v_shop, p_shift, p_handled, nullif(btrim(p_note), ''), v_me)
  on conflict (shop_id, shift_id) do update
    set handled = excluded.handled,
        note = excluded.note,
        updated_by = excluded.updated_by,
        updated_at = now();
end $$;

revoke all on function set_shift_review(uuid, boolean, text) from public, anon;
grant execute on function set_shift_review(uuid, boolean, text) to authenticated;

create or replace function mark_owner_notifications_read(p_keys text[])
returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
  v_me uuid := app_staff_id();
  v_key text;
  v_count integer := 0;
  v_id uuid;
begin
  if v_shop is null or v_me is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if coalesce(cardinality(p_keys), 0) > 100 then
    raise exception 'TOO_MANY_NOTIFICATIONS';
  end if;

  foreach v_key in array coalesce(p_keys, '{}'::text[]) loop
    if v_key like 'invite:%' then
      begin v_id := substring(v_key from 8)::uuid;
      exception when invalid_text_representation then continue; end;
      if not exists (select 1 from shop_invites i
                      where i.id = v_id and i.shop_id = v_shop
                        and i.status in ('pending','accepted','declined')) then
        continue;
      end if;
    elsif v_key like 'shift:%' then
      begin v_id := substring(v_key from 7)::uuid;
      exception when invalid_text_representation then continue; end;
      if not exists (select 1 from shifts s
                      where s.id = v_id and s.shop_id = v_shop and s.status = 'closed') then
        continue;
      end if;
    else
      continue;
    end if;

    insert into owner_notification_reads(shop_id, notification_key, read_by)
    values (v_shop, v_key, v_me)
    on conflict (shop_id, notification_key) do nothing;
    if found then v_count := v_count + 1; end if;
  end loop;
  return v_count;
end $$;

revoke all on function mark_owner_notifications_read(text[]) from public, anon;
grant execute on function mark_owner_notifications_read(text[]) to authenticated;

create or replace function owner_dashboard(p_from timestamptz, p_to timestamptz)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
  v_open jsonb;
  v_reports jsonb;
  v_cash bigint;
  v_transfer bigint;
  v_yesterday bigint;
  v_bills integer;
  v_invites integer;
  v_missing integer;
  v_missing_sizes jsonb;
  v_pending integer := 0;
  v_old record;
  v_staff_active integer := 0;
  v_low_stock jsonb;
  v_notifications jsonb := '[]'::jsonb;
  v_event jsonb;
  v_key text;
  v_read boolean;
begin
  if v_shop is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if p_from is null or p_to is null or p_to <= p_from
     or p_to - p_from > interval '36 hours' then
    raise exception 'DATE_RANGE_INVALID';
  end if;

  select jsonb_build_object(
           'id', s.id,
           'opened_at', s.opened_at,
           'opened_by_name', st.full_name)
    into v_open
    from shifts s
    join staff st on st.id = s.opened_by and st.shop_id = s.shop_id
   where s.shop_id = v_shop and s.status = 'open'
   limit 1;

  if v_open is not null then
    select count(distinct b.opened_by)::integer into v_staff_active
      from bills b
     where b.shop_id = v_shop
       and b.shift_id = (v_open ->> 'id')::uuid
       and b.status <> 'cancelled';
  end if;

  select count(*)::integer,
         coalesce(sum(b.total_amount) filter (where b.payment_method = 'cash'), 0)::bigint,
         coalesce(sum(b.total_amount) filter (where b.payment_method = 'transfer'), 0)::bigint
    into v_bills, v_cash, v_transfer
    from bills b
   where b.shop_id = v_shop and b.status = 'paid'
     and b.paid_at >= p_from and b.paid_at < p_to;

  select coalesce(sum(b.total_amount), 0)::bigint into v_yesterday
    from bills b
   where b.shop_id = v_shop and b.status = 'paid'
     and b.paid_at >= p_from - interval '1 day'
     and b.paid_at < least(now(), p_to) - interval '1 day';   -- hôm qua TÍNH ĐẾN CÙNG GIỜ, để so sánh công bằng

  select count(*)::integer into v_invites
    from shop_invites i where i.shop_id = v_shop and i.status = 'pending';

  select count(*)::integer into v_missing
    from menu_sizes ms
    join menu_items mi on mi.id = ms.item_id and mi.shop_id = ms.shop_id
   where ms.shop_id = v_shop and ms.active and mi.active
     and not exists (select 1 from recipe_lines rl
                      where rl.shop_id = v_shop and rl.size_id = ms.id);

  select coalesce(jsonb_agg(ms.id order by mi.name, ms.size_name), '[]'::jsonb)
    into v_missing_sizes
    from menu_sizes ms
    join menu_items mi on mi.id = ms.item_id and mi.shop_id = ms.shop_id
   where ms.shop_id = v_shop and ms.active and mi.active
     and not exists (select 1 from recipe_lines rl
                      where rl.shop_id = v_shop and rl.size_id = ms.id);

  select coalesce(jsonb_agg(jsonb_build_object(
           'ingredient_id', i.id,
           'name', i.name,
           'unit', i.unit,
           'expected_qty', e.expected_qty,
           'minimum_qty', i.min_stock_qty)
           order by (i.importance = 'important') desc, i.name), '[]'::jsonb)
    into v_low_stock
    from ingredients i
    join v_expected_stock e on e.ingredient_id = i.id
   where i.shop_id = v_shop and i.active and i.min_stock_qty > 0
     and e.expected_qty is not null and e.expected_qty <= i.min_stock_qty;

  select coalesce(jsonb_agg(
           jsonb_build_object(
             'shift', jsonb_build_object(
               'id', recent.id,
               'status', recent.status,
               'opened_at', recent.opened_at,
               'closed_at', recent.closed_at,
               'opened_by_name', recent.opened_by_name,
               'closed_by_name', recent.closed_by_name),
             'review', jsonb_build_object(
               'handled', coalesce(recent.handled, false),
               'note', recent.note),
             'report', case when recent.status = 'closed'
                            then shift_report(recent.id)
                            else null end)
           order by recent.opened_at desc), '[]'::jsonb)
    into v_reports
    from (
      select s.id, s.status, s.opened_at, s.closed_at, st.full_name as opened_by_name,
             cl.full_name as closed_by_name, r.handled, r.note
        from shifts s
        join staff st on st.id = s.opened_by and st.shop_id = s.shop_id
        left join staff cl on cl.id = s.closed_by and cl.shop_id = s.shop_id
        left join owner_shift_reviews r on r.shop_id = s.shop_id and r.shift_id = s.id
       where s.shop_id = v_shop
       order by s.opened_at desc
       limit 3
    ) recent;

  -- Ca cần xử lý = vàng/đỏ mà chủ chưa đánh dấu đã xử lý, trong 7 ngày gần nhất.
  -- 3 ca mới nhất đã có báo cáo ở trên; chỉ tính thêm tối đa 7 ca cũ hơn để giữ tốc độ.
  select count(*)::integer into v_pending
    from jsonb_array_elements(v_reports) e
   where e -> 'shift' ->> 'status' = 'closed'
     and (e -> 'shift' ->> 'opened_at')::timestamptz >= now() - interval '7 days'
     and coalesce(e -> 'report' -> 'summary' ->> 'overall', '') in ('warn', 'alert')
     and not coalesce((e -> 'review' ->> 'handled')::boolean, false);
  for v_old in
    select s.id
      from shifts s
      left join owner_shift_reviews r on r.shop_id = s.shop_id and r.shift_id = s.id
     where s.shop_id = v_shop and s.status = 'closed'
       and s.opened_at >= now() - interval '7 days'
       and s.id not in (select (e -> 'shift' ->> 'id')::uuid from jsonb_array_elements(v_reports) e)
       and not coalesce(r.handled, false)
     order by s.opened_at desc
     limit 7
  loop
    if coalesce(shift_report(v_old.id) -> 'summary' ->> 'overall', '') in ('warn', 'alert') then
      v_pending := v_pending + 1;
    end if;
  end loop;

  select coalesce(jsonb_agg(jsonb_build_object(
           'id', 'invite:' || i.id::text,
           'kind', 'invite',
           'title', case i.status
             when 'accepted' then i.full_name || ' đã nhận lời mời'
             when 'declined' then i.full_name || ' đã từ chối lời mời'
             else 'Lời mời nhân viên đang chờ' end,
           'body', case i.status
             when 'accepted' then i.full_name || ' đã tham gia quán với vai trò nhân viên.'
             when 'declined' then 'Lời mời tham gia quán không được nhận.'
             else 'Đang chờ ' || i.full_name || ' phản hồi lời mời.' end,
           'occurred_at', coalesce(i.responded_at, i.created_at),
           'read', exists (select 1 from owner_notification_reads nr
                            where nr.shop_id = v_shop
                              and nr.notification_key = 'invite:' || i.id::text)
         ) order by coalesce(i.responded_at, i.created_at) desc), '[]'::jsonb)
    into v_notifications
    from (
      select * from shop_invites
       where shop_id = v_shop and status in ('pending','accepted','declined')
       order by coalesce(responded_at, created_at) desc limit 20
    ) i;

  for v_event in select value from jsonb_array_elements(v_reports) loop
    if coalesce(v_event -> 'report' -> 'summary' ->> 'overall', '') not in ('warn', 'alert')
       or coalesce((v_event -> 'review' ->> 'handled')::boolean, false) then
      continue;
    end if;
    v_key := 'shift:' || (v_event -> 'shift' ->> 'id');
    select exists (select 1 from owner_notification_reads nr
                    where nr.shop_id = v_shop and nr.notification_key = v_key)
      into v_read;
    v_notifications := v_notifications || jsonb_build_array(jsonb_build_object(
      'id', v_key,
      'kind', 'shift',
      'title', 'Ca vừa đóng có chênh lệch',
      'body', 'Ca của ' || coalesce(v_event -> 'shift' ->> 'opened_by_name', 'nhân viên')
             || ' cần được kiểm tra đối soát.',
      'occurred_at', v_event -> 'shift' ->> 'closed_at',
      'read', v_read));
  end loop;

  return jsonb_build_object(
    'open_shift', v_open,
    'cash_sales', v_cash,
    'transfer_sales', v_transfer,
    'yesterday_sales', v_yesterday,
    'bill_count', v_bills,
    'pending_invites', v_invites,
    'missing_recipe_count', v_missing,
    'missing_recipe_sizes', v_missing_sizes,
    'pending_review_count', v_pending,
    'active_staff_count', v_staff_active,
    'low_stock', v_low_stock,
    'notifications', v_notifications,
    'reports', v_reports);
end $$;

revoke all on function owner_dashboard(timestamptz, timestamptz) from public, anon;
grant execute on function owner_dashboard(timestamptz, timestamptz) to authenticated;

-- ---------- Danh sách ca đã đóng cho màn Đối soát (chọn ngày, lọc, tải thêm) ----------
-- p_from/p_to: khoảng ngày làm việc (tối đa 62 ngày) tính theo giờ MỞ ca.
-- p_filter: all | attention (ca vàng/đỏ) | unhandled (chủ chưa đánh dấu đã xử lý)
--           | pending (vàng/đỏ VÀ chưa xử lý: việc chủ còn phải làm).
-- p_before: con trỏ phân trang = opened_at của ca cuối trang trước.
-- Trả về { open_shift, items:[{shift, review, report}], has_more, next_before }.
create or replace function owner_shift_list(
  p_from timestamptz,
  p_to timestamptz,
  p_filter text default 'all',
  p_limit integer default 10,
  p_before timestamptz default null)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
  v_limit integer := least(greatest(coalesce(p_limit, 10), 1), 30);
  v_filter text := coalesce(p_filter, 'all');
  v_items jsonb := '[]'::jsonb;
  v_open jsonb;
  v_count integer := 0;
  v_has_more boolean := false;
  v_last timestamptz;
  v_report jsonb;
  r record;
begin
  if v_shop is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if v_filter not in ('all', 'attention', 'unhandled', 'pending') then
    raise exception 'FILTER_INVALID';
  end if;
  if p_from is null or p_to is null or p_to <= p_from
     or p_to - p_from > interval '62 days' then
    raise exception 'DATE_RANGE_INVALID';
  end if;

  select jsonb_build_object('id', s.id, 'opened_at', s.opened_at,
                            'opened_by_name', st.full_name)
    into v_open
    from shifts s
    join staff st on st.id = s.opened_by and st.shop_id = s.shop_id
   where s.shop_id = v_shop and s.status = 'open'
   limit 1;

  for r in
    select s.id, s.opened_at, s.closed_at, s.status,
           st.full_name as opened_by_name, cl.full_name as closed_by_name,
           coalesce(rv.handled, false) as handled, rv.note
      from shifts s
      join staff st on st.id = s.opened_by and st.shop_id = s.shop_id
      left join staff cl on cl.id = s.closed_by and cl.shop_id = s.shop_id
      left join owner_shift_reviews rv on rv.shop_id = s.shop_id and rv.shift_id = s.id
     where s.shop_id = v_shop and s.status = 'closed'
       and s.opened_at >= p_from and s.opened_at < p_to
       and (p_before is null or s.opened_at < p_before)
       and (v_filter not in ('unhandled', 'pending') or not coalesce(rv.handled, false))
     order by s.opened_at desc
  loop
    v_report := shift_report(r.id);
    if v_filter in ('attention', 'pending')
       and coalesce(v_report -> 'summary' ->> 'overall', '') not in ('warn', 'alert') then
      continue;
    end if;
    if v_count >= v_limit then
      v_has_more := true;
      exit;
    end if;
    v_items := v_items || jsonb_build_array(jsonb_build_object(
      'shift', jsonb_build_object(
        'id', r.id, 'status', r.status,
        'opened_at', r.opened_at, 'closed_at', r.closed_at,
        'opened_by_name', r.opened_by_name, 'closed_by_name', r.closed_by_name),
      'review', jsonb_build_object('handled', r.handled, 'note', r.note),
      'report', v_report));
    v_count := v_count + 1;
    v_last := r.opened_at;
  end loop;

  return jsonb_build_object(
    'open_shift', v_open,
    'items', v_items,
    'has_more', v_has_more,
    'next_before', v_last);
end $$;

revoke all on function owner_shift_list(timestamptz, timestamptz, text, integer, timestamptz) from public, anon;
grant execute on function owner_shift_list(timestamptz, timestamptz, text, integer, timestamptz) to authenticated;
