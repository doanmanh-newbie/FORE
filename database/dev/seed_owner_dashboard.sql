-- Fore · dữ liệu demo cho dashboard chủ quán.
-- Chỉ chạy trên project Supabase THỬ sau khi đã cài các nhóm SQL 01–04.
-- Tạo một quán riêng [DEMO] Fore Dashboard và chuyển active shop sang quán đó.
-- Không xóa hay ghi đè dữ liệu của quán hiện có. Chạy một lần trên mỗi project.
--
-- Trước khi chạy: sửa v_owner_email thành email tài khoản chủ đã đăng ký trong Supabase Auth.
-- Sau khi chạy: đăng nhập app bằng tài khoản đó; vào menu đổi quán nếu muốn quay lại quán cũ.

do $seed$
declare
  v_owner_email text := 'THAY_BANG_EMAIL_TAI_KHOAN_CHU';
  v_uid uuid;
  v_shop uuid;
  v_owner uuid;
  v_staff uuid;
  v_shift uuid;
  v_bill uuid;
  v_area uuid;
  v_table uuid;
  v_milk uuid;
  v_tea uuid;
  v_pearl uuid;
  v_coffee uuid;
  v_item_milktea uuid;
  v_item_coffee uuid;
  v_item_missing uuid;
  v_size_m uuid;
  v_size_l uuid;
  v_size_cf uuid;
  v_sizes uuid[];
  v_dates date[];
  v_is_open boolean;
  v_day date;
  v_start timestamptz;
  v_end timestamptz;
  v_cash integer;
  v_transfer integer;
  v_price integer;
  v_qty integer;
  v_i integer;
  v_j integer;
  v_n integer;
  v_size uuid;
  v_line_total integer;
  v_paid_at timestamptz;
  v_sale_qty integer;
  v_rec record;
begin
  if v_owner_email = 'THAY_BANG_EMAIL_TAI_KHOAN_CHU' then
    raise exception 'Hãy sửa v_owner_email trong file thành email tài khoản chủ Supabase trước khi chạy.';
  end if;

  select id into v_uid from auth.users where lower(email) = lower(v_owner_email) limit 1;
  if v_uid is null then
    raise exception 'Không tìm thấy tài khoản Auth có email %. Hãy kiểm tra email đã đăng ký.', v_owner_email;
  end if;

  -- Shop riêng để số liệu demo không ảnh hưởng quán thật.
  select id into v_shop from shops
   where created_by = v_uid and name = '[DEMO] Fore Dashboard'
   order by created_at limit 1;
  if v_shop is null then
    insert into shops (name, created_by) values ('[DEMO] Fore Dashboard', v_uid)
      returning id into v_shop;
  elsif exists (select 1 from shifts where shop_id = v_shop) then
    raise exception 'Quán demo đã có dữ liệu. Không chạy seed lần nữa để tránh nhân đôi.';
  end if;

  select id into v_owner from staff where shop_id = v_shop and auth_user_id = v_uid limit 1;
  if v_owner is null then
    insert into staff (shop_id, auth_user_id, full_name, role)
    values (v_shop, v_uid, 'Chủ quán demo', 'owner') returning id into v_owner;
  end if;
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, v_shop)
  on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;

  insert into staff (shop_id, full_name, role)
  values (v_shop, 'Minh Anh · Ca sáng', 'staff') returning id into v_staff;

  insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty)
  values (v_shop, '[DEMO] Sữa tươi', 'Sữa', 'ml', 'important', 20000) returning id into v_milk;
  insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty)
  values (v_shop, '[DEMO] Trà đen', 'Trà', 'g', 'important', 8000) returning id into v_tea;
  insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty)
  values (v_shop, '[DEMO] Trân châu', 'Topping', 'g', 'important', 10000) returning id into v_pearl;
  insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty)
  values (v_shop, '[DEMO] Cà phê', 'Cà phê', 'g', 'normal', 6000) returning id into v_coffee;

  insert into menu_items (shop_id, name, group_name)
  values (v_shop, '[DEMO] Trà sữa', 'Trà sữa') returning id into v_item_milktea;
  insert into menu_items (shop_id, name, group_name)
  values (v_shop, '[DEMO] Cà phê sữa', 'Cà phê') returning id into v_item_coffee;
  insert into menu_items (shop_id, name, group_name)
  values (v_shop, '[DEMO] Món mới chưa có công thức', 'Món mới') returning id into v_item_missing;
  insert into menu_sizes (shop_id, item_id, size_name, price)
  values (v_shop, v_item_milktea, 'M', 35000) returning id into v_size_m;
  insert into menu_sizes (shop_id, item_id, size_name, price)
  values (v_shop, v_item_milktea, 'L', 42000) returning id into v_size_l;
  insert into menu_sizes (shop_id, item_id, size_name, price)
  values (v_shop, v_item_coffee, 'M', 29000) returning id into v_size_cf;
  insert into menu_sizes (shop_id, item_id, size_name, price)
  values (v_shop, v_item_missing, 'M', 39000);
  insert into recipe_lines (shop_id, size_id, ingredient_id, qty) values
    (v_shop, v_size_m, v_milk, 50), (v_shop, v_size_m, v_tea, 15), (v_shop, v_size_m, v_pearl, 50),
    (v_shop, v_size_l, v_milk, 70), (v_shop, v_size_l, v_tea, 20), (v_shop, v_size_l, v_pearl, 70),
    (v_shop, v_size_cf, v_milk, 30), (v_shop, v_size_cf, v_coffee, 20);
  v_sizes := array[v_size_m, v_size_m, v_size_m, v_size_l, v_size_cf];

  insert into areas (shop_id, name) values (v_shop, '[DEMO] Tầng 1') returning id into v_area;
  insert into dining_tables (shop_id, area_id, name)
  values (v_shop, v_area, '[DEMO] Bàn 1') returning id into v_table;

  -- Ba ca đóng có đủ trạng thái xanh/vàng/đỏ, cộng một ca đang mở để demo dashboard.
  v_dates := array[
    ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 3),
    ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 2),
    ((now() at time zone 'Asia/Ho_Chi_Minh')::date - 1),
    case when extract(hour from now() at time zone 'Asia/Ho_Chi_Minh') < 6
      then (now() at time zone 'Asia/Ho_Chi_Minh')::date - 1
      else (now() at time zone 'Asia/Ho_Chi_Minh')::date end
  ];

  for v_i in 1..4 loop
    v_is_open := v_i = 4;
    v_day := v_dates[v_i];
    v_start := (v_day + time '07:00') at time zone 'Asia/Ho_Chi_Minh';
    if v_is_open then
      v_start := least(now() - interval '2 hours', (v_day + time '07:00') at time zone 'Asia/Ho_Chi_Minh');
      v_start := greatest(v_start, (v_day + time '06:00') at time zone 'Asia/Ho_Chi_Minh');
      v_end := null;
    else
      v_end := (v_day + time '22:00') at time zone 'Asia/Ho_Chi_Minh';
    end if;

    insert into shifts (shop_id, opened_by, opened_at, closed_by, closed_at, opening_cash, closing_cash, status)
    values (v_shop, v_staff, v_start, case when v_is_open then null else v_staff end,
      v_end, 500000, case when v_is_open then null else 2780000 end,
      case when v_is_open then 'open' else 'closed' end)
    returning id into v_shift;

    -- Tồn đầu và phiếu nhập làm số tồn có dữ liệu cho màn kho.
    insert into stock_counts (shop_id, shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
    values (v_shop, v_shift, v_milk, 'open', 12000, v_staff, v_start + interval '1 minute'),
           (v_shop, v_shift, v_tea, 'open', 5000, v_staff, v_start + interval '1 minute'),
           (v_shop, v_shift, v_pearl, 'open', 6000, v_staff, v_start + interval '1 minute'),
           (v_shop, v_shift, v_coffee, 'open', 4000, v_staff, v_start + interval '1 minute');
    insert into purchases (shop_id, shift_id, ingredient_id, qty, note, entered_by, entered_at)
    values (v_shop, v_shift, v_milk, 6000, 'Nhập sữa demo', v_staff, v_start + interval '10 minutes'),
           (v_shop, v_shift, v_tea, 2000, 'Nhập trà demo', v_staff, v_start + interval '10 minutes'),
           (v_shop, v_shift, v_pearl, 3000, 'Nhập trân châu demo', v_staff, v_start + interval '10 minutes'),
           (v_shop, v_shift, v_coffee, 1500, 'Nhập cà phê demo', v_staff, v_start + interval '10 minutes');
    insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, created_by)
    values (v_shop, v_start + interval '10 minutes', v_shift, v_milk, 'purchase', 6000, v_staff),
           (v_shop, v_start + interval '10 minutes', v_shift, v_tea, 'purchase', 2000, v_staff),
           (v_shop, v_start + interval '10 minutes', v_shift, v_pearl, 'purchase', 3000, v_staff),
           (v_shop, v_start + interval '10 minutes', v_shift, v_coffee, 'purchase', 1500, v_staff);

    v_n := case when v_is_open then 128 else 100 end;
    v_cash := 0;
    v_transfer := 0;
    for v_j in 1..v_n loop
      v_size := v_sizes[1 + ((v_j - 1) % cardinality(v_sizes))];
      select price into v_price from menu_sizes where id = v_size;
      v_qty := case when v_j % 4 = 0 then 2 else 1 end;
      v_line_total := v_price * v_qty;
      v_paid_at := case when v_is_open
        then greatest(v_start + interval '30 minutes',
          now() - make_interval(mins => (v_n - v_j) * 3))
        else v_start + interval '2 hours' + make_interval(mins => v_j * 35) end;

      insert into bills (shop_id, shift_id, table_id, bill_type, guests, status,
        opened_by, opened_at, paid_by, paid_at, payment_method, total_amount)
      values (v_shop, v_shift,
        case when v_j % 2 = 0 then v_table else null end,
        case when v_j % 2 = 0 then 'dine_in' else 'take_away' end,
        case when v_j % 2 = 0 then 2 else null end,
        'paid', v_staff, v_paid_at - interval '5 minutes', v_staff, v_paid_at,
        case when v_j % 3 = 0 then 'transfer' else 'cash' end, v_line_total)
      returning id into v_bill;

      insert into bill_lines (shop_id, bill_id, size_id, qty, unit_price, created_by, created_at)
      values (v_shop, v_bill, v_size, v_qty, v_price, v_staff, v_paid_at - interval '5 minutes');

      insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
      select v_shop, v_paid_at, v_shift, ingredient_id, 'sale', -(qty * v_qty), v_bill, v_staff
        from recipe_lines where size_id = v_size;

      if v_j % 3 = 0 then v_transfer := v_transfer + v_line_total;
      else v_cash := v_cash + v_line_total; end if;
    end loop;

    insert into cash_movements (shop_id, shift_id, direction, amount, note, entered_by, entered_at)
    values (v_shop, v_shift, 'out', 20000, 'Mua đá và vật tư demo', v_owner,
      case when v_is_open then greatest(v_start + interval '20 minutes', now() - interval '20 minutes')
        else v_start + interval '5 hours' end);

    if not v_is_open then
      -- Tạo ba mức đối soát: đỏ -120.000đ, vàng -30.000đ, xanh -5.000đ.
      if v_i = 2 then
        update shifts set closing_cash = 500000 + v_cash - 20000 - 30000 where id = v_shift;
      elsif v_i = 3 then
        update shifts set closing_cash = 500000 + v_cash - 20000 - 5000 where id = v_shift;
      else
        update shifts set closing_cash = 500000 + v_cash - 20000 - 120000 where id = v_shift;
      end if;
      for v_rec in
        select ingredient_id, open_qty, purchase_qty,
               case
                 when v_i = 1 then loss_qty
                 when v_i = 2 then case ingredient_id
                   when v_milk then 80 when v_tea then 20 when v_pearl then 120 else 0 end
                 else 0
               end as loss_qty
          from (values
            (v_milk, 12000, 6000, 250),
            (v_tea, 5000, 2000, 40),
            (v_pearl, 6000, 3000, 450),
            (v_coffee, 4000, 1500, 0)
          ) as inv(ingredient_id, open_qty, purchase_qty, loss_qty)
      loop
        select coalesce(sum(-qty_delta), 0)::integer into v_sale_qty
          from stock_ledger where shop_id = v_shop and shift_id = v_shift
            and ingredient_id = v_rec.ingredient_id and kind = 'sale';
        insert into stock_counts (shop_id, shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
        values (v_shop, v_shift, v_rec.ingredient_id, 'close',
          greatest(0, v_rec.open_qty + v_rec.purchase_qty - v_sale_qty - v_rec.loss_qty),
          v_staff, v_end - interval '1 minute');
      end loop;
    end if;
  end loop;

  -- Một lời mời chờ và một mặt hàng thiếu công thức giúp các thẻ chú ý có dữ liệu.
  insert into shop_invites (shop_id, phone, full_name, invited_by)
  values (v_shop, '84905550123', 'Hoàng Long · Nhân viên mới', v_owner);

  raise notice 'Đã tạo dữ liệu dashboard demo cho shop % (%) (3 ca đóng xanh/vàng/đỏ, 1 ca đang mở).',
    v_shop, '[DEMO] Fore Dashboard';
end
$seed$;
