-- Cập nhật ba ca đã seed để QA có đủ mức xanh / vàng / đỏ.
-- Chỉ chạy trên Supabase TEST, sau seed_owner_dashboard.sql.
-- Điền email chủ demo; file này chỉ chạm đúng shop [DEMO] Fore Dashboard của email đó.
-- Có thể chạy lại an toàn: mỗi lần đặt lại ba ca đã đóng gần nhất theo cùng mức.
do $qa$
declare
  v_owner_email text := 'THAY_BANG_EMAIL_TAI_KHOAN_CHU';
  v_uid uuid;
  v_shop uuid;
  v_count integer;
begin
  if v_owner_email = 'THAY_BANG_EMAIL_TAI_KHOAN_CHU' then
    raise exception 'Hãy điền email chủ demo trước khi chạy.';
  end if;

  select id into v_uid from auth.users
   where lower(email) = lower(v_owner_email) limit 1;
  if v_uid is null then
    raise exception 'Không tìm thấy tài khoản chủ demo trong Auth.';
  end if;

  select id into v_shop from shops
   where created_by = v_uid and name = '[DEMO] Fore Dashboard'
   order by created_at limit 1;
  if v_shop is null then
    raise exception 'Không tìm thấy shop demo của email này. Chạy seed_owner_dashboard.sql trước.';
  end if;

  select count(*) into v_count from (
    select id from shifts where shop_id = v_shop and status = 'closed'
    order by closed_at desc limit 3
  ) recent;
  if v_count <> 3 then
    raise exception 'Cần đúng ít nhất 3 ca đã đóng trong shop demo để tạo đủ ba mức.';
  end if;

  with recent as (
    select s.id, s.opening_cash, s.closed_at,
           row_number() over (order by s.closed_at desc) as position
      from shifts s
     where s.shop_id = v_shop and s.status = 'closed'
     order by s.closed_at desc
     limit 3
  ), cash_sales as (
    select b.shift_id, sum(b.total_amount)::bigint as amount
      from bills b join recent r on r.id = b.shift_id
     where b.status = 'paid' and b.payment_method = 'cash'
     group by b.shift_id
  ), movement_totals as (
    select m.shift_id,
           coalesce(sum(m.amount) filter (where m.direction = 'in'), 0)::bigint as cash_in,
           coalesce(sum(m.amount) filter (where m.direction = 'out'), 0)::bigint as cash_out
      from cash_movements m join recent r on r.id = m.shift_id
     group by m.shift_id
  ), totals as (
    select r.id, r.position,
           r.opening_cash
           + coalesce(c.amount, 0)
           + coalesce(m.cash_in, 0)
           - coalesce(m.cash_out, 0)
             as expected_cash
      from recent r
      left join cash_sales c on c.shift_id = r.id
      left join movement_totals m on m.shift_id = r.id
  )
  update shifts s
     set closing_cash = (t.expected_cash + case t.position
       when 1 then -120000 -- mới nhất: đỏ (>= 50.000đ)
       when 2 then -30000  -- kế tiếp: vàng (>= 20.000đ)
       else 0              -- cũ nhất: xanh
     end)::integer
    from totals t
   where s.id = t.id;

  raise notice 'Ba ca demo được đặt thành đỏ, vàng và xanh. Dữ liệu thật ngoài shop demo không đổi.';
end
$qa$;
