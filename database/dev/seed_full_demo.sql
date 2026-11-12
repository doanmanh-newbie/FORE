-- Fore · DỮ LIỆU MẪU ĐẦY ĐỦ để thử giao diện và trải nghiệm (module 01–08).
--
-- !!! CHỈ CHẠY TRÊN PROJECT SUPABASE THỬ (TEST), sau khi đã cài 01 → 08. !!!
-- Script CHỈ THÊM dữ liệu, không xóa hay sửa dữ liệu quán thật. Nhưng sổ kho, hóa đơn, nhật ký là chứng từ
-- bất biến (có trigger chặn sửa/xóa) nên dữ liệu demo KHÔNG gỡ lại được từng phần. Muốn sạch thì dựng lại project thử.
--
-- Tạo 2 quán riêng, tên bắt đầu bằng [DEMO]:
--   · [DEMO] Fore Nguyễn Du  : quán chính, đủ mọi thứ (10 ngày lịch sử + 1 ca đang mở)
--   · [DEMO] Fore Thảo Điền  : quán nhỏ để thử đổi quán / quản lý chi nhánh
--
-- TRƯỚC KHI CHẠY: sửa v_owner_email thành email tài khoản chủ đã đăng ký trong Supabase Auth.
-- TÙY CHỌN: điền v_staff_email = email một tài khoản Auth THỨ HAI (đã đăng ký) để nó vào quán chính với vai trò
--           nhân viên, dùng thử giao diện nhân viên (đếm kho mù, nhập hàng nhanh, ghi hao hụt).
-- SAU KHI CHẠY: đăng nhập app bằng tài khoản chủ; quán đang chọn được đặt sang quán [DEMO] Fore Nguyễn Du.
-- Chạy được MỘT LẦN (chạy lại sẽ báo lỗi để tránh nhân đôi dữ liệu). Dùng số liệu ngẫu nhiên nhưng cố định theo ngày.

do $seed$
declare
  v_owner_email text := 'THAY_BANG_EMAIL_TAI_KHOAN_CHU';
  v_staff_email text := '';
  v_owner_name  text := 'Minh Anh';

  v_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid uuid; v_staff_uid uuid; v_shop uuid;
  v_owner uuid; v_hai uuid; v_lan uuid; v_tran uuid; v_thu uuid; v_real uuid;
  v_ops uuid[];
  v_sups uuid[] := array[]::uuid[];
  v_area uuid; v_tid uuid; v_areas uuid[] := array[]::uuid[]; v_tables uuid[] := array[]::uuid[];
  v_today date; v_day date; v_dix integer; v_s integer; v_k integer;
  v_start timestamptz; v_end timestamptz; v_open boolean; v_op uuid; v_shift uuid;
  v_open_cash integer := 600000; v_cash_sales integer; v_cash_in integer; v_cash_out integer; v_close integer; v_var integer;
  v_n integer; v_j integer; v_l integer; v_nl integer; v_span numeric; v_paid timestamptz; v_bill uuid;
  v_pool uuid[]; v_sizes uuid[]; v_qtys integer[]; v_prices integer[]; v_total integer; v_h integer; v_size uuid; v_q integer; v_price integer;
  v_po uuid; v_poline uuid; v_po_n integer; v_code text; v_price_u numeric; v_qty integer; v_new_avg numeric; v_factor numeric;
  v_wat timestamptz; v_lot uuid; v_pct integer; v_loss integer; v_w integer; v_wi integer; v_wing record; v_wqty integer; v_wtype text; v_wid uuid;
  v_kid uuid; v_i integer; r record; u record; m record;
  v_milk uuid; v_matcha uuid; v_cup uuid; v_lime uuid;
begin
  if v_owner_email = 'THAY_BANG_EMAIL_TAI_KHOAN_CHU' then
    raise exception 'Hãy sửa v_owner_email trong file thành email tài khoản chủ Supabase trước khi chạy.';
  end if;
  select id into v_uid from auth.users where lower(email) = lower(v_owner_email) limit 1;
  if v_uid is null then raise exception 'Không tìm thấy tài khoản Auth có email %.', v_owner_email; end if;
  if btrim(v_staff_email) <> '' then
    select id into v_staff_uid from auth.users where lower(email) = lower(btrim(v_staff_email)) limit 1;
    if v_staff_uid is null then raise exception 'Không tìm thấy tài khoản Auth nhân viên có email %.', v_staff_email; end if;
    if v_staff_uid = v_uid then raise exception 'Email nhân viên phải khác email chủ.'; end if;
  end if;
  if exists (select 1 from shops where created_by = v_uid and name = '[DEMO] Fore Nguyễn Du') then
    raise exception 'Quán demo đã tồn tại. Không chạy seed lần nữa để tránh nhân đôi dữ liệu.';
  end if;

  v_today := case when extract(hour from now() at time zone v_tz) < 7
                  then (now() at time zone v_tz)::date - 1 else (now() at time zone v_tz)::date end;

  -- ================================================================== 1) QUÁN + NHÂN SỰ
  insert into shops (name, created_by) values ('[DEMO] Fore Nguyễn Du', v_uid) returning id into v_shop;
  update shops set legal_name = 'Hộ kinh doanh Fore Nguyễn Du', tax_code = '0312345678', email = 'nguyendu@fore.example',
         phone = '84283812345', address = '12 Nguyễn Du, Quận 1, TP.HCM', open_time = '06:30', close_time = '22:00'
   where id = v_shop;

  insert into staff (shop_id, auth_user_id, full_name, role) values (v_shop, v_uid, v_owner_name, 'owner') returning id into v_owner;
  insert into staff (shop_id, full_name, role, job_role) values (v_shop, 'Văn Hải', 'staff', 'manager') returning id into v_hai;
  insert into staff (shop_id, full_name, role, job_role) values (v_shop, 'Ngọc Lan', 'staff', 'cashier') returning id into v_lan;
  insert into staff (shop_id, full_name, role, job_role) values (v_shop, 'Bảo Trân', 'staff', 'staff') returning id into v_tran;
  insert into staff (shop_id, full_name, role, job_role, active, deactivated_at)
  values (v_shop, 'Thu Hà', 'staff', 'staff', false, now() - interval '20 days') returning id into v_thu;
  if v_staff_uid is not null then
    insert into staff (shop_id, auth_user_id, full_name, role, job_role)
    values (v_shop, v_staff_uid, 'Nhân viên (tài khoản thử)', 'staff', 'staff') returning id into v_real;
  end if;
  v_ops := array[v_lan, v_hai, v_tran];
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, v_shop)
  on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;

  -- Quản lý được xem giá vốn trong Kho; còn lại giữ mặc định
  update role_permissions set allowed = true
   where shop_id = v_shop and job_role = 'manager' and permission in ('inventory.costs', 'members.manage');

  insert into shop_invites (shop_id, phone, full_name, invited_by, job_role, expires_at)
  values (v_shop, '84905550123', 'Hoàng Long', v_owner, 'cashier', now() + interval '5 days'),
         (v_shop, '84905550456', 'Đức Anh', v_owner, 'staff', now() - interval '2 days');

  -- ================================================================== 2) KHU VỰC + BÀN
  for r in select * from (values
      ('Tầng trệt', 1, 6, 2), ('Tầng 1', 2, 4, 4), ('Sân vườn', 3, 4, 4)) as t(name, ord, n, seats) loop
    insert into areas (shop_id, name, sort_order) values (v_shop, r.name, r.ord) returning id into v_area;
    v_areas := v_areas || v_area;
    for v_i in 1..r.n loop
      insert into dining_tables (shop_id, area_id, name, seats, sort_order, active)
      values (v_shop, v_area, 'B' || lpad(((r.ord - 1) * 6 + v_i)::text, 2, '0'),
              case when v_i % 3 = 0 then r.seats + 2 else r.seats end, v_i,
              not (r.ord = 3 and v_i = 4))   -- một bàn sân vườn tạm ẩn
      returning id into v_tid;
      if not (r.ord = 3 and v_i = 4) then v_tables := v_tables || v_tid; end if;
    end loop;
  end loop;

  -- ================================================================== 3) NHÀ CUNG CẤP + NHÓM + NGUYÊN LIỆU
  for r in select * from (values
      (1, 'Sữa & Kem Đại Lợi', 'Chị Thu', '0901000001', 1, '07:00–10:00', '16:00'),
      (2, 'Cà phê Buôn Hoàng Gia', 'Anh Tuấn', '0901000002', 2, '08:00–11:00', '15:00'),
      (3, 'Trà & Topping Tâm An', 'Cô Hạnh', '0901000003', 1, '07:30–10:30', '17:00'),
      (4, 'Nguyên liệu pha chế Sài Gòn', 'Anh Phúc', '0901000004', 1, '09:00–12:00', '16:30'),
      (5, 'Bao bì Minh Phát', 'Chị Lụa', '0901000005', 3, '13:00–16:00', '14:00')
    ) as t(idx, name, contact, phone, lead, win, cutoff) loop
    insert into suppliers (shop_id, name, contact_name, phone, email, address, lead_days, delivery_window, order_cutoff, note)
    values (v_shop, r.name, r.contact, r.phone, 'lienhe' || r.idx || '@ncc.example', 'Kho trung tâm TP.HCM', r.lead, r.win, r.cutoff,
            case when r.idx = 5 then 'Đặt tối thiểu 500 cái mỗi loại' end)
    returning id into v_area;
    v_sups := v_sups || v_area;
  end loop;
  insert into ingredient_groups (shop_id, name, sort_order)
  select v_shop, g, row_number() over () from unnest(array['Cà phê', 'Sữa', 'Trà', 'Topping', 'Đường & siro', 'Trái cây', 'Bao bì']) g;

  drop table if exists demo_ing;
  create temp table demo_ing (
    idx integer primary key, id uuid, name text, grp text, unit text, important boolean, min_qty integer,
    base_cost numeric, target integer, step integer, sup integer, period integer, shelf integer, note text,
    phys numeric not null default 0, avg numeric, last_price numeric, last_at timestamptz
  ) on commit drop;
  insert into demo_ing (idx, name, grp, unit, important, min_qty, base_cost, target, step, sup, period, shelf, note) values
    (1, 'Cà phê Robusta', 'Cà phê', 'g', true, 2000, 280, 8000, 1000, 2, 4, 120, 'Nơi khô ráo, đậy kín'),
    (2, 'Cà phê Arabica', 'Cà phê', 'g', false, 1000, 420, 4000, 1000, 2, 4, 120, 'Nơi khô ráo, đậy kín'),
    (3, 'Sữa tươi', 'Sữa', 'ml', true, 6000, 32, 30000, 1000, 1, 3, 10, 'Bảo quản 2–6°C'),
    (4, 'Sữa đặc', 'Sữa', 'g', false, 2000, 52, 10000, 1000, 1, 6, 180, null),
    (5, 'Kem béo', 'Sữa', 'ml', false, 2000, 85, 8000, 1000, 1, 6, 12, 'Bảo quản 2–6°C'),
    (6, 'Trà đen', 'Trà', 'g', true, 1500, 240, 6000, 1000, 3, 5, 240, null),
    (7, 'Trà ô long', 'Trà', 'g', false, 1000, 380, 4000, 1000, 3, 5, 240, null),
    (8, 'Bột matcha', 'Trà', 'g', false, 300, 1200, 1500, 100, 3, 7, 150, 'Tránh ánh sáng'),
    (9, 'Trân châu', 'Topping', 'g', false, 3000, 60, 10000, 1000, 3, 5, 30, null),
    (10, 'Thạch dừa', 'Topping', 'g', false, 2000, 45, 6000, 1000, 3, 5, 20, null),
    (11, 'Đường cát', 'Đường & siro', 'g', false, 3000, 22, 12000, 1000, 3, 7, 365, null),
    (12, 'Siro đào', 'Đường & siro', 'ml', false, 1000, 70, 4000, 1000, 4, 7, 120, null),
    (13, 'Siro vải', 'Đường & siro', 'ml', false, 1000, 70, 4000, 1000, 4, 7, 120, null),
    (14, 'Đào ngâm', 'Trái cây', 'g', false, 1500, 90, 5000, 500, 4, 4, 25, null),
    (15, 'Chanh tươi', 'Trái cây', 'piece', false, 20, 2500, 120, 20, 4, 3, 12, 'Để ngăn mát'),
    (16, 'Ly 500ml', 'Bao bì', 'piece', false, 300, 900, 1500, 100, 5, 8, 365, null),
    (17, 'Ly 700ml', 'Bao bì', 'piece', false, 300, 1100, 1500, 100, 5, 8, 365, null),
    (18, 'Ống hút', 'Bao bì', 'piece', false, 500, 250, 3000, 100, 5, 8, 365, null),
    (19, 'Nắp ly', 'Bao bì', 'piece', false, 500, 300, 3000, 100, 5, 8, 365, null);
  for r in select * from demo_ing order by idx loop
    insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty, default_supplier_id, storage_note)
    values (v_shop, r.name, r.grp, r.unit, case when r.important then 'important' else 'normal' end, r.min_qty, v_sups[r.sup], r.note)
    returning id into v_area;
    update demo_ing set id = v_area where idx = r.idx;
  end loop;
  select id into v_milk from demo_ing where idx = 3;
  select id into v_matcha from demo_ing where idx = 8;
  select id into v_cup from demo_ing where idx = 16;
  select id into v_lime from demo_ing where idx = 15;

  -- ================================================================== 4) THỰC ĐƠN + CÔNG THỨC
  insert into menu_categories (shop_id, name, sort_order)
  select v_shop, g, row_number() over () from unnest(array['Cà phê', 'Trà sữa', 'Trà trái cây', 'Đá xay', 'Món mới']) g;

  drop table if exists demo_size;
  create temp table demo_size (id uuid primary key, item text, size_name text, price integer, weight integer) on commit drop;
  for r in select * from (values
      ('Cà phê đen đá', 'Cà phê', 'M', 25000, 5, '{"Cà phê Robusta":18,"Đường cát":10}'::jsonb),
      ('Cà phê đen đá', 'Cà phê', 'L', 29000, 2, '{"Cà phê Robusta":22,"Đường cát":12}'),
      ('Cà phê sữa đá', 'Cà phê', 'M', 29000, 9, '{"Cà phê Robusta":18,"Sữa đặc":25}'),
      ('Cà phê sữa đá', 'Cà phê', 'L', 35000, 4, '{"Cà phê Robusta":22,"Sữa đặc":30}'),
      ('Bạc xỉu', 'Cà phê', 'M', 32000, 6, '{"Cà phê Robusta":12,"Sữa tươi":80,"Sữa đặc":20}'),
      ('Bạc xỉu', 'Cà phê', 'L', 38000, 3, '{"Cà phê Robusta":15,"Sữa tươi":100,"Sữa đặc":25}'),
      ('Latte Arabica', 'Cà phê', 'M', 45000, 3, '{"Cà phê Arabica":18,"Sữa tươi":150}'),
      ('Latte Arabica', 'Cà phê', 'L', 52000, 1, '{"Cà phê Arabica":20,"Sữa tươi":200}'),
      ('Trà sữa truyền thống', 'Trà sữa', 'M', 35000, 10, '{"Trà đen":15,"Sữa tươi":50,"Đường cát":15,"Kem béo":20}'),
      ('Trà sữa truyền thống', 'Trà sữa', 'L', 42000, 5, '{"Trà đen":20,"Sữa tươi":70,"Đường cát":20,"Kem béo":25}'),
      ('Trà sữa ô long', 'Trà sữa', 'M', 39000, 6, '{"Trà ô long":15,"Sữa tươi":60,"Kem béo":20}'),
      ('Trà sữa ô long', 'Trà sữa', 'L', 46000, 3, '{"Trà ô long":20,"Sữa tươi":80,"Kem béo":25}'),
      ('Matcha latte', 'Trà sữa', 'M', 49000, 3, '{"Bột matcha":6,"Sữa tươi":150,"Đường cát":10}'),
      ('Matcha latte', 'Trà sữa', 'L', 56000, 1, '{"Bột matcha":8,"Sữa tươi":200,"Đường cát":12}'),
      ('Trà đào cam sả', 'Trà trái cây', 'M', 39000, 7, '{"Trà đen":12,"Siro đào":30,"Đào ngâm":40,"Chanh tươi":1}'),
      ('Trà đào cam sả', 'Trà trái cây', 'L', 45000, 3, '{"Trà đen":15,"Siro đào":40,"Đào ngâm":50,"Chanh tươi":1}'),
      ('Trà vải', 'Trà trái cây', 'M', 39000, 4, '{"Trà ô long":12,"Siro vải":30}'),
      ('Trà vải', 'Trà trái cây', 'L', 45000, 2, '{"Trà ô long":15,"Siro vải":40}'),
      ('Cà phê đá xay', 'Đá xay', 'M', 45000, 3, '{"Cà phê Robusta":15,"Sữa tươi":60,"Đường cát":20,"Kem béo":30}'),
      ('Cà phê đá xay', 'Đá xay', 'L', 52000, 1, '{"Cà phê Robusta":18,"Sữa tươi":80,"Đường cát":25,"Kem béo":40}')
    ) as t(item, grp, size_name, price, weight, recipe) loop
    select id into v_area from menu_items where shop_id = v_shop and name = r.item;
    if v_area is null then
      insert into menu_items (shop_id, name, group_name) values (v_shop, r.item, r.grp) returning id into v_area;
    end if;
    insert into menu_sizes (shop_id, item_id, size_name, price) values (v_shop, v_area, r.size_name, r.price) returning id into v_size;
    insert into demo_size values (v_size, r.item, r.size_name, r.price, r.weight);
    insert into recipe_lines (shop_id, size_id, ingredient_id, qty)
    select v_shop, v_size, d.id, (e.value)::integer
      from jsonb_each_text(r.recipe) e join demo_ing d on d.name = e.key;
    insert into recipe_lines (shop_id, size_id, ingredient_id, qty)
    select v_shop, v_size, d.id, 1 from demo_ing d
     where d.name in (case r.size_name when 'M' then 'Ly 500ml' else 'Ly 700ml' end, 'Ống hút', 'Nắp ly');
  end loop;
  -- Món chưa có công thức: để thử cảnh báo "thiếu công thức"
  insert into menu_items (shop_id, name, group_name) values (v_shop, 'Nước ép cam tươi', 'Món mới') returning id into v_area;
  insert into menu_sizes (shop_id, item_id, size_name, price) values (v_shop, v_area, 'M', 42000);

  -- Topping và tùy chọn mức đường (module 06)
  insert into menu_toppings (shop_id, name, price, ingredient_id, qty)
  select v_shop, 'Trân châu', 8000, d.id, 50 from demo_ing d where d.name = 'Trân châu';
  insert into menu_toppings (shop_id, name, price, ingredient_id, qty)
  select v_shop, 'Thạch dừa', 6000, d.id, 40 from demo_ing d where d.name = 'Thạch dừa';
  insert into menu_item_toppings (shop_id, item_id, topping_id)
  select v_shop, i.id, t.id from menu_items i cross join menu_toppings t
   where i.shop_id = v_shop and i.group_name = 'Trà sữa' and t.shop_id = v_shop;
  insert into menu_option_groups (shop_id, item_id, name, required, sort_order)
  select v_shop, i.id, 'Mức đường', true, 1 from menu_items i where i.shop_id = v_shop and i.group_name in ('Trà sữa', 'Cà phê');
  insert into menu_option_choices (shop_id, group_id, name, is_default, sort_order)
  select v_shop, g.id, c.name, c.def, c.ord from menu_option_groups g
   cross join (values ('100% đường', true, 1), ('70% đường', false, 2), ('50% đường', false, 3)) as c(name, def, ord)
   where g.shop_id = v_shop;

  select array_agg(id) into v_pool from (select s.id from demo_size s, generate_series(1, s.weight) order by s.id) p;

  -- ================================================================== 5) 10 NGÀY CA LÀM + BÁN HÀNG + KHO + TIỀN
  v_po_n := 0;
  for v_k in 1..21 loop
    v_dix := (v_k - 1) / 2;                       -- 0..10
    v_s := ((v_k - 1) % 2) + 1;                   -- 1 = ca sáng, 2 = ca chiều
    v_day := v_today - (10 - v_dix);
    v_open := (v_k = 21);                         -- ca đầu của hôm nay đang mở
    v_op := v_ops[1 + (v_k % 3)];
    v_start := ((v_day + case v_s when 1 then time '06:30' else time '14:00' end) at time zone v_tz);
    v_end := ((v_day + case v_s when 1 then time '14:00' else time '22:00' end) at time zone v_tz);
    if v_open then
      v_start := least(now() - interval '3 hours', v_start);
      v_start := greatest(v_start, (v_day + time '05:00') at time zone v_tz);
      v_end := null;
    end if;

    insert into shifts (shop_id, opened_by, opened_at, closed_by, closed_at, opening_cash, closing_cash, status)
    values (v_shop, v_op, v_start, case when v_open then null else v_op end, v_end, v_open_cash,
            case when v_open then null else v_open_cash end, case when v_open then 'open' else 'closed' end)
    returning id into v_shift;

    -- Tồn đầu ca = tồn cuối ca trước (lần đếm đầu tiên là 0, rồi nhập hàng)
    insert into stock_counts (shop_id, shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
    select v_shop, v_shift, id, 'open', greatest(round(phys)::integer, 0), v_op, v_start + interval '1 minute' from demo_ing;

    -- ---- Nhập hàng theo nhà cung cấp (ca sáng): phiếu PN có lô, hạn dùng, giá; giá bình quân gia quyền
    if v_s = 1 or v_open then
      for v_i in 1..5 loop
        v_po := null;
        for r in select * from demo_ing
                  where sup = v_i and (v_dix % period = 0) and (target - phys) >= step order by idx loop
          if v_po is null then
            v_po_n := v_po_n + 1;
            v_code := 'PN-' || to_char(v_day, 'DDMM') || '-' || v_i;
            insert into purchase_orders (shop_id, code, supplier_id, status, source, vat_included, received_at, total_amount,
                                         created_by, confirmed_by, confirmed_at, created_at, updated_at)
            values (v_shop, v_code, v_sups[v_i], 'confirmed', 'owner', true, v_start + interval '10 minutes', 0,
                    v_owner, v_owner, v_start + interval '10 minutes', v_start, v_start + interval '10 minutes')
            returning id into v_po;
          end if;
          v_qty := (ceil((r.target - r.phys) / r.step) * r.step)::integer;
          v_factor := 1 + ((abs(hashtext(r.name || v_dix::text)) % 5) - 2) / 100.0
                      + case when r.idx = 3 and v_dix >= 6 then 0.06 else 0 end;      -- sữa tươi tăng giá 6% từ giữa kỳ
          v_price_u := round(r.base_cost * v_factor, 2);
          insert into purchase_order_lines (shop_id, order_id, ingredient_id, qty, unit_price, lot_code, expiry_date, created_at)
          values (v_shop, v_po, r.id, v_qty, v_price_u, 'ST-' || to_char(v_day, 'DDMM') || '-' || lpad(r.idx::text, 2, '0'),
                  case when r.idx = 15 and v_dix >= 6 then v_today + 2 else v_day + r.shelf end, v_start)
          returning id into v_poline;
          insert into stock_lots (shop_id, ingredient_id, code, received_at, expiry_date, qty_received, unit_cost, order_line_id)
          select v_shop, r.id, lot_code, v_start + interval '10 minutes', expiry_date, qty, unit_price, id
            from purchase_order_lines where id = v_poline returning id into v_lot;
          update purchase_order_lines set lot_id = v_lot where id = v_poline;
          insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, note)
          values (v_shop, v_start + interval '10 minutes', v_shift, r.id, 'purchase', v_qty, v_poline, v_owner, v_code);
          v_new_avg := case when r.avg is null or r.phys <= 0 then v_price_u
                            else (r.phys * r.avg + v_qty * v_price_u) / (r.phys + v_qty) end;
          insert into ingredient_cost_events (shop_id, ingredient_id, at, kind, price, avg_before, avg_after, qty, order_id, created_by)
          values (v_shop, r.id, v_start + interval '10 minutes', 'purchase', v_price_u, r.avg, round(v_new_avg, 2), v_qty, v_po, v_owner);
          update demo_ing set phys = phys + v_qty, avg = round(v_new_avg, 2), last_price = v_price_u,
                 last_at = v_start + interval '10 minutes' where idx = r.idx;
        end loop;
        if v_po is not null then
          update purchase_orders set total_amount = (select round(sum(qty * unit_price))::bigint from purchase_order_lines where order_id = v_po)
           where id = v_po;
        end if;
      end loop;
    end if;

    -- ---- Bán hàng
    v_n := case when v_open
                then least(70, greatest(6, (extract(epoch from (now() - v_start)) / 60 / 4)::integer))
                else 26 + (abs(hashtext(v_day::text || v_s::text)) % 16)
                     + case when extract(isodow from v_day) in (6, 7) then 12 else 0 end
                     + case when v_s = 2 then 4 else 0 end end;
    v_span := case when v_open then greatest(extract(epoch from (now() - v_start)) / 60 - 20, 10)
                   else extract(epoch from (v_end - v_start)) / 60 - 60 end;
    v_cash_sales := 0;
    for v_j in 1..v_n loop
      v_h := abs(hashtext(v_day::text || '-' || v_s || '-' || v_j));
      v_nl := 1 + case when v_h % 5 = 0 then 1 else 0 end + case when v_h % 13 = 0 then 1 else 0 end;
      v_sizes := array[]::uuid[]; v_qtys := array[]::integer[]; v_prices := array[]::integer[]; v_total := 0;
      for v_l in 1..v_nl loop
        v_size := v_pool[1 + (abs(hashtext(v_day::text || '-' || v_s || '-' || v_j || '-' || v_l)) % cardinality(v_pool))];
        v_q := case when v_h % 7 = 0 and v_l = 1 then 2 else 1 end;
        select price into v_price from demo_size where id = v_size;
        v_sizes := v_sizes || v_size; v_qtys := v_qtys || v_q; v_prices := v_prices || v_price;
        v_total := v_total + v_price * v_q;
      end loop;
      v_paid := v_start + interval '20 minutes' + make_interval(mins => floor((v_j - 1) * v_span / v_n)::integer);
      insert into bills (shop_id, shift_id, table_id, bill_type, guests, status, opened_by, opened_at, paid_by, paid_at,
                         payment_method, total_amount)
      values (v_shop, v_shift, case when v_j % 2 = 0 then v_tables[1 + (v_h % cardinality(v_tables))] end,
              case when v_j % 2 = 0 then 'dine_in' else 'take_away' end, case when v_j % 2 = 0 then 1 + (v_h % 4) end,
              'paid', v_op, v_paid - interval '4 minutes', v_op, v_paid,
              case when v_h % 3 = 0 then 'transfer' else 'cash' end, v_total)
      returning id into v_bill;
      for v_l in 1..v_nl loop
        insert into bill_lines (shop_id, bill_id, size_id, qty, unit_price, created_by, created_at)
        values (v_shop, v_bill, v_sizes[v_l], v_qtys[v_l], v_prices[v_l], v_op, v_paid - interval '4 minutes');
        insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
        select v_shop, v_paid, v_shift, ingredient_id, 'sale', -(qty * v_qtys[v_l]), v_bill, v_op
          from recipe_lines where size_id = v_sizes[v_l];
      end loop;
      if v_h % 3 <> 0 then v_cash_sales := v_cash_sales + v_total; end if;
    end loop;
    update demo_ing d set phys = d.phys - coalesce(x.used, 0)
      from (select ingredient_id, -sum(qty_delta) as used from stock_ledger
             where shop_id = v_shop and shift_id = v_shift and kind = 'sale' group by ingredient_id) x
     where d.id = x.ingredient_id;

    -- ---- Hao hụt có ghi (1–2 lần mỗi ca)
    v_w := 1 + (abs(hashtext('w' || v_k)) % 2);
    for v_wi in 1..v_w loop
      select * into v_wing from demo_ing where idx = (array[3, 5, 14, 9, 10, 3])[1 + (abs(hashtext('wi' || v_k || v_wi)) % 6)];
      v_wqty := 300 + (abs(hashtext('wq' || v_k || v_wi)) % 700);
      if v_wing.phys > v_wqty + 500 then
        v_wtype := (array['expired', 'mistake', 'spill'])[1 + (abs(hashtext('wt' || v_k || v_wi)) % 3)];
        select id into v_lot from stock_lots where ingredient_id = v_wing.id and received_at <= v_start + interval '3 hours'
         order by received_at desc limit 1;
        v_wat := least(v_start + interval '4 hours' + make_interval(mins => v_wi * 25), coalesce(v_end, now()) - interval '1 minute');
        insert into waste_logs (shop_id, shift_id, ingredient_id, qty, reason_type, reason, entered_by, entered_at, code, lot_id)
        values (v_shop, v_shift, v_wing.id, v_wqty, v_wtype,
                case v_wtype when 'expired' then 'Đổ bỏ quá giờ' when 'mistake' then 'Làm sai, đổ ly' else 'Đổ vỡ khi pha' end,
                v_op, v_wat, 'HH-' || to_char(v_day, 'DDMM') || '-' || v_s || v_wi, v_lot)
        returning id into v_wid;
        insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
        values (v_shop, v_wat, v_shift, v_wing.id, 'waste', -v_wqty, v_wid, v_op);
        update demo_ing set phys = phys - v_wqty where idx = v_wing.idx;
        if v_k = 20 and v_wi = 1 then   -- Lan ghi nhầm một lần hao hụt và nhờ chủ sửa
          insert into inventory_requests (shop_id, kind, ref_id, note, created_by, created_at)
          values (v_shop, 'waste', v_wid, 'Em ghi nhầm số lượng, thực tế là 300ml', v_lan, v_start + interval '6 hours');
        end if;
      end if;
    end loop;

    -- ---- Tiền mặt ra/vào trong ca
    v_cash_out := 40000; v_cash_in := 0;
    insert into cash_movements (shop_id, shift_id, direction, amount, note, entered_by, entered_at)
    values (v_shop, v_shift, 'out', 40000, 'Mua đá viên', v_op, least(v_start + interval '3 hours', coalesce(v_end, now()) - interval '1 minute'));
    if v_k % 7 = 0 then
      insert into cash_movements (shop_id, shift_id, direction, amount, note, entered_by, entered_at)
      values (v_shop, v_shift, 'in', 200000, 'Chủ gửi thêm tiền lẻ', v_owner, v_start + interval '30 minutes');
      v_cash_in := 200000;
    end if;
    if v_k % 6 = 0 and not v_open then
      insert into cash_movements (shop_id, shift_id, direction, amount, note, entered_by, entered_at)
      values (v_shop, v_shift, 'out', 85000, 'Mua chanh và đường lẻ', v_op, v_start + interval '5 hours');
      v_cash_out := v_cash_out + 85000;
    end if;

    -- ---- Đóng ca: hao hụt không ghi (tạo mức vàng/đỏ), đếm cuối ca, tiền cuối ca
    if not v_open then
      v_pct := case v_k when 4 then 4 when 11 then 4 when 9 then 8 when 16 then 8 else 0 end;
      if v_pct > 0 then
        for r in select * from demo_ing where idx in (1, 3, 6) loop
          select coalesce(sum(-qty_delta), 0)::integer into v_loss from stock_ledger
           where shop_id = v_shop and shift_id = v_shift and ingredient_id = r.id and kind = 'sale';
          v_loss := round(v_loss * v_pct / 100.0)::integer;
          update demo_ing set phys = greatest(phys - v_loss, 0) where idx = r.idx;
        end loop;
      end if;
      insert into stock_counts (shop_id, shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
      select v_shop, v_shift, id, 'close', greatest(round(phys)::integer, 0), v_op, v_end - interval '1 minute' from demo_ing;

      v_var := case v_k when 6 then -25000 when 11 then -22000 when 14 then -60000 when 18 then 5000
                        else case when v_k % 5 = 0 then -3000 else 0 end end;
      v_close := v_open_cash + v_cash_sales + v_cash_in - v_cash_out + v_var;
      update shifts set closing_cash = v_close where id = v_shift;
      v_open_cash := v_close;
      if v_k in (6, 14) then
        insert into owner_shift_reviews (shop_id, shift_id, handled, note, updated_by, updated_at)
        values (v_shop, v_shift, v_k = 6,
                case v_k when 6 then 'Đã hỏi Ngọc Lan: trả nhầm tiền thừa, nhắc đếm lại trước khi trả.' else null end,
                v_owner, v_end + interval '30 minutes');
      end if;
    end if;
  end loop;

  -- Giá bình quân hiện tại, giá nhập gần nhất
  update ingredients i set unit_cost = round(d.avg, 2), unit_cost_updated_at = d.last_at, last_purchase_cost = d.last_price,
         last_purchase_at = d.last_at
    from demo_ing d where i.id = d.id;

  -- ================================================================== 6) PHIẾU NHẬP ĐẶC BIỆT (hôm nay)
  -- 6a) Nhân viên nhận hàng, chờ chủ bổ sung giá
  select id into v_shift from shifts where shop_id = v_shop and status = 'open';
  v_op := v_lan;
  insert into purchase_orders (shop_id, code, supplier_id, status, source, received_at, needs_pricing, created_by, confirmed_by,
                               confirmed_at, vat_included, shipping_fee)
  values (v_shop, 'PN-' || to_char(v_today, 'DDMM') || '-NV', v_sups[4], 'confirmed', 'staff', now() - interval '40 minutes', true,
          v_lan, v_lan, now() - interval '40 minutes', true, 0)
  returning id into v_po;
  for r in select * from demo_ing where idx in (12, 15) loop
    v_qty := case r.idx when 12 then 3000 else 40 end;
    insert into purchase_order_lines (shop_id, order_id, ingredient_id, qty, lot_code, expiry_date, created_at)
    values (v_shop, v_po, r.id, v_qty, 'ST-' || to_char(v_today, 'DDMM') || '-' || lpad(r.idx::text, 2, '0'), v_today + 14, now() - interval '40 minutes')
    returning id into v_poline;
    insert into stock_lots (shop_id, ingredient_id, code, received_at, expiry_date, qty_received, order_line_id)
    select v_shop, r.id, lot_code, now() - interval '40 minutes', expiry_date, qty, id from purchase_order_lines where id = v_poline
    returning id into v_lot;
    update purchase_order_lines set lot_id = v_lot where id = v_poline;
    insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, note)
    values (v_shop, now() - interval '40 minutes', v_shift, r.id, 'purchase', v_qty, v_poline, v_lan, 'Nhân viên nhận hàng');
    update demo_ing set phys = phys + v_qty where idx = r.idx;
  end loop;

  -- 6b) Phiếu nháp từ gợi ý nhập hàng; 6c) phiếu đã hủy
  insert into purchase_orders (shop_id, code, supplier_id, status, source, note, created_by)
  values (v_shop, 'PN-' || to_char(v_today, 'DDMM') || '-GY', v_sups[1], 'draft', 'suggestion', 'Tạo từ gợi ý nhập hàng', v_owner)
  returning id into v_po;
  insert into purchase_order_lines (shop_id, order_id, ingredient_id, qty, unit_price)
  select v_shop, v_po, d.id, 20000, d.last_price from demo_ing d where d.idx = 3;
  insert into purchase_order_lines (shop_id, order_id, ingredient_id, qty, unit_price)
  select v_shop, v_po, d.id, 4000, d.last_price from demo_ing d where d.idx = 5;
  insert into purchase_orders (shop_id, code, supplier_id, status, source, cancel_reason, created_by, created_at)
  values (v_shop, 'PN-' || to_char(v_today - 3, 'DDMM') || '-HU', v_sups[2], 'cancelled', 'owner', 'Nhà cung cấp hết hàng', v_owner,
          now() - interval '3 days');

  -- ================================================================== 7) KIỂM KÊ (3 trạng thái)
  -- 7a) Đã duyệt cách đây 6 ngày, có điều chỉnh vào sổ kho
  insert into stocktakes (shop_id, code, status, started_by, started_at, saved_at, submitted_at, reviewed_by, reviewed_at, review_reason)
  values (v_shop, 'KK-' || to_char(v_today - 6, 'DDMM'), 'approved', v_lan,
          ((v_today - 6 + time '21:00') at time zone v_tz), ((v_today - 6 + time '21:20') at time zone v_tz),
          ((v_today - 6 + time '21:25') at time zone v_tz), v_owner, ((v_today - 6 + time '22:10') at time zone v_tz), 'Hao hụt chưa ghi')
  returning id into v_kid;
  insert into stocktake_lines (shop_id, stocktake_id, ingredient_id, counted_qty, counted_at, system_qty, unit_cost, decision)
  select v_shop, v_kid, d.id,
         round(d.target * 0.55)::integer + case when d.idx = 3 then -1500 when d.idx = 8 then 40 else 0 end,
         ((v_today - 6 + time '21:15') at time zone v_tz), round(d.target * 0.55)::integer, round(d.avg, 2),
         case when d.idx in (3, 8) then 'adjust' else 'keep' end
    from demo_ing d;
  insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by, is_correction, note)
  select v_shop, ((v_today - 6 + time '22:10') at time zone v_tz), null, d.id, 'adjust', case d.idx when 3 then -1500 else 40 end,
         v_kid, v_owner, true, 'Hao hụt chưa ghi'
    from demo_ing d where d.idx in (3, 8);

  -- 7b) Đã gửi, chờ chủ duyệt (có lệch)
  insert into stocktakes (shop_id, code, status, started_by, started_at, saved_at, submitted_at)
  values (v_shop, 'KK-' || to_char(v_today, 'DDMM'), 'submitted', v_tran, now() - interval '90 minutes', now() - interval '65 minutes',
          now() - interval '60 minutes')
  returning id into v_kid;
  insert into stocktake_lines (shop_id, stocktake_id, ingredient_id, counted_qty, counted_at, system_qty, unit_cost)
  select v_shop, v_kid, d.id,
         greatest(round(d.phys)::integer + case d.idx when 3 then -1500 when 8 then 30 when 16 then -12 when 15 then -3 else 0 end, 0),
         now() - interval '70 minutes', round(d.phys)::integer, round(d.avg, 2)
    from demo_ing d;

  -- 7c) Chủ yêu cầu đếm lại hai dòng
  insert into stocktakes (shop_id, code, status, started_by, started_at, saved_at, submitted_at, review_note)
  values (v_shop, 'KK-' || to_char(v_today - 2, 'DDMM') || '-B', 'recount', v_lan,
          ((v_today - 2 + time '20:00') at time zone v_tz), ((v_today - 2 + time '20:30') at time zone v_tz),
          ((v_today - 2 + time '20:35') at time zone v_tz), 'Sữa tươi và trân châu lệch nhiều, nhờ đếm lại giúp.')
  returning id into v_kid;
  insert into stocktake_lines (shop_id, stocktake_id, ingredient_id, counted_qty, counted_at, system_qty, unit_cost, recount_requested)
  select v_shop, v_kid, d.id, round(d.target * 0.5)::integer + case d.idx when 3 then -2500 when 9 then 900 else 0 end,
         ((v_today - 2 + time '20:10') at time zone v_tz), round(d.target * 0.5)::integer, round(d.avg, 2), d.idx in (3, 9)
    from demo_ing d;

  -- 7d) Nháp của tài khoản nhân viên thật (nếu có): đã đếm 6 dòng
  if v_real is not null then
    insert into stocktakes (shop_id, code, status, started_by, started_at, saved_at)
    values (v_shop, 'KK-' || to_char(v_today, 'DDMM') || '-C', 'draft', v_real, now() - interval '20 minutes', now() - interval '5 minutes')
    returning id into v_kid;
    insert into stocktake_lines (shop_id, stocktake_id, ingredient_id, counted_qty, counted_at)
    select v_shop, v_kid, d.id, case when d.idx <= 6 then greatest(round(d.phys)::integer - 200, 0) end,
           case when d.idx <= 6 then now() - interval '10 minutes' end
      from demo_ing d;
  end if;

  -- ================================================================== 8) HỖ TRỢ + NHẬT KÝ QUẢN TRỊ
  insert into support_requests (shop_id, code, topic, message, contact, diagnostics, status, created_by, created_at)
  values (v_shop, 'SP-' || to_char(v_today - 4, 'DDMM') || '-A1B2', 'printer', 'Máy in bếp không in được phiếu từ hôm qua.', 'callback',
          '{"app_version":"dev","platform":"android"}'::jsonb, 'open', v_owner, now() - interval '4 days'),
         (v_shop, 'SP-' || to_char(v_today - 9, 'DDMM') || '-C3D4', 'setup', 'Cần hướng dẫn thêm nhà cung cấp mới.', 'in_app',
          null, 'closed', v_owner, now() - interval '9 days');

  insert into audit_log (shop_id, at, actor, action, entity, entity_id, detail) values
    (v_shop, now() - interval '12 days', v_owner, 'shop_profile_save', 'shops', v_shop, '{"name":"[DEMO] Fore Nguyễn Du"}'),
    (v_shop, now() - interval '11 days', v_owner, 'roles_save', 'role_permissions', null,
       '{"job_role":"manager","permissions":{"inventory.costs":true,"members.manage":true}}'),
    (v_shop, now() - interval '10 days', v_owner, 'set_job_role', 'staff', v_hai, '{"from":"staff","to":"manager"}'),
    (v_shop, now() - interval '9 days', v_owner, 'set_job_role', 'staff', v_lan, '{"from":"staff","to":"cashier"}'),
    (v_shop, now() - interval '20 days', v_owner, 'revoke_member', 'staff', v_thu, '{"name":"Thu Hà","job_role":"staff"}'),
    (v_shop, now() - interval '6 days', v_owner, 'st_approve', 'stocktake', null, '{"adjusted":2}'),
    (v_shop, now() - interval '5 days', v_owner, 'po_set_prices', 'purchase_order', null, '{"code":"PN-demo"}'),
    (v_shop, now() - interval '2 days', v_owner, 'table_set_active', 'dining_tables', v_tables[1], '{"active":true}');

  raise notice 'Đã tạo quán [DEMO] Fore Nguyễn Du (%): 3 khu vực, 19 nguyên liệu, 5 nhà cung cấp, 10 menu, 21 ca (20 đóng + 1 mở), 3 kiểm kê.', v_shop;
end
$seed$;

-- ===================================================================================================
-- QUÁN THỨ HAI (nhỏ): để thử Đổi quán, Quản lý chi nhánh, so sánh kho. Cùng chủ với quán chính.
-- ===================================================================================================
do $seed2$
declare
  v_owner_email text := 'THAY_BANG_EMAIL_TAI_KHOAN_CHU';   -- dùng cùng email như khối trên
  v_tz constant text := 'Asia/Ho_Chi_Minh';
  v_uid uuid; v_shop uuid; v_owner uuid; v_staff uuid; v_area uuid; v_table uuid; v_shift uuid; v_bill uuid;
  v_today date; v_start timestamptz; v_i integer; v_item uuid; v_size uuid; v_sizes uuid[] := array[]::uuid[];
  v_milk uuid; v_tea uuid; v_coffee uuid; v_price integer; v_cash integer := 0; v_paid timestamptz;
  r record;
begin
  if v_owner_email = 'THAY_BANG_EMAIL_TAI_KHOAN_CHU' then
    raise exception 'Hãy sửa v_owner_email (khối quán thứ hai) giống khối trên.';
  end if;
  select id into v_uid from auth.users where lower(email) = lower(v_owner_email) limit 1;
  if v_uid is null then raise exception 'Không tìm thấy tài khoản Auth có email %.', v_owner_email; end if;
  if exists (select 1 from shops where created_by = v_uid and name = '[DEMO] Fore Thảo Điền') then
    raise exception 'Quán demo thứ hai đã tồn tại.';
  end if;
  v_today := (now() at time zone v_tz)::date;
  v_today := case when extract(hour from now() at time zone v_tz) < 7 then v_today - 1 else v_today end;

  insert into shops (name, created_by) values ('[DEMO] Fore Thảo Điền', v_uid) returning id into v_shop;
  update shops set legal_name = 'Công ty TNHH Fore Thảo Điền', tax_code = '0312345678-001', phone = '84283898765',
         address = '45 Xuân Thủy, Thảo Điền, TP. Thủ Đức', open_time = '07:00', close_time = '22:30'
   where id = v_shop;
  insert into staff (shop_id, auth_user_id, full_name, role) values (v_shop, v_uid, 'Minh Anh', 'owner') returning id into v_owner;
  insert into staff (shop_id, full_name, role, job_role) values (v_shop, 'Khánh Vy', 'staff', 'cashier') returning id into v_staff;

  insert into areas (shop_id, name, sort_order) values (v_shop, 'Trong nhà', 1) returning id into v_area;
  for v_i in 1..5 loop
    insert into dining_tables (shop_id, area_id, name, seats, sort_order) values (v_shop, v_area, 'T' || v_i, 2 + (v_i % 3) * 2, v_i)
    returning id into v_table;
  end loop;

  insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty, unit_cost)
  values (v_shop, 'Sữa tươi', 'Sữa', 'ml', 'important', 5000, 33) returning id into v_milk;
  insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty, unit_cost)
  values (v_shop, 'Trà đen', 'Trà', 'g', 'important', 1000, 245) returning id into v_tea;
  insert into ingredients (shop_id, name, group_name, unit, importance, min_stock_qty, unit_cost)
  values (v_shop, 'Cà phê Robusta', 'Cà phê', 'g', 'important', 1500, 285) returning id into v_coffee;

  for r in select * from (values ('Cà phê sữa đá', 'Cà phê', 29000, v_coffee, 18, v_milk, 25),
                                  ('Trà sữa truyền thống', 'Trà sữa', 35000, v_tea, 15, v_milk, 50)) as t(item, grp, price, i1, q1, i2, q2) loop
    insert into menu_items (shop_id, name, group_name) values (v_shop, r.item, r.grp) returning id into v_item;
    insert into menu_sizes (shop_id, item_id, size_name, price) values (v_shop, v_item, 'M', r.price) returning id into v_size;
    insert into recipe_lines (shop_id, size_id, ingredient_id, qty) values (v_shop, v_size, r.i1, r.q1), (v_shop, v_size, r.i2, r.q2);
    v_sizes := v_sizes || v_size;
  end loop;

  -- Một ca hôm qua, đã đóng: 18 hóa đơn
  v_start := (((v_today - 1) + time '07:00') at time zone v_tz);
  insert into shifts (shop_id, opened_by, opened_at, closed_by, closed_at, opening_cash, closing_cash, status)
  values (v_shop, v_staff, v_start, v_staff, v_start + interval '14 hours', 500000, 500000, 'closed') returning id into v_shift;
  insert into stock_counts (shop_id, shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
  values (v_shop, v_shift, v_milk, 'open', 15000, v_staff, v_start + interval '1 minute'),
         (v_shop, v_shift, v_tea, 'open', 3000, v_staff, v_start + interval '1 minute'),
         (v_shop, v_shift, v_coffee, 'open', 4000, v_staff, v_start + interval '1 minute');
  for v_i in 1..18 loop
    v_size := v_sizes[1 + (v_i % 2)];
    select price into v_price from menu_sizes where id = v_size;
    v_paid := v_start + interval '30 minutes' + make_interval(mins => v_i * 40);
    insert into bills (shop_id, shift_id, bill_type, status, opened_by, opened_at, paid_by, paid_at, payment_method, total_amount)
    values (v_shop, v_shift, 'take_away', 'paid', v_staff, v_paid - interval '3 minutes', v_staff, v_paid, 'cash', v_price)
    returning id into v_bill;
    insert into bill_lines (shop_id, bill_id, size_id, qty, unit_price, created_by, created_at)
    values (v_shop, v_bill, v_size, 1, v_price, v_staff, v_paid - interval '3 minutes');
    insert into stock_ledger (shop_id, at, shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
    select v_shop, v_paid, v_shift, ingredient_id, 'sale', -qty, v_bill, v_staff from recipe_lines where size_id = v_size;
    v_cash := v_cash + v_price;
  end loop;
  insert into stock_counts (shop_id, shift_id, ingredient_id, kind, counted_qty, counted_by, counted_at)
  select v_shop, v_shift, i.id, 'close',
         greatest(case i.name when 'Sữa tươi' then 15000 when 'Trà đen' then 3000 else 4000 end
                  + 0 - coalesce((select -sum(qty_delta) from stock_ledger where shift_id = v_shift and ingredient_id = i.id), 0)::integer, 0),
         v_staff, v_start + interval '13 hours 59 minutes'
    from ingredients i where i.shop_id = v_shop;
  update shifts set closing_cash = 500000 + v_cash where id = v_shift;

  raise notice 'Đã tạo quán [DEMO] Fore Thảo Điền (%).', v_shop;
end
$seed2$;
