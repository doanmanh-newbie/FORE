-- Fore canonical install module: 01_schema.sql
-- Run modules in numeric order after database/dev/reset_schema.sql on a test project.

-- >>> Integrated source: database/001_tables.sql
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
