-- Fore · 02_operations_reconciliation.sql
-- Grouped install module. Apply after the previous numbered module.
-- Generated from the former ordered SQL sources; preserve source order within this file.

-- >>> 004_reconcile.sql
-- =====================================================================
-- Fore · 004_reconcile.sql · Hàm đối soát (trái tim của Fore)
--   Thực dùng   = Tồn đầu + Nhập − Tồn cuối
--   Lý thuyết   = Σ (số bán × định lượng công thức)      (lấy từ sổ kho lúc bán)
--   Chênh lệch  = Thực dùng − Lý thuyết
--   Sau điều chỉnh = Chênh lệch − Hao hụt có lý do
--   Quy ra ly   = Chênh lệch điều chỉnh ÷ (lượng trung bình mỗi ly có nguyên liệu đó)
--   Quy ra tiền = số ly × giá bán trung bình (ƯỚC TÍNH)
-- Chỉ chủ quán gọi được. Chạy SAU 003_actions.sql.
-- Ngưỡng cảnh báo là CON SỐ trong app_settings (important_warn_pct, important_alert_pct, normal_warn_pct,
-- normal_alert_pct); mỗi nguyên liệu có thể đặt ngưỡng riêng (ingredients.warn_pct / alert_pct) thì ưu tiên.
-- Giá trị mặc định (TẠM, phải chỉnh theo quán thật): quan trọng 3% / 5%, thường 10% / 15%.
-- Giảm báo nhầm: nguyên liệu có min_abs_qty > 0 chỉ bị cảnh báo khi lệch TUYỆT ĐỐI >= min_abs_qty
-- (đơn vị gốc của nguyên liệu) VÀ lệch % vượt ngưỡng. Mặc định 0 = tắt.
-- =====================================================================

create or replace function reconcile_shift(p_shift uuid)
returns table (
  ingredient_id     uuid,
  ingredient_name   text,
  unit              text,
  importance        text,
  opening_qty       integer,
  purchased_qty     integer,
  closing_qty       integer,
  actual_used       integer,
  theoretical_used  integer,
  variance          integer,
  variance_pct      numeric,
  justified_waste   integer,
  adjusted_variance integer,
  adjusted_pct      numeric,
  equiv_cups        numeric,
  equiv_revenue     integer,
  status            text          -- ok | warn | alert | no_data
)
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  -- Chỉ chủ CỦA QUÁN CHỨA CA NÀY (hoặc quản trị viên database khi chạy kiểm thử trong SQL Editor)
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;

  return query
  with sh as (select s.id, s.opened_at from shifts s where s.id = p_shift),
  prev as (
    select s.id from shifts s, sh
     where s.shop_id = v_shop and s.status = 'closed' and s.id <> sh.id and s.closed_at <= sh.opened_at
     order by s.closed_at desc limit 1
  ),
  ing as (select i.* from ingredients i where i.active and i.shop_id = v_shop),
  op as (   -- tồn đầu: lần đếm 'open' của ca này, nếu không có thì lấy đếm cuối ca trước
    select i.id as iid,
           coalesce(
             (select c.counted_qty from stock_counts c
               where c.shift_id = p_shift and c.ingredient_id = i.id and c.kind = 'open'
               order by c.counted_at desc limit 1),
             (select c.counted_qty from stock_counts c
               where c.shift_id = (select id from prev) and c.ingredient_id = i.id and c.kind = 'close'
               order by c.counted_at desc limit 1)) as q
      from ing i
  ),
  cl as (
    select i.id as iid,
           (select c.counted_qty from stock_counts c
             where c.shift_id = p_shift and c.ingredient_id = i.id and c.kind = 'close'
             order by c.counted_at desc limit 1) as q
      from ing i
  ),
  pu as (select l.ingredient_id as iid, sum(l.qty_delta) as q from stock_ledger l
          where l.shift_id = p_shift and l.kind = 'purchase' group by 1),
  th as (select l.ingredient_id as iid, -sum(l.qty_delta) as q from stock_ledger l
          where l.shift_id = p_shift and l.kind in ('sale','void_sale') group by 1),
  wa as (select l.ingredient_id as iid, -sum(l.qty_delta) as q from stock_ledger l
          where l.shift_id = p_shift and l.kind = 'waste' group by 1),
  cups as (  -- số ly có chứa nguyên liệu và doanh thu của chúng (để quy ra ly/tiền)
    select r.ingredient_id as iid, sum(bl.qty) as cups, sum(bl.qty::bigint * bl.unit_price) as revenue
      from bill_lines bl
      join bills b on b.id = bl.bill_id and b.status = 'paid' and b.shift_id = p_shift
      cross join lateral _recipe_at(bl.size_id, b.paid_at) r   -- công thức có hiệu lực LÚC bán
     where bl.voided_at is null
     group by r.ingredient_id
  ),
  base as (
    select i.id, i.name, i.unit, i.importance,
           op.q as opening, coalesce(pu.q, 0) as purchased, cl.q as closing,
           coalesce(th.q, 0) as theo, coalesce(wa.q, 0) as waste,
           cups.cups, cups.revenue,
           i.min_abs_qty as min_abs,
           coalesce(i.warn_pct,  _setting(i.importance || '_warn_pct',  case i.importance when 'important' then 3 else 10 end, v_shop)) as warn_at,
           coalesce(i.alert_pct, _setting(i.importance || '_alert_pct', case i.importance when 'important' then 5 else 15 end, v_shop)) as alert_at
      from ing i
      join op on op.iid = i.id
      join cl on cl.iid = i.id
      left join pu on pu.iid = i.id
      left join th on th.iid = i.id
      left join wa on wa.iid = i.id
      left join cups on cups.iid = i.id
     where not i.weekly_check or cl.q is not null    -- loại kiểm theo tuần: chỉ hiện khi có đếm
  ),
  calc as (
    select b.*,
           case when b.opening is not null and b.closing is not null
                then b.opening + b.purchased - b.closing end as actual
      from base b
  ),
  calc2 as (
    select c.*,
           c.actual - c.theo as var,
           c.actual - c.theo - c.waste as adj
      from calc c
  )
  select c.id, c.name, c.unit, c.importance,
         c.opening::integer, c.purchased::integer, c.closing::integer,
         c.actual::integer, c.theo::integer,
         c.var::integer,
         round(c.var * 100.0 / nullif(c.theo, 0), 1),
         c.waste::integer,
         c.adj::integer,
         round(c.adj * 100.0 / nullif(c.theo, 0), 1),
         round(c.adj / nullif(c.theo::numeric / nullif(c.cups, 0), 0), 1),
         round(c.adj / nullif(c.theo::numeric / nullif(c.cups, 0), 0) * (c.revenue::numeric / nullif(c.cups, 0)))::integer,
         case
           when c.actual is null then 'no_data'
           when abs(c.adj) < c.min_abs then 'ok'                      -- lệch quá nhỏ về số lượng: bỏ qua (min_abs_qty)
           when c.theo = 0 then case when c.adj <= 0 then 'ok' else 'warn' end   -- không bán gì mà vẫn hao
           when abs(c.adj * 100.0 / c.theo) >= c.alert_at then 'alert'
           when abs(c.adj * 100.0 / c.theo) >= c.warn_at  then 'warn'
           else 'ok'
         end
    from calc2 c
   order by (c.importance = 'important') desc, abs(coalesce(c.adj, 0)) desc;
end $$;

revoke all on function reconcile_shift(uuid) from public, anon, authenticated;
grant execute on function reconcile_shift(uuid) to authenticated;

-- ---------- Tồn dự kiến và "còn pha được" (CHỈ CHỦ xem được nhờ RLS) ----------
create or replace view v_expected_stock with (security_invoker = true) as
select i.id as ingredient_id, i.name, i.unit,
       c.counted_qty + coalesce((select sum(l.qty_delta) from stock_ledger l
                                  where l.ingredient_id = i.id and l.at > c.counted_at), 0) as expected_qty,
       c.counted_at as last_count_at
  from ingredients i
  left join lateral (select counted_qty, counted_at from stock_counts
                      where ingredient_id = i.id order by counted_at desc limit 1) c on true
 where i.active;

create or replace view v_can_make with (security_invoker = true) as
select ms.id as size_id, mi.name as item_name, ms.size_name,
       min(floor(e.expected_qty::numeric / r.qty))::integer as cups_left
  from menu_sizes ms
  join menu_items mi on mi.id = ms.item_id
  join recipe_lines r on r.size_id = ms.id
  join v_expected_stock e on e.ingredient_id = r.ingredient_id
 where ms.active and mi.active and e.expected_qty is not null
 group by ms.id, mi.name, ms.size_name;

grant select on v_expected_stock, v_can_make to authenticated;

-- Món đã bán nhưng chưa có công thức (sẽ làm đối soát bị thiếu): nhắc chủ quán
create or replace view v_items_without_recipe with (security_invoker = true) as
select ms.id as size_id, mi.name as item_name, ms.size_name
  from menu_sizes ms join menu_items mi on mi.id = ms.item_id
 where ms.active and mi.active
   and not exists (select 1 from recipe_lines r where r.size_id = ms.id);
grant select on v_items_without_recipe to authenticated;


-- >>> 005_cash_reconcile.sql
-- =====================================================================
-- Fore · 005_cash_reconcile.sql · Đối soát TIỀN MẶT
--
--   Tiền mặt đáng ra có = tiền đầu ca
--                         + tiền mặt từ bill đã thanh toán (không tính chuyển khoản, không tính bill đã hủy)
--                         + tiền bỏ thêm vào két (hướng 'in': đổi tiền lẻ, chủ nạp...)
--                         − tiền lấy ra khỏi két (hướng 'out': chi mua đá, trả tiền hàng, chủ rút...)
--   Chênh lệch tiền      = tiền đếm cuối ca − tiền đáng ra có   (âm = THIẾU, dương = THỪA)
--
-- Nguyên tắc thiết kế (đã bàn với chủ dự án):
--   * Chỉ có 2 HƯỚNG (in/out): công thức chỉ cần biết cộng hay trừ. Chi tiết (mua đá, chủ rút...) nằm
--     trong GHI CHÚ do người nhập viết. Không cần PIN, nhưng MỌI khoản đều để lại dấu vết (ai nhập,
--     lúc nào, ghi chú) và không sửa/xóa được. Chủ đọc danh sách ghi chú để biết từng khoản.
--   * Hệ thống KHÔNG kiểm chứng được sự thật bên ngoài (đá thật tốn bao nhiêu, tiền chuyển khoản
--     có về tài khoản không). Đó là giới hạn đã biết: hệ thống chỉ hiện số để chủ so với
--     sao kê ngân hàng/loa báo tiền.
--   * Bán KHÔNG lên bill thì tiền không vào két nên không làm lệch két. Phần đó do đối soát
--     nguyên liệu (reconcile_shift) phát hiện. Hai đối soát đọc cùng nhau mới thấy "kiểu" thất thoát.
--
-- Chạy SAU 004_reconcile.sql.
-- =====================================================================

-- (Các ngưỡng tiền mặt cash_warn_vnd, cash_alert_vnd, opening_diff_warn_vnd nằm trong app_settings, tạo ở 001.)

-- ---------- Thu/chi tiền mặt trong ca ----------
-- Số tiền LUÔN DƯƠNG; cột direction quyết định cộng hay trừ (tránh nhầm dấu khi tính công thức).
--   out = lấy ra khỏi két (−): mua đá, trả tiền hàng, chủ rút...  -> BẮT BUỘC ghi chú (từ 3 ký tự)
--   in  = bỏ thêm vào két (+): đổi tiền lẻ, chủ nạp...             -> ghi chú không bắt buộc
create table cash_movements (
  id          uuid primary key default gen_random_uuid(),
  shop_id     uuid not null default app_shop_id() references shops(id),
  shift_id    uuid not null references shifts(id),
  direction   text not null check (direction in ('in', 'out')),
  amount      integer not null check (amount > 0),
  note        text,
  entered_by  uuid not null references staff(id),
  entered_at  timestamptz not null default now(),
  constraint note_required_when_taking_out
    check (direction = 'in' or char_length(btrim(coalesce(note, ''))) >= 3),
  constraint cash_movements_shift_same_shop_fk
    foreign key (shop_id, shift_id) references shifts (shop_id, id),
  constraint cash_movements_entered_by_same_shop_fk
    foreign key (shop_id, entered_by) references staff (shop_id, id)
);
create index cash_movements_shift on cash_movements (shift_id);
create trigger no_change_cash_movements before update or delete on cash_movements
  for each row execute function prevent_mutation();                    -- chỉ thêm, không sửa/xóa
alter table cash_movements enable row level security;
grant select on cash_movements to authenticated;
create policy cash_movements_owner_read on cash_movements for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Nhân viên hoặc chủ đều ghi được (không cần PIN). Chỉ ghi vào ca đang mở.
-- Việc ghi không bắt buộc (ca không có thu/chi thì không có dòng nào).
create or replace function add_cash_movement(p_direction text, p_amount integer, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  if p_direction is null or p_direction not in ('in', 'out') then raise exception 'DIRECTION_INVALID'; end if;
  if p_amount is null or p_amount <= 0 then raise exception 'AMOUNT_INVALID'; end if;
  if p_direction = 'out' and char_length(btrim(coalesce(p_note, ''))) < 3 then
    raise exception 'NOTE_REQUIRED';        -- lấy tiền ra thì phải ghi chú
  end if;
  insert into cash_movements (shift_id, direction, amount, note, entered_by)
  values (v_shift, p_direction, p_amount, nullif(btrim(p_note), ''), v_me) returning id into v_id;
  perform _audit('add_cash_movement', 'cash_movements', v_id,
                 jsonb_build_object('direction', p_direction, 'amount', p_amount, 'note', nullif(btrim(p_note), '')));
  return v_id;
end $$;

-- Danh sách các khoản thu/chi (chỉ chủ đọc được vì bảng gốc chặn bằng RLS), kèm tên người nhập.
create or replace view v_cash_movements with (security_invoker = true) as
select m.shift_id, m.entered_at, m.direction, m.amount, m.note, s.full_name as entered_by_name
  from cash_movements m
  join staff s on s.id = m.entered_by;

-- ---------- Hàm đối soát tiền mặt (chỉ chủ) ----------
create or replace function reconcile_cash(p_shift uuid)
returns table (
  shift_id                    uuid,
  opened_at                   timestamptz,
  closed_at                   timestamptz,
  opening_cash                integer,
  prev_closing_cash           integer,      -- tiền cuối ca trước (null nếu là ca đầu tiên)
  opening_diff                integer,      -- tiền đầu ca − tiền cuối ca trước (khác 0 = đáng chú ý)
  cash_sales                  integer,
  transfer_sales              integer,      -- để chủ so với loa/app ngân hàng
  cash_in                     integer,
  cash_out                    integer,
  expected_cash               integer,
  closing_cash                integer,
  variance                    integer,      -- đếm − đáng ra có (âm = thiếu)
  variance_pct                numeric,      -- so với doanh thu tiền mặt
  cancelled_after_paid_count  integer,      -- bill đã thu rồi hủy trong ca (chủ nên xem)
  cancelled_after_paid_amount integer,
  status                      text          -- ok | warn | alert | no_data
)
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  -- Chỉ chủ CỦA QUÁN CHỨA CA NÀY (hoặc quản trị viên database khi chạy kiểm thử trong SQL Editor)
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;

  return query
  with sh as (select s.* from shifts s where s.id = p_shift),
  prev as (   -- ca đã đóng gần nhất trước ca này
    select p.closing_cash
      from shifts p, sh
     where p.shop_id = v_shop and p.status = 'closed' and p.id <> sh.id and p.closed_at <= sh.opened_at and p.closing_cash is not null
     order by p.closed_at desc limit 1
  ),
  sales as (
    select coalesce(sum(b.total_amount) filter (where b.status = 'paid' and b.payment_method = 'cash'), 0)     as cash,
           coalesce(sum(b.total_amount) filter (where b.status = 'paid' and b.payment_method = 'transfer'), 0) as transfer,
           count(*)  filter (where b.status = 'cancelled' and b.paid_at is not null)                           as canc_n,
           coalesce(sum(b.total_amount) filter (where b.status = 'cancelled' and b.paid_at is not null), 0)    as canc_amt
      from bills b where b.shift_id = p_shift
  ),
  mv as (
    select coalesce(sum(m.amount) filter (where m.direction = 'in'),  0) as cin,
           coalesce(sum(m.amount) filter (where m.direction = 'out'), 0) as cout
      from cash_movements m where m.shift_id = p_shift
  ),
  base as (
    select sh.id, sh.opened_at, sh.closed_at, sh.opening_cash, sh.closing_cash,
           (select pr.closing_cash from prev pr) as prev_close,
           sales.cash, sales.transfer, sales.canc_n, sales.canc_amt,
           mv.cin, mv.cout,
           sh.opening_cash + sales.cash + mv.cin - mv.cout as expected,
           _setting('cash_warn_vnd',  20000, v_shop) as warn_at,
           _setting('cash_alert_vnd', 50000, v_shop) as alert_at
      from sh, sales, mv
  )
  select b.id, b.opened_at, b.closed_at, b.opening_cash,
         b.prev_close,
         (b.opening_cash - b.prev_close)::integer,
         b.cash::integer, b.transfer::integer, b.cin::integer, b.cout::integer,
         b.expected::integer, b.closing_cash,
         (b.closing_cash - b.expected)::integer,
         round((b.closing_cash - b.expected) * 100.0 / nullif(b.cash, 0), 1),
         b.canc_n::integer, b.canc_amt::integer,
         case when b.closing_cash is null then 'no_data'
              when abs(b.closing_cash - b.expected) >= b.alert_at then 'alert'
              when abs(b.closing_cash - b.expected) >= b.warn_at  then 'warn'
              else 'ok' end
    from base b;
end $$;

-- ---------- Quyền chạy hàm ----------
revoke all on function add_cash_movement(text, integer, text), reconcile_cash(uuid) from public, anon;
grant execute on function add_cash_movement(text, integer, text), reconcile_cash(uuid) to authenticated;
grant select on v_cash_movements to authenticated;


-- >>> 006_waste_report.sql
-- =====================================================================
-- Fore · 006_waste_report.sql · Báo cáo hao hụt cho chủ (CHỈ CẢNH BÁO, không chặn)
--
-- Vì sao cần: hao hụt "có lý do" được TRỪ khỏi chênh lệch đối soát (cột justified_waste ở
-- reconcile_shift). Nếu không có báo cáo này, có thể ghi "đổ bỏ" để che việc lấy trộm.
-- Báo cáo cho chủ thấy: hao hụt từng nguyên liệu theo từng LOẠI, chiếm bao nhiêu % so với
-- lượng dùng lý thuyết, và cờ cảnh báo nếu vượt waste_warn_pct (con số trong app_settings).
-- Hệ thống không quyết định thay chủ: chỉ hiện số và cờ để chủ tự xem lại.
--
-- Chạy SAU 005_cash_reconcile.sql.
-- =====================================================================

-- Chi tiết từng lần ghi hao hụt, kèm tên người nhập (chủ đọc được nhờ RLS của bảng waste_logs)
create or replace view v_waste_detail with (security_invoker = true) as
select w.shift_id, w.entered_at, i.name as ingredient_name, i.unit,
       w.reason_type, t.label_vi as reason_label, w.qty, w.reason as note,
       s.full_name as entered_by_name
  from waste_logs w
  join ingredients i on i.id = w.ingredient_id
  join waste_types t on t.code = w.reason_type and t.shop_id = w.shop_id
  left join staff s on s.id = w.entered_by;
grant select on v_waste_detail to authenticated;

-- Báo cáo theo ca: mỗi dòng là (nguyên liệu, loại hao hụt)
--   waste_pct_total = TỔNG hao hụt của nguyên liệu đó (mọi loại) ÷ lượng dùng lý thuyết × 100
--   flag = 'warn' nếu waste_pct_total >= waste_warn_pct, hoặc không bán gì mà vẫn có hao hụt; còn lại 'ok'
create or replace function waste_report(p_shift uuid)
returns table (
  ingredient_id     uuid,
  ingredient_name   text,
  unit              text,
  reason_type       text,
  reason_label      text,
  entries           integer,   -- số lần ghi
  qty               integer,   -- tổng lượng của loại này
  waste_total       integer,   -- tổng hao hụt của nguyên liệu (mọi loại)
  theoretical_used  integer,
  waste_pct_total   numeric,
  flag              text       -- ok | warn
)
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_warn int;
begin
  -- Chỉ chủ CỦA QUÁN CHỨA CA NÀY (hoặc quản trị viên database khi chạy kiểm thử trong SQL Editor)
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;
  v_warn := _setting('waste_warn_pct', 10, v_shop);

  return query
  with w as (
    -- Lượng lấy từ SỔ KHO (gồm cả dòng điều chỉnh của 007) để khớp với reconcile_shift
    select wl.ingredient_id as iid, wl.reason_type as rtype,
           count(distinct wl.id) as n, -sum(sl.qty_delta) as q
      from waste_logs wl
      join stock_ledger sl on sl.kind = 'waste' and sl.ref_id = wl.id
     where wl.shift_id = p_shift
     group by 1, 2
  ),
  tot as (select w.iid, sum(w.q) as q from w group by 1),
  th as (
    select s.ingredient_id as iid, -sum(s.qty_delta) as q
      from stock_ledger s
     where s.shift_id = p_shift and s.kind in ('sale', 'void_sale') group by 1
  )
  select i.id, i.name, i.unit, w.rtype, t.label_vi,
         w.n::integer, w.q::integer, tot.q::integer, coalesce(th.q, 0)::integer,
         round(tot.q * 100.0 / nullif(th.q, 0), 1),
         case when coalesce(th.q, 0) = 0 then 'warn'
              when tot.q * 100.0 / th.q >= v_warn then 'warn'
              else 'ok' end
    from w
    join tot on tot.iid = w.iid
    join ingredients i on i.id = w.iid
    join waste_types t on t.code = w.rtype and t.shop_id = v_shop
    left join th on th.iid = w.iid
   order by (case when coalesce(th.q, 0) = 0 or tot.q * 100.0 / th.q >= v_warn then 0 else 1 end),
            i.name, t.sort_order;
end $$;

revoke all on function waste_report(uuid) from public, anon;
grant execute on function waste_report(uuid) to authenticated;


-- >>> 007_corrections.sql
-- =====================================================================
-- Fore · 007_corrections.sql · Sửa nhập nhầm bằng dòng ĐIỀU CHỈNH (không sửa dòng cũ)
--   - Nhập kho hoặc hao hụt sai số: chủ ghi thêm một dòng điều chỉnh có lý do, dòng gốc vẫn còn.
--   - Kiểm kê sai: nhân viên đếm lại (dòng mới nhất được dùng), không cần điều chỉnh.
--   - Hàm đối soát (004) tự cộng các dòng điều chỉnh vì chúng nằm trong sổ kho.
-- Chạy SAU 006_waste_report.sql.
-- =====================================================================

alter table stock_ledger
  add column is_correction boolean not null default false,
  add column note text;

-- Sửa số lượng của một phiếu nhập: chỉ chủ
create or replace function correct_purchase(p_purchase uuid, p_new_qty integer, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_shift uuid; v_ing uuid; v_cur integer; v_delta integer;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  if p_new_qty < 0 then raise exception 'QTY_INVALID'; end if;
  select shift_id, ingredient_id into v_shift, v_ing from purchases where id = p_purchase and shop_id = app_shop_id() for update;
  if v_shift is null then   -- dòng phiếu nhập PN: lấy ca từ dòng sổ kho gốc
    select sl.shift_id, sl.ingredient_id into v_shift, v_ing
      from stock_ledger sl join purchase_order_lines pl on pl.id = sl.ref_id
     where sl.ref_id = p_purchase and sl.kind = 'purchase' and not sl.is_correction and sl.shop_id = app_shop_id()
       for update of pl;   -- hai máy sửa cùng lúc thì máy sau chờ, không cộng chênh lệch hai lần
  end if;
  if v_shift is null then raise exception 'NOT_FOUND'; end if;

  select coalesce(sum(qty_delta), 0) into v_cur from stock_ledger where kind = 'purchase' and ref_id = p_purchase;
  v_delta := p_new_qty - v_cur;
  if v_delta = 0 then raise exception 'NO_CHANGE'; end if;

  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, is_correction, note)
  values (v_shift, v_ing, 'purchase', v_delta, p_purchase, v_me, true, p_reason);
  perform _audit('correct_purchase', 'purchases', p_purchase,
                 jsonb_build_object('from', v_cur, 'to', p_new_qty, 'reason', p_reason));
end $$;

-- Sửa số lượng của một dòng hao hụt: chỉ chủ
create or replace function correct_waste(p_waste uuid, p_new_qty integer, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_shift uuid; v_ing uuid; v_cur integer; v_delta integer;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  if p_new_qty < 0 then raise exception 'QTY_INVALID'; end if;
  select shift_id, ingredient_id into v_shift, v_ing from waste_logs where id = p_waste and shop_id = app_shop_id() for update;
  if v_shift is null then raise exception 'NOT_FOUND'; end if;

  select coalesce(-sum(qty_delta), 0) into v_cur from stock_ledger where kind = 'waste' and ref_id = p_waste;
  v_delta := v_cur - p_new_qty;          -- dòng sổ kho của hao hụt mang dấu âm
  if v_delta = 0 then raise exception 'NO_CHANGE'; end if;

  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, is_correction, note)
  values (v_shift, v_ing, 'waste', v_delta, p_waste, v_me, true, p_reason);
  perform _audit('correct_waste', 'waste_logs', p_waste,
                 jsonb_build_object('from', v_cur, 'to', p_new_qty, 'reason', p_reason));
end $$;

-- ---------- View báo cáo (chỉ chủ xem được nhờ RLS của bảng gốc) ----------
-- Số lượng nhập thực tế sau điều chỉnh
create or replace view v_purchases_effective with (security_invoker = true) as
select p.id, p.shift_id, p.ingredient_id, p.qty as original_qty,
       coalesce((select sum(l.qty_delta) from stock_ledger l where l.kind = 'purchase' and l.ref_id = p.id), p.qty) as effective_qty,
       (select count(*) from stock_ledger l where l.kind = 'purchase' and l.ref_id = p.id and l.is_correction) as corrections
  from purchases p;

-- Tổng hao hụt theo tuần, nguyên liệu và loại (đã tính điều chỉnh)
create or replace view v_waste_summary with (security_invoker = true) as
select date_trunc('week', w.entered_at)::date as week_start,
       w.ingredient_id, i.name as ingredient_name, w.reason_type,
       count(*) filter (where not l.is_correction) as entries,
       -sum(l.qty_delta) as total_qty
  from waste_logs w
  join stock_ledger l on l.kind = 'waste' and l.ref_id = w.id
  join ingredients i on i.id = w.ingredient_id
 group by 1, 2, 3, 4;

-- Nguyên liệu bị đếm lại nhiều lần trong một ca (đếm lại để "thử cho đẹp số")
create or replace view v_recount_flags with (security_invoker = true) as
select c.shift_id, c.ingredient_id, c.kind, count(*) as times_counted
  from stock_counts c
 group by c.shift_id, c.ingredient_id, c.kind
having count(*) > coalesce((select a.value_int from app_settings a
                              where a.key = 'recount_flag_after'
                                and a.shop_id = app_shop_id()), 2);

grant select on v_purchases_effective, v_waste_summary, v_recount_flags to authenticated;

revoke all on function correct_purchase(uuid, integer, text), correct_waste(uuid, integer, text) from public, anon;
grant execute on function correct_purchase(uuid, integer, text), correct_waste(uuid, integer, text) to authenticated;


-- >>> 008_staff_setup.sql
-- =====================================================================
-- Fore · 008_staff_setup.sql · Tạo quán, mời nhân viên, chọn quán (NHIỀU QUÁN)
--
-- Quy trình:
--   1) CHỦ: đăng ký tài khoản rõ ràng (email + mật khẩu) qua Supabase Auth, rồi gọi create_shop(tên quán, tên hiển thị).
--      Người tạo quán trở thành chủ của quán đó. Một người có thể tạo/tham gia nhiều quán.
--   2) CHỦ mời nhân viên: invite_staff(số điện thoại, tên hiển thị[, email]).
--   3) NHÂN VIÊN: đăng nhập bằng số điện thoại (OTP, Supabase xác thực) hoặc email đã xác nhận.
--      Chưa có quán nào thì vào "không gian nhân viên trống" và thấy hộp thư: my_invites().
--      Chấp nhận accept_invite(id) thì trở thành thành viên và tải dữ liệu quán.
--   4) Người thuộc nhiều quán chọn quán bằng select_shop(); my_shops() liệt kê các quán.
--   5) Chủ đặt PIN bằng set_staff_pin (003). Nghỉ việc: đặt staff.active = false (không xóa).
--
-- BẢO MẬT: lời mời chỉ khớp với số điện thoại/email ĐÃ XÁC THỰC trong auth.users
-- (phone_confirmed_at / email_confirmed_at). Không tin số điện thoại do người dùng tự gõ vào app,
-- vì khi đó ai biết số nhân viên cũng có thể "đăng ký giùm" rồi nhận lời mời vào quán.
-- Chạy SAU 007_corrections.sql.
-- =====================================================================

-- Không cho khóa hoặc hạ quyền của chủ cuối cùng TRONG QUÁN (tránh quán không còn chủ)
create or replace function staff_guard() returns trigger
language plpgsql as $$
begin
  if old.role = 'owner' and old.active and (new.active = false or new.role <> 'owner') then
    if not exists (select 1 from staff s where s.shop_id = old.shop_id and s.role = 'owner' and s.active and s.id <> old.id) then
      raise exception 'LAST_OWNER' using errcode = '42501';
    end if;
  end if;
  if new.shop_id <> old.shop_id or new.auth_user_id is distinct from old.auth_user_id then
    raise exception 'Không được đổi quán hoặc tài khoản của thành viên' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger staff_guard_trg before update on staff for each row execute function staff_guard();

-- ---------- Số điện thoại ----------
-- Chuẩn hóa về dạng chỉ chữ số kèm mã quốc gia: '0901 234 567' -> '84901234567'; '+84901234567' -> '84901234567'.
-- Số bắt đầu bằng 0 được hiểu là số Việt Nam. Số nước khác: nhập đủ mã quốc gia (+1..., +44...).
create or replace function normalize_phone(p text) returns text
language sql immutable as $$
  select case
    when d = '' then null
    when btrim(coalesce(p, '')) like '+%' then d
    when d like '0%' then '84' || substr(d, 2)
    else d
  end
  from (select regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g') as d) x
$$;

-- Số điện thoại và email ĐÃ XÁC THỰC của người đang đăng nhập
create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public as $$
begin
  select case when u.phone_confirmed_at is not null then normalize_phone(u.phone) end,
         case when u.email_confirmed_at is not null then lower(btrim(u.email)) end
    into phone, email
    from auth.users u where u.id = auth.uid();
end $$;

-- ---------- Tạo quán (chủ) ----------
create or replace function create_shop(p_shop_name text, p_owner_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_shop uuid;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if coalesce(btrim(p_shop_name), '') = '' then raise exception 'SHOP_NAME_REQUIRED'; end if;
  if coalesce(btrim(p_owner_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  insert into shops (name, created_by) values (btrim(p_shop_name), v_uid) returning id into v_shop;
  insert into staff (shop_id, auth_user_id, full_name, role) values (v_shop, v_uid, btrim(p_owner_name), 'owner');
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, v_shop)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
  return v_shop;
end $$;

-- ---------- Các quán của tôi và chọn quán ----------
-- (Nâng cấp từ bản 1 quán: bỏ các hàm cũ)
drop function if exists claim_first_owner(text);
drop function if exists link_staff_account(text, text, text);
drop function if exists my_profile();

create or replace function my_shops()
returns table (shop_id uuid, shop_name text, staff_id uuid, role text, display_name text, is_current boolean)
language sql stable security definer set search_path = public as $$
  select s.shop_id, sh.name, s.id, s.role, s.full_name, s.shop_id = app_shop_id()
    from staff s join shops sh on sh.id = s.shop_id
   where s.auth_user_id = auth.uid() and s.active
   order by s.created_at
$$;

create or replace function select_shop(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid();
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if not exists (select 1 from staff where shop_id = p_shop and auth_user_id = v_uid and active) then
    raise exception 'NOT_STAFF';
  end if;
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, p_shop)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
end $$;

-- Thông tin của tôi trong quán đang chọn (không có cột PIN). Không có dòng nào = chưa thuộc quán nào.
create or replace function my_profile()
returns table (staff_id uuid, full_name text, role text, has_pin boolean, active boolean, shop_id uuid, shop_name text)
language sql stable security definer set search_path = public as $$
  select s.id, s.full_name, s.role, s.pin_hash is not null, s.active, s.shop_id, sh.name
    from staff s join shops sh on sh.id = s.shop_id
   where s.auth_user_id = auth.uid() and s.shop_id = app_shop_id()
$$;

-- ---------- Mời nhân viên (chủ) ----------
create or replace function invite_staff(p_phone text, p_full_name text, p_email text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_phone text := normalize_phone(p_phone); v_email text := nullif(lower(btrim(p_email)), '');
        v_id uuid;
begin
  if v_phone is null or v_phone !~ '^[1-9][0-9]{7,14}$' then raise exception 'PHONE_INVALID'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  -- đã là thành viên đang hoạt động của quán này?
  if exists (select 1 from staff s join auth.users u on u.id = s.auth_user_id
              where s.shop_id = app_shop_id() and s.active
                and ((u.phone_confirmed_at is not null and normalize_phone(u.phone) = v_phone)
                  or (v_email is not null and u.email_confirmed_at is not null and lower(u.email) = v_email))) then
    raise exception 'ALREADY_MEMBER';
  end if;
  begin
    insert into shop_invites (shop_id, phone, email, full_name, invited_by)
    values (app_shop_id(), v_phone, v_email, btrim(p_full_name), v_me) returning id into v_id;
  exception when unique_violation then
    raise exception 'ALREADY_INVITED';
  end;
  perform _audit('invite_staff', 'shop_invites', v_id, jsonb_build_object('phone', v_phone, 'name', btrim(p_full_name)));
  return v_id;
end $$;

create or replace function cancel_invite(p_invite uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();
  update shop_invites set status = 'cancelled', responded_at = now()
   where id = p_invite and shop_id = app_shop_id() and status = 'pending';
  if not found then raise exception 'NOT_FOUND'; end if;
  perform _audit('cancel_invite', 'shop_invites', p_invite);
end $$;

-- Danh sách thành viên của quán đang chọn, kèm số điện thoại/email (chủ xem)
create or replace function shop_team()
returns table (staff_id uuid, full_name text, role text, active boolean, phone text, email text, has_pin boolean, joined_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return query
    select s.id, s.full_name, s.role, s.active, u.phone::text, u.email::text, s.pin_hash is not null, s.created_at
      from staff s left join auth.users u on u.id = s.auth_user_id
     where s.shop_id = app_shop_id()
     order by (s.role = 'owner') desc, s.active desc, s.created_at;
end $$;

-- ---------- Hộp thư của nhân viên ----------
-- Lời mời đang chờ gửi tới số điện thoại/email ĐÃ XÁC THỰC của người đang đăng nhập
create or replace function my_invites()
returns table (invite_id uuid, shop_id uuid, shop_name text, invited_name text, invited_by_name text, created_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare v_phone text; v_email text;
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  return query
    select i.id, i.shop_id, sh.name, i.full_name, inv.full_name, i.created_at
      from shop_invites i
      join shops sh on sh.id = i.shop_id
      join staff inv on inv.id = i.invited_by
     where i.status = 'pending'
       and ((v_phone is not null and i.phone = v_phone) or (v_email is not null and i.email = v_email))
     order by i.created_at desc;
end $$;

-- Hàm dùng chung: lời mời có thật sự gửi cho tôi không (đang chờ)
create or replace function _invite_for_me(p_invite uuid) returns shop_invites
language plpgsql security definer set search_path = public as $$
declare v_phone text; v_email text; r shop_invites;
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  select * into r from shop_invites i
   where i.id = p_invite and i.status = 'pending'
     and ((v_phone is not null and i.phone = v_phone) or (v_email is not null and i.email = v_email))
   for update;
  if not found then raise exception 'INVITE_NOT_FOUND'; end if;   -- không tồn tại, đã xử lý, hoặc không phải của tôi
  return r;
end $$;

-- Chấp nhận: trở thành nhân viên của quán và chuyển sang quán đó
create or replace function accept_invite(p_invite uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); r shop_invites; v_staff uuid;
begin
  r := _invite_for_me(p_invite);
  select id into v_staff from staff where shop_id = r.shop_id and auth_user_id = v_uid;
  if v_staff is null then
    insert into staff (shop_id, auth_user_id, full_name, role) values (r.shop_id, v_uid, r.full_name, 'staff')
      returning id into v_staff;
  else   -- đã từng làm ở quán này và bị ẩn: kích hoạt lại với vai trò nhân viên
    update staff set active = true, role = 'staff', full_name = r.full_name where id = v_staff and not active;
  end if;
  update shop_invites set status = 'accepted', responded_at = now(), accepted_user_id = v_uid where id = r.id;
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, r.shop_id)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
    values (r.shop_id, v_staff, 'accept_invite', 'shop_invites', r.id, null);
  return v_staff;
end $$;

create or replace function decline_invite(p_invite uuid) returns void
language plpgsql security definer set search_path = public as $$
declare r shop_invites;
begin
  r := _invite_for_me(p_invite);
  update shop_invites set status = 'declined', responded_at = now() where id = r.id;
end $$;

-- ---------- Quyền chạy hàm ----------
revoke all on function _my_verified_contacts(), _invite_for_me(uuid) from public, anon, authenticated;
revoke all on function normalize_phone(text), create_shop(text, text), my_shops(), select_shop(uuid), my_profile(),
  invite_staff(text, text, text), cancel_invite(uuid), shop_team(), my_invites(), accept_invite(uuid), decline_invite(uuid)
  from public, anon;
grant execute on function normalize_phone(text), create_shop(text, text), my_shops(), select_shop(uuid), my_profile(),
  invite_staff(text, text, text), cancel_invite(uuid), shop_team(), my_invites(), accept_invite(uuid), decline_invite(uuid)
  to authenticated;


-- >>> 009_shift_report.sql
-- =====================================================================
-- Fore · 009_shift_report.sql · MỘT hàm báo cáo cho màn hình chủ
--
-- shift_report(ca) gom mọi thứ chủ cần xem về một ca vào MỘT khối JSON:
--   summary         trạng thái chung (ok | warn | alert | no_data) và số lượng từng loại cảnh báo
--   ingredients     kết quả reconcile_shift (004) + cờ XU HƯỚNG (streak_count, streak_flag)
--   cash            kết quả reconcile_cash (005)
--   waste           kết quả waste_report (006)
--   cash_movements  các khoản thu/chi tiền mặt trong ca (ghi chú, người nhập, giờ)
--   warnings        nhắc việc (ví dụ số món chưa có công thức)
-- App chỉ cần gọi MỘT lần: supabase.rpc('shift_report', params: {'p_shift': id}).
--
-- Cờ XU HƯỚNG (giảm báo nhầm): một ca lệch nhẹ chưa chắc là gian lận, nhưng nhiều ca LIÊN TIẾP
-- lệch CÙNG CHIỀU (cùng dương hoặc cùng âm) thì đáng nghi hơn nhiều. streak_count là số ca liên
-- tiếp (tính đến ca đang xem) mà nguyên liệu đó bị vàng/đỏ cùng chiều; streak_flag = true khi
-- streak_count >= streak_shifts (con số trong app_settings, mặc định 3, tối thiểu 2).
--
-- Chỉ CẢNH BÁO, không chặn; chủ tự quyết định. Chỉ chủ gọi được.
-- Chạy SAU 008_staff_setup.sql.
-- =====================================================================

create or replace function shift_report(p_shift uuid) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_n           int;
  v_shop        uuid;
  v_opened      timestamptz;
  v_map         jsonb := '{}'::jsonb;      -- mã nguyên liệu -> {"n": số ca liên tiếp, "sign": chiều lệch, "alive": còn đang nối}
  v_seen        text[];
  v_key         text;
  v_prev        uuid;
  r             record;
  r2            record;
  e             jsonb;
  v_cur         jsonb;                     -- kết quả đối soát của ca đang xem (tính 1 lần, dùng lại)
  v_ingredients jsonb := '[]'::jsonb;
  v_cash        jsonb;
  v_waste       jsonb;
  v_moves       jsonb;
  v_missing     integer;
  v_cancelled   jsonb;
  v_waste_log   jsonb;
  v_purchases   jsonb;
  v_open_diff   boolean := false;
  v_streak      integer;
  v_rank        integer := 0;              -- 0 ok, 1 warn, 2 alert
  v_has_data    boolean := false;
  n_alert       integer := 0;
  n_warn        integer := 0;
  n_streak      integer := 0;
  n_waste_warn  integer := 0;
  v_cash_status text;
  v_overall     text;
  v_shift       jsonb;
begin
  select s.shop_id into v_shop from shifts s where s.id = p_shift;
  if not ((app_is_owner() and v_shop = app_shop_id()) or session_user in ('postgres', 'supabase_admin')) then
    raise exception 'OWNER_ONLY';
  end if;
  select opened_at into v_opened from shifts where id = p_shift;
  if v_opened is null then raise exception 'NOT_FOUND'; end if;
  v_n := greatest(_setting('streak_shifts', 3, v_shop), 2);

  -- reconcile_shift là hàm nặng nhất: gọi đúng 1 lần cho ca đang xem rồi giữ kết quả trong v_cur
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into v_cur from reconcile_shift(p_shift) x;

  -- (1) Chuỗi lệch cùng chiều: bắt đầu từ ca đang xem
  for e in select value from jsonb_array_elements(v_cur) loop
    if e ->> 'status' in ('warn', 'alert') and coalesce((e ->> 'adjusted_variance')::numeric, 0) <> 0 then
      v_map := v_map || jsonb_build_object(e ->> 'ingredient_id',
                 jsonb_build_object('n', 1, 'sign', sign((e ->> 'adjusted_variance')::numeric), 'alive', true));
    end if;
  end loop;

  -- (2) Lùi về các ca đã đóng trước đó (tối đa streak_shifts - 1 ca), nối chuỗi nếu vẫn lệch cùng chiều
  for v_prev in
    select id from shifts where shop_id = v_shop and status = 'closed' and opened_at < v_opened
     order by opened_at desc limit v_n - 1
  loop
    v_seen := '{}';
    for r2 in select * from reconcile_shift(v_prev) loop
      v_key := r2.ingredient_id::text;
      if v_map ? v_key and (v_map -> v_key ->> 'alive')::boolean then
        v_seen := v_seen || v_key;
        if r2.status in ('warn', 'alert') and coalesce(r2.adjusted_variance, 0) <> 0
           and sign(r2.adjusted_variance) = (v_map -> v_key ->> 'sign')::int then
          v_map := jsonb_set(v_map, array[v_key, 'n'], to_jsonb((v_map -> v_key ->> 'n')::int + 1));
        else
          v_map := jsonb_set(v_map, array[v_key, 'alive'], 'false'::jsonb);
        end if;
      end if;
    end loop;
    -- nguyên liệu không có dòng nào ở ca trước: chuỗi đứt
    for v_key in select k from jsonb_object_keys(v_map) k loop
      if (v_map -> v_key ->> 'alive')::boolean and not (v_key = any (v_seen)) then
        v_map := jsonb_set(v_map, array[v_key, 'alive'], 'false'::jsonb);
      end if;
    end loop;
  end loop;

  -- (3) Danh sách nguyên liệu kèm cờ xu hướng, và đếm cảnh báo
  for e in select value from jsonb_array_elements(v_cur) loop
    v_streak := coalesce((v_map -> (e ->> 'ingredient_id') ->> 'n')::int, 0);
    v_ingredients := v_ingredients || (e || jsonb_build_object(
                       'streak_count', v_streak, 'streak_flag', v_streak >= v_n));
    if e ->> 'status' <> 'no_data' then v_has_data := true; end if;
    if e ->> 'status' = 'alert' then n_alert := n_alert + 1; v_rank := greatest(v_rank, 2);
    elsif e ->> 'status' = 'warn' then n_warn := n_warn + 1; v_rank := greatest(v_rank, 1);
    end if;
    if v_streak >= v_n then n_streak := n_streak + 1; v_rank := greatest(v_rank, 1); end if;
  end loop;

  -- (4) Tiền mặt
  select to_jsonb(c), c.status into v_cash, v_cash_status from reconcile_cash(p_shift) c;
  if v_cash_status is not null and v_cash_status <> 'no_data' then
    v_has_data := true;
    if v_cash_status = 'alert' then v_rank := greatest(v_rank, 2);
    elsif v_cash_status = 'warn' then v_rank := greatest(v_rank, 1); end if;
  end if;

  -- Tiền đầu ca lệch so với cuối ca trước từ ngưỡng opening_diff_warn_vnd: đáng chú ý (vàng)
  if v_cash is not null and v_cash ->> 'opening_diff' is not null
     and abs((v_cash ->> 'opening_diff')::integer) >= _setting('opening_diff_warn_vnd', 1000, v_shop) then
    v_open_diff := true;
    v_cash := v_cash || jsonb_build_object('opening_diff_flag', true);
    v_rank := greatest(v_rank, 1);
  end if;

  -- (5) Hao hụt
  select coalesce(jsonb_agg(to_jsonb(w)), '[]'::jsonb), count(*) filter (where w.flag = 'warn')
    into v_waste, n_waste_warn from waste_report(p_shift) w;
  if n_waste_warn > 0 then v_rank := greatest(v_rank, 1); end if;

  -- (6) Các khoản thu/chi và nhắc việc
  select coalesce(jsonb_agg(to_jsonb(m) order by m.entered_at), '[]'::jsonb) into v_moves
    from v_cash_movements m where m.shift_id = p_shift;
  select count(*) into v_missing
    from menu_sizes ms join menu_items mi on mi.id = ms.item_id
   where ms.shop_id = v_shop and ms.active and mi.active
     and not exists (select 1 from recipe_lines rl where rl.size_id = ms.id);

  -- Bill đã thu tiền rồi mới hủy trong ca (chủ nên xem: ai hủy, vì sao, ai duyệt)
  select coalesce(jsonb_agg(jsonb_build_object(
           'bill_no', b.bill_no,
           'amount', coalesce(b.total_amount, 0),
           'payment_method', b.payment_method,
           'paid_at', b.paid_at,
           'cancelled_at', b.cancelled_at,
           'reason', b.cancel_reason,
           'cancelled_by_name', cs.full_name,
           'approved_by_name', ap.full_name) order by b.cancelled_at), '[]'::jsonb)
    into v_cancelled
    from bills b
    left join staff cs on cs.id = b.cancelled_by
    left join staff ap on ap.id = b.approved_by
   where b.shift_id = p_shift and b.status = 'cancelled' and b.paid_at is not null;

  -- Từng lần ghi hao hụt: ai ghi, lúc nào, loại gì. qty = số lượng hiệu lực sau điều chỉnh của chủ.
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', w.id,
           'ingredient_name', i.name, 'unit', i.unit,
           'qty', coalesce((select -sum(l.qty_delta) from stock_ledger l
                             where l.kind = 'waste' and l.ref_id = w.id), w.qty),
           'original_qty', w.qty,
           'reason_type', w.reason_type, 'reason_label', t.label_vi, 'note', w.reason,
           'entered_at', w.entered_at, 'entered_by_name', st.full_name)
           order by w.entered_at), '[]'::jsonb)
    into v_waste_log
    from waste_logs w
    join ingredients i on i.id = w.ingredient_id
    left join waste_types t on t.code = w.reason_type and t.shop_id = w.shop_id
    left join staff st on st.id = w.entered_by
   where w.shift_id = p_shift;

  -- Hàng nhập trong ca (số lượng hiệu lực sau điều chỉnh) để chủ đối chiếu khi nguyên liệu lệch:
  -- phiếu nhập nhanh cũ (purchases) và từng dòng phiếu nhập PN đã ghi vào sổ kho của ca này.
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', x.id,
           'ingredient_name', i.name, 'unit', i.unit,
           'qty', coalesce((select sum(l.qty_delta) from stock_ledger l
                             where l.kind = 'purchase' and l.ref_id = x.id), x.qty),
           'original_qty', x.qty,
           'is_late_entry', x.is_late_entry, 'note', x.note,
           'entered_at', x.entered_at, 'entered_by_name', st.full_name)
           order by x.entered_at), '[]'::jsonb)
    into v_purchases
    from (select pu.id, pu.ingredient_id, pu.qty, pu.is_late_entry, pu.note, pu.entered_at, pu.entered_by
            from purchases pu
           where pu.shift_id = p_shift
          union all
          select pl.id, pl.ingredient_id, pl.qty, false, po.code, sl.at, sl.created_by
            from stock_ledger sl
            join purchase_order_lines pl on pl.id = sl.ref_id
            join purchase_orders po on po.id = pl.order_id
           where sl.shift_id = p_shift and sl.kind = 'purchase' and not sl.is_correction) x
    join ingredients i on i.id = x.ingredient_id
    left join staff st on st.id = x.entered_by;

  v_overall := case when not v_has_data then 'no_data'
                    when v_rank >= 2 then 'alert'
                    when v_rank = 1 then 'warn'
                    else 'ok' end;

  select jsonb_build_object('id', s.id, 'opened_at', s.opened_at, 'closed_at', s.closed_at, 'status', s.status,
                            'opened_by_name', o.full_name, 'closed_by_name', c.full_name)
    into v_shift
    from shifts s
    left join staff o on o.id = s.opened_by
    left join staff c on c.id = s.closed_by
   where s.id = p_shift;

  return jsonb_build_object(
    'shift', v_shift,
    'summary', jsonb_build_object(
      'overall', v_overall,
      'ingredient_alerts', n_alert, 'ingredient_warns', n_warn,
      'streak_flags', n_streak,
      'opening_diff_flag', v_open_diff,
      'cash_status', coalesce(v_cash_status, 'no_data'),
      'waste_warns', n_waste_warn,
      'streak_shifts_setting', v_n),
    'ingredients', v_ingredients,
    'cash', coalesce(v_cash, '{}'::jsonb),
    'waste', v_waste,
    'cash_movements', v_moves,
    'cancelled_bills', v_cancelled,
    'waste_entries', v_waste_log,
    'purchases', v_purchases,
    'warnings', jsonb_build_object('items_without_recipe', v_missing));
end $$;

revoke all on function shift_report(uuid) from public, anon;
grant execute on function shift_report(uuid) to authenticated;

