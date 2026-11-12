-- Fore · chuẩn bị dữ liệu xem trước màn Đối soát.
-- Chỉ cập nhật 3 ca đã đóng gần nhất, trạng thái xem xét và shop đang chọn
-- trong shop demo của đúng email bên dưới; không tạo/xóa hóa đơn, nguyên liệu,
-- nhân viên hay ca. Chạy lại được.
-- Có thể dùng trên project chính vì script giới hạn chính xác shop [DEMO] Fore Dashboard.
-- Chạy sau khi cài đủ sáu module database/01_foundation.sql đến database/06_menu_options.sql.

do $preview$
declare
  v_owner_email text := 'manhkota1203@gmail.com';
  v_uid uuid;
  v_shop uuid;
  v_owner uuid;
  v_closed_count integer;
begin
  select id into v_uid
    from auth.users
   where lower(email) = lower(v_owner_email)
   limit 1;
  if v_uid is null then
    raise exception 'Không tìm thấy tài khoản Auth của email chủ demo.';
  end if;

  select id into v_shop
    from shops
   where created_by = v_uid
     and name = '[DEMO] Fore Dashboard'
   order by created_at, id
   limit 1;
  if v_shop is null then
    raise exception 'Chưa có shop [DEMO] Fore Dashboard. Chạy seed_owner_dashboard.sql trước.';
  end if;

  select id into v_owner
    from staff
   where shop_id = v_shop
     and auth_user_id = v_uid
     and role = 'owner'
     and active
   limit 1;
  if v_owner is null then
    raise exception 'Tài khoản này chưa có quyền chủ trong shop demo.';
  end if;

  select count(*) into v_closed_count
    from (
      select id
        from shifts
       where shop_id = v_shop and status = 'closed'
       order by closed_at desc, id desc
       limit 3
    ) recent;
  if v_closed_count < 3 then
    raise exception 'Cần ít nhất 3 ca đã đóng trong shop demo.';
  end if;

  -- Tạo lệch tuyệt đối 120.000đ (đỏ), 30.000đ (vàng), 0đ (xanh).
  -- Dùng số dư lớn hơn tiền kỳ vọng để closing_cash luôn không âm.
  -- Tiền kỳ vọng tính lại từ bill tiền mặt và phiếu thu/chi hiện có.
  with recent as (
    select s.id, s.opening_cash,
           row_number() over (order by s.closed_at desc, s.id desc) as position
      from shifts s
     where s.shop_id = v_shop and s.status = 'closed'
     order by s.closed_at desc, s.id desc
     limit 3
  ), cash_sales as (
    select b.shift_id, coalesce(sum(b.total_amount), 0)::bigint as amount
      from bills b
      join recent r on r.id = b.shift_id
     where b.status = 'paid' and b.payment_method = 'cash'
     group by b.shift_id
  ), movements as (
    select m.shift_id,
           coalesce(sum(m.amount) filter (where m.direction = 'in'), 0)::bigint as cash_in,
           coalesce(sum(m.amount) filter (where m.direction = 'out'), 0)::bigint as cash_out
      from cash_movements m
      join recent r on r.id = m.shift_id
     group by m.shift_id
  ), expected as (
    select r.id, r.position,
           r.opening_cash::bigint
             + coalesce(s.amount, 0)
             + coalesce(m.cash_in, 0)
             - coalesce(m.cash_out, 0) as amount
      from recent r
      left join cash_sales s on s.shift_id = r.id
      left join movements m on m.shift_id = r.id
  )
  update shifts s
     set closing_cash = least(2147483647::bigint, e.amount + case e.position
       when 1 then 120000
       when 2 then 30000
       else 0
     end)::integer
    from expected e
   where s.id = e.id and s.shop_id = v_shop;

  -- Tạo trạng thái để chủ xem được cả lọc "Chưa xử lý" lẫn ca đã xử lý.
  with recent as (
    select s.id,
           row_number() over (order by s.closed_at desc, s.id desc) as position
      from shifts s
     where s.shop_id = v_shop and s.status = 'closed'
     order by s.closed_at desc, s.id desc
     limit 3
  )
  insert into owner_shift_reviews (shop_id, shift_id, handled, note, updated_by)
  select v_shop, r.id, r.position = 2,
         case when r.position = 2 then 'Demo: đã kiểm tra chứng từ.' else null end,
         v_owner
    from recent r
  on conflict (shop_id, shift_id) do update
    set handled = excluded.handled,
        note = excluded.note,
        updated_by = excluded.updated_by,
        updated_at = now();

  insert into user_settings (auth_user_id, active_shop_id)
  values (v_uid, v_shop)
  on conflict (auth_user_id) do update
    set active_shop_id = excluded.active_shop_id;

  raise notice 'Đã chuẩn bị 3 ca demo xanh/vàng/đỏ và chuyển quán đang chọn sang [DEMO] Fore Dashboard.';
end
$preview$;
