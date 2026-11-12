-- Fore · 01_foundation.sql
-- Grouped install module. Apply after the previous numbered module.
-- Generated from the former ordered SQL sources; preserve source order within this file.

-- >>> 001_tables.sql
-- =====================================================================
-- Fore · 001_tables.sql · Các bảng và ràng buộc (NHIỀU QUÁN: mọi dữ liệu nghiệp vụ có shop_id)
-- Chạy trên Supabase (PostgreSQL 15+). Chạy file này TRƯỚC.
-- Quy ước: id = UUID không mã hóa ý nghĩa; tiền = số nguyên (đồng);
--          định lượng = số nguyên theo đơn vị gốc (ml, g, piece).
-- =====================================================================

create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

-- ---------- Quán, nhân sự, lời mời ----------
-- Một người (một tài khoản đăng nhập) có thể thuộc NHIỀU quán: mỗi quán là một dòng trong bảng staff
-- (staff = "tư cách thành viên của quán"; tên hiển thị và vai trò là RIÊNG từng quán).
create table shops (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(btrim(name)) >= 1),
  created_by  uuid,                                -- auth.users.id của người tạo quán
  created_at  timestamptz not null default now()
);

create table staff (
  id            uuid primary key default gen_random_uuid(),
  shop_id       uuid not null references shops(id),
  auth_user_id  uuid,                              -- liên kết tài khoản đăng nhập Supabase Auth (null: nhân sự mô phỏng)
  full_name     text not null,                     -- tên hiển thị trong quán này
  birth_date    date,                               -- ngày sinh nhân viên (có thể null với hồ sơ cũ/chủ quán)
  role          text not null check (role in ('owner','staff')),
  pin_hash      text,                              -- PIN đã băm (bcrypt), không bao giờ lưu PIN thô
  active        boolean not null default true,     -- không xóa, chỉ ẩn
  created_at    timestamptz not null default now(),
  unique (shop_id, auth_user_id),
  unique (shop_id, id)
);
create index staff_user_idx on staff (auth_user_id) where active;

-- Quán đang chọn của mỗi người (người thuộc nhiều quán chọn quán nào thì app làm việc với quán đó)
create table user_settings (
  auth_user_id    uuid primary key,
  active_shop_id  uuid references shops(id)
);

-- Lời mời vào quán: chủ nhập SỐ ĐIỆN THOẠI (có thể thêm email) của nhân viên.
-- Người nhận thấy lời mời trong hộp thư của app khi đăng nhập bằng số điện thoại/email ĐÃ XÁC THỰC khớp.
create table shop_invites (
  id                uuid primary key default gen_random_uuid(),
  shop_id           uuid not null references shops(id),
  phone             text not null,                 -- đã chuẩn hóa (chỉ chữ số, đầu số quốc gia): 84901234567
  email             text,                          -- không bắt buộc; viết thường
  full_name         text not null check (char_length(btrim(full_name)) >= 1),
  status            text not null default 'pending' check (status in ('pending','accepted','declined','cancelled')),
  invited_by        uuid not null references staff(id),
  created_at        timestamptz not null default now(),
  responded_at      timestamptz,
  accepted_user_id  uuid
);
create unique index one_pending_invite on shop_invites (shop_id, phone) where status = 'pending';
create index invites_phone_idx on shop_invites (phone) where status = 'pending';

-- ---------- Hàm xác định "tôi là ai, đang ở quán nào" (dùng làm giá trị mặc định shop_id) ----------
create or replace function app_shop_id() returns uuid
language sql stable security definer set search_path = public as $$
  select coalesce(
    (select s.shop_id from user_settings u
       join staff s on s.shop_id = u.active_shop_id and s.auth_user_id = u.auth_user_id and s.active
      where u.auth_user_id = auth.uid()),
    (select s.shop_id from staff s where s.auth_user_id = auth.uid() and s.active
      order by s.created_at, s.id limit 1))
$$;

create or replace function app_staff_id() returns uuid
language sql stable security definer set search_path = public as $$
  select id from staff where auth_user_id = auth.uid() and active and shop_id = app_shop_id()
$$;

create or replace function app_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from staff where auth_user_id = auth.uid() and active and role = 'owner'
                    and shop_id = app_shop_id())
$$;

-- ---------- Nguyên liệu, món, công thức ----------
create table ingredients (
  id           uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  name         text not null,
  group_name   text,                               -- nhóm (topping, sữa, trà...) tách riêng khỏi id
  unit         text not null check (unit in ('ml','g','piece')),
  importance   text not null default 'normal' check (importance in ('important','normal')),
  weekly_check boolean not null default false,     -- chỉ cần kiểm theo tuần (đường, muối...)
  warn_pct     numeric(5,2) check (warn_pct  >= 0), -- ngưỡng riêng (để trống = dùng mặc định theo importance)
  alert_pct    numeric(5,2) check (alert_pct >= 0),
  min_abs_qty  integer not null default 0 check (min_abs_qty >= 0),  -- lệch tuyệt đối dưới mức này (đơn vị gốc) thì KHÔNG cảnh báo; 0 = tắt
  min_stock_qty integer not null default 0 check (min_stock_qty >= 0), -- ngưỡng tồn thấp; 0 = tắt
  active       boolean not null default true,
  created_at   timestamptz not null default now(),
  unique (shop_id, id),
  check (warn_pct is null or alert_pct is null or warn_pct <= alert_pct)
);
-- Chống trùng tên gần giống nhau (không phân biệt hoa thường, bỏ khoảng trắng thừa)
create unique index ingredients_name_uq on ingredients (shop_id, lower(btrim(name)));

create table menu_items (
  id          uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  name        text not null,
  group_name  text,
  active      boolean not null default true,
  created_at  timestamptz not null default now(),
  unique (shop_id, id)
);
create unique index menu_items_name_uq on menu_items (shop_id, lower(btrim(name)));

-- Mỗi size có giá riêng và công thức riêng
create table menu_sizes (
  id          uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  item_id     uuid not null references menu_items(id),
  size_name   text not null,
  price       integer not null check (price >= 0),  -- đồng
  active      boolean not null default true,
  unique (item_id, size_name),
  unique (shop_id, id)
);

create table recipe_lines (
  id             uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  size_id        uuid not null references menu_sizes(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),  -- theo đơn vị gốc của nguyên liệu
  unique (size_id, ingredient_id)
);

-- ---------- Khu vực và bàn (do người dùng tự tạo) ----------
create table areas (
  id      uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  name    text not null,
  active  boolean not null default true,
  unique (shop_id, name),
  unique (shop_id, id)
);

create table dining_tables (
  id       uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  area_id  uuid not null references areas(id),
  name     text not null,
  active   boolean not null default true,
  unique (area_id, name),
  unique (shop_id, id)
);

-- ---------- Ca làm việc ----------
create table shifts (
  id            uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  opened_by     uuid not null references staff(id),
  opened_at     timestamptz not null default now(),   -- giờ máy chủ, không lấy giờ điện thoại
  closed_by     uuid references staff(id),
  closed_at     timestamptz,
  opening_cash  integer not null default 0 check (opening_cash >= 0),
  closing_cash  integer check (closing_cash >= 0),
  status        text not null default 'open' check (status in ('open','closed')),
  constraint shifts_closed_requires_cash
    check (status <> 'closed' or closing_cash is not null),
  unique (shop_id, id)
);
-- Tại một thời điểm, MỖI QUÁN chỉ có tối đa 1 ca đang mở
create unique index one_open_shift on shifts (shop_id) where status = 'open';
create index shifts_shop_time on shifts (shop_id, opened_at desc);   -- danh sách ca, ca trước (đối soát)

-- ---------- Hóa đơn ----------
create table bills (
  id               uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  bill_no          bigint generated always as identity,  -- số bill tuần tự, không bị nhảy tay
  shift_id         uuid not null references shifts(id),
  table_id         uuid references dining_tables(id),
  bill_type        text not null check (bill_type in ('dine_in','take_away')),
  guests           integer check (guests > 0),
  status           text not null default 'open' check (status in ('open','paid','cancelled')),
  opened_by        uuid not null references staff(id),
  opened_at        timestamptz not null default now(),
  paid_by          uuid references staff(id),
  paid_at          timestamptz,
  payment_method   text check (payment_method in ('cash','transfer')),
  discount         integer not null default 0 check (discount >= 0),
  discount_reason  text,
  total_amount     integer check (total_amount >= 0),     -- chốt lúc thanh toán
  cancelled_by     uuid references staff(id),
  cancelled_at     timestamptz,
  cancel_reason    text,
  approved_by      uuid references staff(id),             -- chủ xác nhận bằng PIN khi hủy bill đã thu tiền
  prep_done_at     timestamptz,                           -- đơn mang đi: đã làm xong chưa
  check (bill_type <> 'dine_in' or table_id is not null),
  check (status <> 'cancelled' or cancel_reason is not null),
  constraint paid_bill_requires_payment_details
    check (status <> 'paid' or
           (payment_method is not null and total_amount is not null
            and paid_at is not null and paid_by is not null)),
  unique (shop_id, id)
);
create unique index bills_bill_no_uq on bills (bill_no);
-- CHỐNG 2 MÁY CÙNG MỞ/THANH TOÁN 1 BÀN: mỗi bàn chỉ có tối đa 1 bill đang mở
create unique index one_open_bill_per_table on bills (table_id)
  where status = 'open' and table_id is not null;
create index bills_shift_idx on bills (shift_id);

create table bill_lines (
  id           uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  bill_id      uuid not null references bills(id),
  size_id      uuid not null references menu_sizes(id),
  qty          integer not null check (qty > 0),
  unit_price   integer not null check (unit_price >= 0),  -- giá tại thời điểm bán (không tính lại)
  created_at   timestamptz not null default now(),
  created_by   uuid references staff(id),
  voided_at    timestamptz,                               -- không xóa dòng, chỉ đánh dấu hủy
  voided_by    uuid references staff(id),
  void_reason  text,
  check (voided_at is null or void_reason is not null)
);
create index bill_lines_bill_idx on bill_lines (bill_id);

-- ---------- Kho: nhập, đếm, hao hụt, sổ kho ----------
create table purchases (
  id             uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),
  is_late_entry  boolean not null default false,          -- "nhập bù" (viết giấy rồi nhập lại)
  note           text,
  entered_by     uuid references staff(id),
  entered_at     timestamptz not null default now()
);

create table stock_counts (                               -- kiểm kê (đếm mù)
  id             uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  kind           text not null check (kind in ('open','close')),
  counted_qty    integer not null check (counted_qty >= 0),
  counted_by     uuid references staff(id),
  counted_at     timestamptz not null default now()
);
create index stock_counts_lookup on stock_counts (shift_id, ingredient_id, kind, counted_at desc);

-- ---------- Cấu hình: công thức nằm trong code, CON SỐ nằm ở đây để chủ quán chỉnh ----------
create table app_settings (
  shop_id     uuid not null default app_shop_id() references shops(id),
  key         text not null,
  value_int   integer not null,
  description text,
  primary key (shop_id, key)
);

-- Loại hao hụt: chỉ là NHÃN nên để thành bảng (chủ thêm/đổi tên/ẩn được, mã code không đổi)
create table waste_types (
  shop_id       uuid not null default app_shop_id() references shops(id),
  code          text not null,
  label_vi      text not null,
  requires_note boolean not null default false,   -- loại này bắt buộc ghi chú (ví dụ "khác")
  active        boolean not null default true,    -- không xóa, chỉ ẩn
  sort_order    integer not null default 0,
  primary key (shop_id, code)
);

-- Mỗi quán mới được tạo sẵn cấu hình và loại hao hụt mặc định (số TẠM, chủ chỉnh theo quán thật)
create or replace function _seed_shop(p_shop uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  insert into app_settings (shop_id, key, value_int, description) values
    (p_shop, 'important_warn_pct',    3, 'Nguyên liệu quan trọng: lệch từ mức % này trở lên thì cảnh báo vàng (TẠM, chỉnh theo quán thật)'),
    (p_shop, 'important_alert_pct',   5, 'Nguyên liệu quan trọng: lệch từ mức % này trở lên thì cảnh báo đỏ'),
    (p_shop, 'normal_warn_pct',      10, 'Nguyên liệu thường: cảnh báo vàng từ mức % này'),
    (p_shop, 'normal_alert_pct',     15, 'Nguyên liệu thường: cảnh báo đỏ từ mức % này'),
    (p_shop, 'waste_warn_pct',       10, 'Hao hụt có lý do vượt mức % này so với lượng dùng lý thuyết thì cảnh báo'),
    (p_shop, 'cash_warn_vnd',     20000, 'Lệch tiền mặt từ mức này (đồng): cảnh báo vàng'),
    (p_shop, 'cash_alert_vnd',    50000, 'Lệch tiền mặt từ mức này (đồng): cảnh báo đỏ'),
    (p_shop, 'opening_diff_warn_vnd', 1000, 'Tiền đầu ca lệch so với tiền cuối ca trước từ mức này (đồng): đáng chú ý'),
    (p_shop, 'recount_flag_after',    2, 'Một nguyên liệu bị đếm lại quá số lần này trong 1 ca thì đưa vào danh sách cần chú ý'),
    (p_shop, 'streak_shifts',         3, 'Số ca LIÊN TIẾP lệch cùng chiều (vàng/đỏ) thì gắn cờ xu hướng trong shift_report (tối thiểu 2)'),
    (p_shop, 'pin_max_attempts',      3, 'Số lần nhập sai PIN chủ liên tiếp thì khóa'),
    (p_shop, 'pin_lock_minutes',     15, 'Số phút khóa PIN sau khi sai quá số lần')
  on conflict do nothing;
  insert into waste_types (shop_id, code, label_vi, requires_note, sort_order) values
    (p_shop, 'expired',    'Đổ bỏ (quá giờ/hết hạn)', false, 1),
    (p_shop, 'mistake',    'Làm sai, đổ ly',          false, 2),
    (p_shop, 'staff_meal', 'Cho nhân viên dùng',       false, 3),
    (p_shop, 'tasting',    'Thử vị',                   false, 4),
    (p_shop, 'other',      'Khác (ghi chú rõ)',        true,  9)
  on conflict do nothing;
end $$;

create or replace function shops_seed_trg() returns trigger
language plpgsql security definer set search_path = public as $$
begin perform _seed_shop(new.id); return new; end $$;
create trigger shops_seed after insert on shops for each row execute function shops_seed_trg();

create table waste_logs (                                 -- hao hụt có lý do (đổ, làm sai, thử vị...)
  id             uuid primary key default gen_random_uuid(),
  shop_id uuid not null default app_shop_id() references shops(id),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  qty            integer not null check (qty > 0),
  reason_type    text not null default 'other',                                  -- loại (chọn từ danh sách waste_types của quán)
  reason         text not null,                                                  -- ghi chú (mặc định là tên loại)
  entered_by     uuid references staff(id),
  entered_at     timestamptz not null default now(),
  foreign key (shop_id, reason_type) references waste_types (shop_id, code)
);

-- SỔ KHO: mỗi lần nhập, bán, hao hụt là 1 dòng. Tồn kho = tổng các dòng.
create table stock_ledger (
  id             bigint generated always as identity primary key,
  shop_id uuid not null default app_shop_id() references shops(id),
  at             timestamptz not null default now(),
  shift_id       uuid not null references shifts(id),
  ingredient_id  uuid not null references ingredients(id),
  kind           text not null check (kind in ('purchase','sale','void_sale','waste')),
  qty_delta      integer not null check (qty_delta <> 0), -- nhập: +; bán/hao hụt: -; hủy bill: +
  ref_id         uuid,                                    -- bill_id hoặc id phiếu nhập/hao hụt
  created_by     uuid references staff(id)
);
create index stock_ledger_ing_at on stock_ledger (ingredient_id, at);
create index stock_ledger_shift on stock_ledger (shift_id, kind);

-- ---------- Nhật ký và PIN ----------
create table audit_log (
  id         bigint generated always as identity primary key,
  shop_id uuid not null default app_shop_id() references shops(id),
  at         timestamptz not null default now(),
  actor      uuid,
  action     text not null,
  entity     text not null,
  entity_id  uuid,
  detail     jsonb
);
create index if not exists audit_log_shop_feed_idx
  on audit_log (shop_id, at desc, id desc);

create table pin_attempts (
  id        bigint generated always as identity primary key,
  shop_id uuid not null default app_shop_id() references shops(id),
  at        timestamptz not null default now(),
  staff_id  uuid not null references staff(id),
  ok        boolean not null
);
create index pin_attempts_lookup on pin_attempts (staff_id, at desc);

-- UUID vẫn là khóa chính toàn cục; các khóa ghép này buộc quan hệ nghiệp vụ
-- luôn trỏ tới bản ghi cùng quán, kể cả khi có lệnh ghi trực tiếp vào bảng.
alter table shop_invites add constraint shop_invites_inviter_same_shop_fk
  foreign key (shop_id, invited_by) references staff (shop_id, id);
alter table menu_sizes add constraint menu_sizes_item_same_shop_fk
  foreign key (shop_id, item_id) references menu_items (shop_id, id);
alter table recipe_lines add constraint recipe_lines_size_same_shop_fk
  foreign key (shop_id, size_id) references menu_sizes (shop_id, id);
alter table recipe_lines add constraint recipe_lines_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table dining_tables add constraint dining_tables_area_same_shop_fk
  foreign key (shop_id, area_id) references areas (shop_id, id);
alter table shifts add constraint shifts_opened_by_same_shop_fk
  foreign key (shop_id, opened_by) references staff (shop_id, id);
alter table shifts add constraint shifts_closed_by_same_shop_fk
  foreign key (shop_id, closed_by) references staff (shop_id, id);
alter table bills add constraint bills_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table bills add constraint bills_table_same_shop_fk
  foreign key (shop_id, table_id) references dining_tables (shop_id, id);
alter table bills add constraint bills_opened_by_same_shop_fk
  foreign key (shop_id, opened_by) references staff (shop_id, id);
alter table bills add constraint bills_paid_by_same_shop_fk
  foreign key (shop_id, paid_by) references staff (shop_id, id);
alter table bills add constraint bills_cancelled_by_same_shop_fk
  foreign key (shop_id, cancelled_by) references staff (shop_id, id);
alter table bills add constraint bills_approved_by_same_shop_fk
  foreign key (shop_id, approved_by) references staff (shop_id, id);
alter table bill_lines add constraint bill_lines_bill_same_shop_fk
  foreign key (shop_id, bill_id) references bills (shop_id, id);
alter table bill_lines add constraint bill_lines_size_same_shop_fk
  foreign key (shop_id, size_id) references menu_sizes (shop_id, id);
alter table bill_lines add constraint bill_lines_created_by_same_shop_fk
  foreign key (shop_id, created_by) references staff (shop_id, id);
alter table bill_lines add constraint bill_lines_voided_by_same_shop_fk
  foreign key (shop_id, voided_by) references staff (shop_id, id);
alter table purchases add constraint purchases_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table purchases add constraint purchases_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table purchases add constraint purchases_entered_by_same_shop_fk
  foreign key (shop_id, entered_by) references staff (shop_id, id);
alter table stock_counts add constraint stock_counts_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table stock_counts add constraint stock_counts_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table stock_counts add constraint stock_counts_counted_by_same_shop_fk
  foreign key (shop_id, counted_by) references staff (shop_id, id);
alter table waste_logs add constraint waste_logs_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table waste_logs add constraint waste_logs_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table waste_logs add constraint waste_logs_entered_by_same_shop_fk
  foreign key (shop_id, entered_by) references staff (shop_id, id);
alter table stock_ledger add constraint stock_ledger_shift_same_shop_fk
  foreign key (shop_id, shift_id) references shifts (shop_id, id);
alter table stock_ledger add constraint stock_ledger_ingredient_same_shop_fk
  foreign key (shop_id, ingredient_id) references ingredients (shop_id, id);
alter table stock_ledger add constraint stock_ledger_created_by_same_shop_fk
  foreign key (shop_id, created_by) references staff (shop_id, id);
alter table audit_log add constraint audit_log_actor_same_shop_fk
  foreign key (shop_id, actor) references staff (shop_id, id);
alter table pin_attempts add constraint pin_attempts_staff_same_shop_fk
  foreign key (shop_id, staff_id) references staff (shop_id, id);


-- >>> 002_rules.sql
-- =====================================================================
-- Fore · 002_rules.sql · Luật bảo vệ dữ liệu
--  1) Bảng nhật ký/sổ kho CHỈ THÊM, không sửa/xóa (trigger chặn cả quản trị viên)
--  2) Nhật ký tự động cho thay đổi cấu hình (giá, công thức, nhân sự...)
--  3) Phân quyền theo vai trò bằng RLS + chỉ cấp quyền tối thiểu
--  Có hàm _setting(): đọc một con số cấu hình từ app_settings (các hàm sau dùng chung).
-- Chạy SAU 001_tables.sql.
-- =====================================================================

-- ---------- Hàm hỗ trợ ----------
-- (app_shop_id / app_staff_id / app_is_owner nằm ở 001_tables.sql vì cột shop_id dùng làm giá trị mặc định)

-- Con số cấu hình của quán (p_shop để trống = quán đang chọn của người gọi)
create or replace function _setting(p_key text, p_default integer, p_shop uuid default null) returns integer
language sql stable security definer set search_path = public as $$
  select coalesce((select value_int from app_settings
                    where key = p_key and shop_id = coalesce(p_shop, app_shop_id())), p_default)
$$;

-- ---------- 1) Chỉ thêm, không sửa/xóa ----------
create or replace function prevent_mutation() returns trigger
language plpgsql as $$
begin
  raise exception 'Bảng % chỉ được thêm dòng mới, không được sửa hoặc xóa', tg_table_name
    using errcode = '42501';
end $$;

create trigger no_change_stock_ledger before update or delete on stock_ledger for each row execute function prevent_mutation();
create trigger no_change_stock_counts before update or delete on stock_counts for each row execute function prevent_mutation();
create trigger no_change_purchases    before update or delete on purchases    for each row execute function prevent_mutation();
create trigger no_change_waste_logs   before update or delete on waste_logs   for each row execute function prevent_mutation();
create trigger no_change_audit_log    before update or delete on audit_log    for each row execute function prevent_mutation();
create trigger no_change_pin_attempts before update or delete on pin_attempts for each row execute function prevent_mutation();

-- Không xóa các bảng có lịch sử (chỉ ẩn bằng active / đổi trạng thái)
create or replace function prevent_delete() returns trigger
language plpgsql as $$
begin
  raise exception 'Không xóa dữ liệu bảng %. Hãy ẩn (active=false) hoặc đổi trạng thái', tg_table_name
    using errcode = '42501';
end $$;

create trigger no_delete_bills         before delete on bills         for each row execute function prevent_delete();
create trigger no_delete_bill_lines    before delete on bill_lines    for each row execute function prevent_delete();
create trigger no_delete_shifts        before delete on shifts        for each row execute function prevent_delete();
create trigger no_delete_shops         before delete on shops         for each row execute function prevent_delete();
create trigger no_delete_staff         before delete on staff         for each row execute function prevent_delete();
create trigger no_delete_ingredients   before delete on ingredients   for each row execute function prevent_delete();
create trigger no_delete_menu_items    before delete on menu_items    for each row execute function prevent_delete();
create trigger no_delete_menu_sizes    before delete on menu_sizes    for each row execute function prevent_delete();
create trigger no_delete_areas         before delete on areas         for each row execute function prevent_delete();
create trigger no_delete_dining_tables before delete on dining_tables for each row execute function prevent_delete();
create trigger no_delete_waste_types   before delete on waste_types   for each row execute function prevent_delete();

-- Hóa đơn: chỉ cho phép chuyển trạng thái hợp lệ, không đổi các trường gốc
create or replace function bills_guard() returns trigger
language plpgsql as $$
begin
  if new.id <> old.id or new.bill_no <> old.bill_no or new.shift_id <> old.shift_id
     or new.table_id is distinct from old.table_id or new.bill_type <> old.bill_type
     or new.opened_at <> old.opened_at or new.opened_by <> old.opened_by then
    raise exception 'Không được sửa thông tin gốc của bill' using errcode = '42501';
  end if;
  if new.status <> old.status and not (
       (old.status = 'open' and new.status in ('paid','cancelled')) or
       (old.status = 'paid' and new.status = 'cancelled')) then
    raise exception 'Chuyển trạng thái bill không hợp lệ: % -> %', old.status, new.status using errcode = '42501';
  end if;
  if old.status = 'cancelled' then
    raise exception 'Bill đã hủy không được sửa' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger bills_guard_trg before update on bills for each row execute function bills_guard();

-- Dòng bill: chỉ được đánh dấu hủy, không đổi số lượng/giá/món
create or replace function bill_lines_guard() returns trigger
language plpgsql as $$
begin
  if new.id <> old.id or new.bill_id <> old.bill_id or new.size_id <> old.size_id
     or new.qty <> old.qty or new.unit_price <> old.unit_price or old.voided_at is not null then
    raise exception 'Dòng bill chỉ được đánh dấu hủy, không được sửa' using errcode = '42501';
  end if;
  return new;
end $$;
create trigger bill_lines_guard_trg before update on bill_lines for each row execute function bill_lines_guard();

-- ---------- 2) Nhật ký thay đổi cấu hình ----------
create or replace function audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_old jsonb; v_new jsonb;
begin
  if tg_op in ('UPDATE','DELETE') then v_old := to_jsonb(old) - 'pin_hash'; end if;
  if tg_op in ('INSERT','UPDATE') then v_new := to_jsonb(new) - 'pin_hash'; end if;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
  values (coalesce((v_new->>'shop_id')::uuid, (v_old->>'shop_id')::uuid, app_shop_id()),
          app_staff_id(), lower(tg_op), tg_table_name,
          coalesce(v_new->>'id', v_old->>'id')::uuid,
          jsonb_build_object('old', v_old, 'new', v_new));
  return coalesce(new, old);
end $$;

create trigger audit_staff         after insert or update or delete on staff         for each row execute function audit_row_change();
create trigger audit_ingredients   after insert or update or delete on ingredients   for each row execute function audit_row_change();
create trigger audit_menu_items    after insert or update or delete on menu_items    for each row execute function audit_row_change();
create trigger audit_menu_sizes    after insert or update or delete on menu_sizes    for each row execute function audit_row_change();
-- Công thức của size ĐÃ TỪNG BÁN thì không được sửa/xóa/thêm dòng: số ly và tiền ước tính của các ca cũ
-- (reconcile_shift) tính theo công thức, đổi công thức sẽ làm sai quá khứ.
-- Muốn đổi: ẩn size cũ (menu_sizes.active = false) và tạo size mới với công thức mới.
create or replace function recipe_lines_guard() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  -- Chỉ hàm kích hoạt phiên bản công thức (_recipe_activate) được bật cờ này để thay công thức theo lịch
  if current_setting('fore.recipe_apply', true) = 'on' then
    return case when tg_op = 'DELETE' then old else new end;
  end if;
  if exists (select 1 from bill_lines
              where size_id in (case when tg_op = 'INSERT' then new.size_id else old.size_id end,
                                case when tg_op = 'UPDATE' then new.size_id else old.size_id end)) then
    raise exception 'RECIPE_IN_USE';
  end if;
  return case when tg_op = 'DELETE' then old else new end;
end $$;
create trigger recipe_lines_guard before insert or update or delete on recipe_lines
  for each row execute function recipe_lines_guard();

create trigger audit_recipe_lines  after insert or update or delete on recipe_lines  for each row execute function audit_row_change();
create trigger audit_areas         after insert or update or delete on areas         for each row execute function audit_row_change();
create trigger audit_dining_tables after insert or update or delete on dining_tables for each row execute function audit_row_change();
create trigger audit_waste_types   after insert or update or delete on waste_types   for each row execute function audit_row_change();
create trigger audit_app_settings  after update on app_settings for each row execute function audit_row_change();

-- ---------- 3) Phân quyền (RLS) ----------
alter table shops          enable row level security;
alter table user_settings  enable row level security;
alter table shop_invites   enable row level security;
alter table staff          enable row level security;
alter table ingredients    enable row level security;
alter table menu_items     enable row level security;
alter table menu_sizes     enable row level security;
alter table recipe_lines   enable row level security;
alter table areas          enable row level security;
alter table dining_tables  enable row level security;
alter table shifts         enable row level security;
alter table bills          enable row level security;
alter table bill_lines     enable row level security;
alter table purchases      enable row level security;
alter table stock_counts   enable row level security;
alter table waste_logs     enable row level security;
alter table stock_ledger   enable row level security;
alter table audit_log      enable row level security;
alter table pin_attempts   enable row level security;
alter table app_settings   enable row level security;
alter table waste_types    enable row level security;

-- Thu hết quyền mặc định, rồi cấp lại tối thiểu
revoke all on all tables in schema public from anon, authenticated;
alter default privileges in schema public revoke all on tables from anon, authenticated;

-- Quán: thành viên xem quán mình thuộc; chủ quán đang chọn được đổi tên. Tạo quán qua create_shop().
create or replace function _my_shop_ids() returns setof uuid
language sql stable security definer set search_path = public as $$
  select shop_id from staff where auth_user_id = auth.uid() and active
$$;
revoke all on function _my_shop_ids() from public, anon;
grant execute on function _my_shop_ids() to authenticated;
grant select (id, name, created_at) on shops to authenticated;
grant update (name) on shops to authenticated;
create policy shops_read  on shops for select to authenticated using (id in (select _my_shop_ids()));
create policy shops_write on shops for update to authenticated
  using (id = (select app_shop_id()) and (select app_is_owner())) with check (id = (select app_shop_id()) and (select app_is_owner()));
-- user_settings: không cấp quyền trực tiếp (chọn quán qua select_shop()). Không policy nào = không ai đọc/ghi trực tiếp.

-- Lời mời: chủ của quán đang chọn xem được lời mời của quán. Người được mời đọc qua my_invites().
grant select on shop_invites to authenticated;
create policy shop_invites_owner_read on shop_invites for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Nhân sự: ai cũng xem được tên mình; chủ xem cả quán. KHÔNG cho đọc cột pin_hash.
-- Không cho thêm nhân sự trực tiếp: người vào quán chỉ qua create_shop() (chủ) hoặc accept_invite() (nhân viên chấp nhận lời mời).
grant select (id, shop_id, auth_user_id, full_name, role, active, created_at) on staff to authenticated;
grant update (full_name, role, active) on staff to authenticated;
create policy staff_read  on staff for select to authenticated
  using (shop_id = (select app_shop_id()) and ((select app_is_owner()) or auth_user_id = (select auth.uid())));
create policy staff_write on staff for update to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Cấu hình (nguyên liệu, menu, công thức, khu, bàn): nhân viên đọc, chủ ghi
grant select, insert, update on ingredients, menu_items, menu_sizes, areas, dining_tables to authenticated;
grant select, insert, update, delete on recipe_lines to authenticated;   -- sửa công thức = xóa/thêm dòng (có nhật ký)

create policy ingredients_read  on ingredients   for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy ingredients_write on ingredients   for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy menu_items_read   on menu_items    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy menu_items_write  on menu_items    for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy menu_sizes_read   on menu_sizes    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy menu_sizes_write  on menu_sizes    for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy recipe_lines_read  on recipe_lines  for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy recipe_lines_write on recipe_lines  for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy areas_read        on areas         for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy areas_write       on areas         for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy dining_tables_read  on dining_tables for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy dining_tables_write on dining_tables for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Thiết lập và loại hao hụt: nhân viên đọc, chủ ghi. Thiết lập chỉ được sửa GIÁ TRỊ (không đổi tên khóa, không xóa).
grant select on app_settings to authenticated;
grant update (value_int) on app_settings to authenticated;
create policy app_settings_read  on app_settings for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy app_settings_write on app_settings for update to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));
grant select, insert on waste_types to authenticated;
grant update (label_vi, requires_note, active, sort_order) on waste_types to authenticated;
create policy waste_types_read  on waste_types for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy waste_types_write on waste_types for all    to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner())) with check (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- Bán hàng: nhân viên chỉ ĐỌC trực tiếp. Mọi thao tác ghi đi qua hàm trong 003_actions.sql
grant select on shifts, bills, bill_lines to authenticated;
create policy shifts_read     on shifts     for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy bills_read      on bills      for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);
create policy bill_lines_read on bill_lines for select to authenticated using (shop_id = (select app_shop_id()) and (select app_staff_id()) is not null);

-- Kho và nhật ký: CHỈ CHỦ ĐỌC (để nhân viên không thấy số tồn dự kiến khi đếm mù)
grant select on purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts to authenticated;
create policy purchases_owner_read    on purchases    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy stock_counts_owner_read on stock_counts for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy waste_logs_owner_read   on waste_logs   for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy stock_ledger_owner_read on stock_ledger for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy audit_log_owner_read    on audit_log    for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));
create policy pin_attempts_owner_read on pin_attempts for select to authenticated using (shop_id = (select app_shop_id()) and (select app_is_owner()));

-- ---------- Quyền chạy hàm hỗ trợ (dùng trong policy) ----------
revoke all on function app_shop_id(), app_staff_id(), app_is_owner() from public, anon;
grant execute on function app_shop_id(), app_staff_id(), app_is_owner() to authenticated;


-- >>> 003_actions.sql
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

create or replace function add_bill_line(p_bill uuid, p_size uuid, p_qty integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_status text; v_price integer; v_id uuid;
begin
  select status into v_status from bills where id = p_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  perform _menu_apply_due();     -- giá đã hẹn tới giờ thì áp dụng trước khi lấy giá
  select ms.price into v_price
    from menu_sizes ms join menu_items mi on mi.id = ms.item_id
   where ms.id = p_size and ms.active and mi.active and not mi.is_draft and ms.shop_id = app_shop_id();
  if v_price is null then raise exception 'ITEM_UNAVAILABLE'; end if;
  insert into bill_lines (bill_id, size_id, qty, unit_price, created_by)
  values (p_bill, p_size, p_qty, v_price, v_me) returning id into v_id;
  return v_id;
end $$;

create or replace function void_bill_line(p_line uuid, p_reason text) returns void
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_bill uuid; v_status text;
begin
  if coalesce(btrim(p_reason), '') = '' then raise exception 'REASON_REQUIRED'; end if;
  select bill_id into v_bill from bill_lines where id = p_line and shop_id = app_shop_id();
  select status into v_status from bills where id = v_bill and shop_id = app_shop_id() for update;
  if v_status is distinct from 'open' then raise exception 'BILL_NOT_OPEN'; end if;
  update bill_lines set voided_at = now(), voided_by = v_me, void_reason = p_reason
   where id = p_line and voided_at is null;
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

-- Thanh toán. Cập nhật có điều kiện: nếu máy khác đã thanh toán thì báo BILL_NOT_OPEN.
create or replace function pay_bill(p_bill uuid, p_method text default 'cash') returns integer
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_bill bills%rowtype; v_sub integer; v_total integer; v_n integer;
begin
  perform _menu_apply_due();     -- công thức/giá đã hẹn tới giờ thì áp dụng trước khi ghi sổ kho
  if p_method is null or p_method not in ('cash', 'transfer') then
    raise exception 'PAYMENT_METHOD_INVALID';
  end if;
  select * into v_bill from bills where id = p_bill and shop_id = app_shop_id() for update;
  if not found or v_bill.status <> 'open' then raise exception 'BILL_NOT_OPEN'; end if;

  select coalesce(sum(qty * unit_price), 0) into v_sub from bill_lines where bill_id = p_bill and voided_at is null;
  if v_sub = 0 then raise exception 'BILL_EMPTY'; end if;
  v_total := v_sub - v_bill.discount;

  update bills set status = 'paid', paid_at = now(), paid_by = v_me, payment_method = p_method, total_amount = v_total
   where id = p_bill and status = 'open';
  get diagnostics v_n = row_count;
  if v_n = 0 then raise exception 'BILL_NOT_OPEN'; end if;

  -- Ghi sổ kho: mỗi dòng bán x công thức tại THỜI ĐIỂM bán (đổi công thức sau này không làm lệch ca cũ)
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  select v_bill.shift_id, r.ingredient_id, 'sale', -sum(l.qty * r.qty)::integer, p_bill, v_me
    from bill_lines l join recipe_lines r on r.size_id = l.size_id
   where l.bill_id = p_bill and l.voided_at is null
   group by r.ingredient_id;

  perform _audit('pay', 'bills', p_bill, jsonb_build_object('total', v_total, 'method', p_method));
  return v_total;
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
create or replace function add_purchase(p_ingredient uuid, p_qty integer, p_late boolean default false, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  insert into purchases (shift_id, ingredient_id, qty, is_late_entry, note, entered_by)
  values (v_shift, p_ingredient, p_qty, p_late, p_note, v_me) returning id into v_id;
  insert into stock_ledger (shift_id, ingredient_id, kind, qty_delta, ref_id, created_by)
  values (v_shift, p_ingredient, 'purchase', p_qty, v_id, v_me);
  return v_id;
end $$;

-- Kiểm kê MÙ: nhân viên nhập số đo thực tế, hàm này không trả về số dự kiến.
create or replace function submit_stock_count(p_ingredient uuid, p_kind text, p_qty integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid;
begin
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  insert into stock_counts (shift_id, ingredient_id, kind, counted_qty, counted_by)
  values (v_shift, p_ingredient, p_kind, p_qty, v_me) returning id into v_id;
  return v_id;
end $$;

-- Hao hụt: phải CHỌN LOẠI trong bảng waste_types (+ ghi chú). Loại có requires_note thì bắt buộc ghi chú.
-- Nguyên liệu tính theo đơn vị gốc (trân châu: gram KHÔ quy đổi).
create or replace function add_waste(p_ingredient uuid, p_qty integer, p_type text, p_note text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_shift uuid := _open_shift_id(); v_id uuid; v_wt waste_types;
begin
  select * into v_wt from waste_types where code = p_type and active and shop_id = app_shop_id();

  if not found then raise exception 'WASTE_TYPE_INVALID'; end if;
  if v_wt.requires_note and char_length(btrim(coalesce(p_note, ''))) < 5 then
    raise exception 'NOTE_REQUIRED';
  end if;
  if not exists (select 1 from ingredients where id = p_ingredient and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  insert into waste_logs (shift_id, ingredient_id, qty, reason_type, reason, entered_by)
  values (v_shift, p_ingredient, p_qty, p_type, coalesce(nullif(btrim(p_note), ''), v_wt.label_vi), v_me)
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

