-- Fore · 08_settings.sql
-- Tab "Thêm" của chủ quán: vai trò và phân quyền theo quán, nhân sự (mời có vai trò, đổi vai trò, thu hồi),
-- hồ sơ quán, khu vực và bàn, nhật ký quản trị, yêu cầu hỗ trợ, tổng quan các quán.
-- Chạy SAU 07_inventory.sql. Chạy lại nhiều lần không hỏng (idempotent).
--
-- NGUYÊN TẮC
--   · KHÔNG đổi `staff.role` ('owner'|'staff'): mọi hàm cũ vẫn đúng. Vai trò chi tiết là cột MỚI `staff.job_role`
--     ('manager'|'cashier'|'staff'); chỉ hàm mới và vài hàm Kho (07) đọc nó. Mặc định 'staff' = ít quyền nhất.
--   · Chủ quán (role='owner') LUÔN có mọi quyền và không bao giờ bị hạ, thu hồi hay đổi vai trò.
--   · Chỉ liệt kê quyền ĐANG ĐƯỢC ÁP DỤNG ở database; quyền chưa có chỗ áp dụng thì chưa có công tắc.
--   · Quyền `members.manage` = xem danh sách, đổi vai trò, thu hồi. MỜI người mới vẫn chỉ chủ quán (invite_staff cũ là owner-only).
--   · Thu hồi không xóa lịch sử: staff.active = false, giữ nguyên mọi dòng cũ.
--   · Mọi thay đổi quản trị ghi vào audit_log kèm người thực hiện.

-- ======================================================================
-- 1) Mở rộng bảng có sẵn
-- ======================================================================
alter table staff add column if not exists job_role text not null default 'staff';
alter table staff drop constraint if exists staff_job_role_check;
alter table staff add constraint staff_job_role_check check (job_role in ('manager', 'cashier', 'staff'));
alter table staff add column if not exists deactivated_at timestamptz;

alter table shop_invites add column if not exists job_role text not null default 'staff';
alter table shop_invites drop constraint if exists shop_invites_job_role_check;
alter table shop_invites add constraint shop_invites_job_role_check check (job_role in ('manager', 'cashier', 'staff'));
alter table shop_invites add column if not exists expires_at timestamptz;
-- Lời mời đang chờ từ trước: cho thêm 7 ngày kể từ lúc cập nhật để không khóa người đã được mời
update shop_invites set expires_at = greatest(created_at + interval '7 days', now() + interval '7 days')
 where expires_at is null and status = 'pending';
update shop_invites set expires_at = created_at + interval '7 days' where expires_at is null;
alter table shop_invites alter column expires_at set default (now() + interval '7 days');
alter table shop_invites alter column expires_at set not null;

create sequence if not exists shop_code_seq;
alter table shops add column if not exists code text;
alter table shops add column if not exists legal_name text;
alter table shops add column if not exists tax_code text;
alter table shops add column if not exists email text;
alter table shops add column if not exists phone text;
alter table shops add column if not exists address text;
alter table shops add column if not exists open_daily boolean not null default true;
alter table shops add column if not exists open_time time not null default '06:00';
alter table shops add column if not exists close_time time not null default '22:00';
alter table shops add column if not exists timezone text not null default 'Asia/Ho_Chi_Minh';
update shops set code = 'Q' || lpad(nextval('shop_code_seq')::text, 4, '0') where code is null;
alter table shops alter column code set default ('Q' || lpad(nextval('shop_code_seq')::text, 4, '0'));
alter table shops alter column code set not null;
create unique index if not exists shops_code_uq on shops (code);

alter table dining_tables add column if not exists seats integer not null default 2 check (seats between 1 and 50);

-- ======================================================================
-- 2) Bảng mới
-- ======================================================================
create table if not exists role_permissions (
  shop_id     uuid not null references shops(id),
  job_role    text not null check (job_role in ('manager', 'cashier', 'staff')),
  permission  text not null,
  allowed     boolean not null default false,
  updated_by  uuid references staff(id),
  updated_at  timestamptz not null default now(),
  primary key (shop_id, job_role, permission)
);

create table if not exists support_requests (
  id           uuid primary key default gen_random_uuid(),
  shop_id      uuid not null default app_shop_id() references shops(id),
  code         text not null,
  topic        text not null check (topic in ('setup', 'printer', 'permissions', 'data', 'other')),
  message      text not null check (char_length(btrim(message)) between 5 and 2000),
  contact      text not null default 'in_app' check (contact in ('in_app', 'callback')),
  diagnostics  jsonb,                       -- CHỈ lưu khi người dùng đồng ý gửi
  status       text not null default 'open' check (status in ('open', 'closed')),
  created_by   uuid references staff(id),
  created_at   timestamptz not null default now(),
  unique (shop_id, code)
);

-- ======================================================================
-- 3) Quyền
-- ======================================================================
create or replace function _perm_keys() returns text[]
language sql immutable as $$
  select array['inventory.record', 'inventory.costs', 'inventory.approve', 'data.export',
               'members.manage', 'shop.manage', 'floor.manage']
$$;

-- Mặc định giữ đúng hành vi cũ: ai trong quán cũng ghi nhận kho được; còn lại tắt, quản lý được sửa khu vực/bàn
create or replace function _perm_default(p_role text, p_perm text) returns boolean
language sql immutable as $$
  select case p_perm
           when 'inventory.record' then true
           when 'floor.manage' then p_role = 'manager'
           else false
         end
$$;

create or replace function _seed_role_permissions(p_shop uuid) returns void
language sql security definer set search_path = public as $$
  insert into role_permissions (shop_id, job_role, permission, allowed)
  select p_shop, r.role, k.perm, _perm_default(r.role, k.perm)
    from (values ('manager'), ('cashier'), ('staff')) as r(role)
    cross join unnest(_perm_keys()) as k(perm)
  on conflict do nothing
$$;

do $seed$ begin perform _seed_role_permissions(id) from shops; end $seed$;

create or replace function roles_seed_trg() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform _seed_role_permissions(new.id);
  return new;
end $$;
drop trigger if exists shops_seed_roles on shops;
create trigger shops_seed_roles after insert on shops for each row execute function roles_seed_trg();

create or replace function app_can(p_perm text) returns boolean
language sql stable security definer set search_path = public as $$
  select app_is_owner() or coalesce((
    select rp.allowed
      from staff s
      join role_permissions rp on rp.shop_id = s.shop_id and rp.job_role = s.job_role and rp.permission = p_perm
     where s.id = app_staff_id()
  ), false)
$$;

-- Cổng kiểm tra quyền cho hàm có quyền theo vai trò. Trả về id thành viên đang gọi.
create or replace function _require_perm(p_perm text) returns uuid
language plpgsql stable security definer set search_path = public as $$
declare v uuid := _require_staff();
begin
  if not (p_perm = any (_perm_keys())) then raise exception 'PERMISSION_UNKNOWN'; end if;
  if not app_can(p_perm) then raise exception 'PERMISSION_DENIED'; end if;
  return v;
end $$;

-- Quyền của chính tôi tại quán đang chọn (app dùng để ẩn/hiện mục)
create or replace function my_permissions() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff(); k text; v_out jsonb := '{}'::jsonb;
begin
  foreach k in array _perm_keys() loop
    v_out := v_out || jsonb_build_object(k, app_can(k));
  end loop;
  return jsonb_build_object('is_owner', app_is_owner(),
    'job_role', (select job_role from staff where id = v_me), 'permissions', v_out);
end $$;

-- Cấu hình vai trò của một quán (chủ xem), kèm số thành viên đang dùng
create or replace function roles_get(p_job_role text) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_owner(); v_shop := app_shop_id();
  if p_job_role not in ('manager', 'cashier', 'staff') then raise exception 'ROLE_INVALID'; end if;
  return jsonb_build_object(
    'job_role', p_job_role,
    'members', coalesce((select jsonb_agg(s.full_name order by s.full_name) from staff s
                          where s.shop_id = v_shop and s.active and s.role = 'staff' and s.job_role = p_job_role), '[]'::jsonb),
    'permissions', coalesce((select jsonb_object_agg(rp.permission, rp.allowed) from role_permissions rp
                              where rp.shop_id = v_shop and rp.job_role = p_job_role and rp.permission = any (_perm_keys())), '{}'::jsonb));
end $$;

-- Lưu quyền một vai trò, áp dụng cho các quán chủ chọn (mỗi quán phải là quán chủ là chủ)
create or replace function roles_save(p_job_role text, p_permissions jsonb, p_shops uuid[] default null) returns integer
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_owner(); v_current uuid := app_shop_id(); v_shop uuid; k text; v_n integer := 0;
  v_targets uuid[] := coalesce(p_shops, array[v_current]);
begin
  if p_job_role not in ('manager', 'cashier', 'staff') then raise exception 'ROLE_INVALID'; end if;
  if jsonb_typeof(coalesce(p_permissions, 'null'::jsonb)) <> 'object' then raise exception 'INPUT_INVALID'; end if;
  for k in select jsonb_object_keys(p_permissions) loop
    if not (k = any (_perm_keys())) then raise exception 'PERMISSION_UNKNOWN'; end if;
    if jsonb_typeof(p_permissions -> k) <> 'boolean' then raise exception 'INPUT_INVALID'; end if;
  end loop;
  foreach v_shop in array v_targets loop
    if not exists (select 1 from staff where shop_id = v_shop and auth_user_id = auth.uid() and active and role = 'owner') then
      raise exception 'OWNER_ONLY';
    end if;
    for k in select jsonb_object_keys(p_permissions) loop
      insert into role_permissions (shop_id, job_role, permission, allowed, updated_by, updated_at)
      values (v_shop, p_job_role, k, (p_permissions ->> k)::boolean,
              (select id from staff where shop_id = v_shop and auth_user_id = auth.uid() and active and role = 'owner'), now())
      on conflict (shop_id, job_role, permission)
        do update set allowed = excluded.allowed, updated_by = excluded.updated_by, updated_at = now();
    end loop;
    insert into audit_log (shop_id, actor, action, entity, detail)
    values (v_shop, (select id from staff where shop_id = v_shop and auth_user_id = auth.uid() and active and role = 'owner'),
            'roles_save', 'role_permissions', jsonb_build_object('job_role', p_job_role, 'permissions', p_permissions));
    v_n := v_n + 1;
  end loop;
  return v_n;
end $$;

-- ======================================================================
-- 4) Nhân sự: mời có vai trò, đổi vai trò, thu hồi
-- ======================================================================
-- Người có quyền quản lý thành viên không được động vào chủ, vào chính mình, hay vào quản lý khác (chỉ chủ làm được)
create or replace function _can_manage_member(p_target staff) returns boolean
language sql stable security definer set search_path = public as $$
  select case
    when p_target.role = 'owner' then false
    when app_is_owner() then true
    else p_target.id <> app_staff_id() and p_target.job_role <> 'manager'
  end
$$;

create or replace function team_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_perm('members.manage'); v_shop := app_shop_id();
  return jsonb_build_object(
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
               'staff_id', s.id, 'full_name', s.full_name, 'role', s.role, 'job_role', s.job_role, 'active', s.active,
               'phone', _auth_phone(u.phone, u.phone_confirmed_at, u.email),
               'email', case when _is_phone_login(u.email) then null else u.email::text end,
               'has_pin', s.pin_hash is not null, 'joined_at', s.created_at, 'deactivated_at', s.deactivated_at,
               'is_me', s.id = app_staff_id(),
               'on_shift', exists (select 1 from shifts sh where sh.opened_by = s.id and sh.status = 'open'))
             order by (s.role = 'owner') desc, s.active desc, s.created_at)
        from staff s left join auth.users u on u.id = s.auth_user_id
       where s.shop_id = v_shop), '[]'::jsonb),
    'invites', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', i.id, 'full_name', i.full_name, 'phone', i.phone, 'email', i.email, 'job_role', i.job_role,
               'created_at', i.created_at, 'expires_at', i.expires_at, 'expired', i.expires_at < now())
             order by i.created_at desc)
        from shop_invites i where i.shop_id = v_shop and i.status = 'pending'), '[]'::jsonb));
end $$;

-- Gán vai trò cho lời mời vừa tạo bằng invite_staff() (chỉ chủ mời người mới). Nếu bước này lỗi, lời mời vẫn là 'staff' (ít quyền nhất).
create or replace function team_set_invite_role(p_invite uuid, p_job_role text) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_owner();   -- mời người mới là việc của chủ (invite_staff cũ chỉ cho chủ)
  if p_job_role not in ('manager', 'cashier', 'staff') then raise exception 'ROLE_INVALID'; end if;
  if p_job_role = 'manager' and not app_is_owner() then raise exception 'OWNER_ONLY'; end if;
  update shop_invites set job_role = p_job_role where id = p_invite and shop_id = app_shop_id() and status = 'pending';
  if not found then raise exception 'NOT_FOUND'; end if;
  perform _audit('invite_role', 'shop_invites', p_invite, jsonb_build_object('job_role', p_job_role));
end $$;

-- Gửi lại lời mời = gia hạn thêm 7 ngày
create or replace function team_resend_invite(p_invite uuid) returns timestamptz
language plpgsql security definer set search_path = public as $$
declare v_exp timestamptz := now() + interval '7 days';
begin
  perform _require_owner();   -- mời người mới là việc của chủ (invite_staff cũ chỉ cho chủ)
  update shop_invites set expires_at = v_exp where id = p_invite and shop_id = app_shop_id() and status = 'pending';
  if not found then raise exception 'NOT_FOUND'; end if;
  perform _audit('resend_invite', 'shop_invites', p_invite);
  return v_exp;
end $$;

create or replace function team_set_role(p_staff uuid, p_job_role text) returns void
language plpgsql security definer set search_path = public as $$
declare t staff;
begin
  perform _require_perm('members.manage');
  if p_job_role not in ('manager', 'cashier', 'staff') then raise exception 'ROLE_INVALID'; end if;
  select * into t from staff where id = p_staff and shop_id = app_shop_id() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if t.role = 'owner' then raise exception 'OWNER_PROTECTED'; end if;
  if not _can_manage_member(t) then raise exception 'PERMISSION_DENIED'; end if;
  if p_job_role = 'manager' and not app_is_owner() then raise exception 'OWNER_ONLY'; end if;
  update staff set job_role = p_job_role where id = p_staff;
  perform _audit('set_job_role', 'staff', p_staff, jsonb_build_object('from', t.job_role, 'to', p_job_role));
end $$;

-- Thu hồi quyền truy cập: không xóa lịch sử, không thu hồi được chủ quán, không thu hồi người đang giữ ca
create or replace function team_revoke(p_staff uuid) returns void
language plpgsql security definer set search_path = public as $$
declare t staff;
begin
  perform _require_perm('members.manage');
  select * into t from staff where id = p_staff and shop_id = app_shop_id() for update;
  if not found then raise exception 'NOT_FOUND'; end if;
  if t.role = 'owner' then raise exception 'OWNER_PROTECTED'; end if;
  if t.id = app_staff_id() then raise exception 'SELF_PROTECTED'; end if;
  if not _can_manage_member(t) then raise exception 'PERMISSION_DENIED'; end if;
  if not t.active then return; end if;
  if exists (select 1 from shifts where opened_by = t.id and status = 'open') then raise exception 'MEMBER_HAS_OPEN_SHIFT'; end if;
  update staff set active = false, deactivated_at = now() where id = p_staff;
  perform _audit('revoke_member', 'staff', p_staff, jsonb_build_object('name', t.full_name, 'job_role', t.job_role));
end $$;

-- Lời mời hết hạn thì không nhận được nữa; nhận lời mời thì mang theo vai trò chủ đã chọn
create or replace function invite_check_expiry() returns trigger
language plpgsql as $$
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' and old.expires_at < now() then
    raise exception 'INVITE_EXPIRED' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists shop_invites_expiry on shop_invites;
create trigger shop_invites_expiry before update on shop_invites for each row execute function invite_check_expiry();

create or replace function invite_apply_role() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status = 'accepted' and old.status is distinct from 'accepted' then
    update staff set job_role = new.job_role
     where shop_id = new.shop_id and auth_user_id = new.accepted_user_id and role = 'staff';
  end if;
  return new;
end $$;
drop trigger if exists shop_invites_apply_role on shop_invites;
create trigger shop_invites_apply_role after update on shop_invites for each row execute function invite_apply_role();

-- ======================================================================
-- 5) Hồ sơ quán + tổng quan các quán
-- ======================================================================
create or replace function shop_profile_get() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare s shops;
begin
  perform _require_staff();
  select * into s from shops where id = app_shop_id();
  return jsonb_build_object(
    'id', s.id, 'code', s.code, 'name', s.name, 'legal_name', s.legal_name, 'tax_code', s.tax_code,
    'email', s.email, 'phone', s.phone, 'address', s.address, 'open_daily', s.open_daily,
    'open_time', to_char(s.open_time, 'HH24:MI'), 'close_time', to_char(s.close_time, 'HH24:MI'),
    'timezone', s.timezone, 'can_edit', app_can('shop.manage'),
    'missing_invoice_info', (s.legal_name is null or s.tax_code is null or s.address is null));
end $$;

create or replace function shop_profile_save(p jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := _require_perm('shop.manage'); v_shop uuid := app_shop_id();
  v_name text := btrim(coalesce(p->>'name', ''));
  v_legal text := nullif(btrim(p->>'legal_name'), '');
  v_tax text := nullif(btrim(p->>'tax_code'), '');
  v_email text := nullif(lower(btrim(p->>'email')), '');
  v_phone text := nullif(btrim(p->>'phone'), '');
  v_addr text := nullif(btrim(p->>'address'), '');
  v_tz text := coalesce(nullif(btrim(p->>'timezone'), ''), 'Asia/Ho_Chi_Minh');
  v_open time; v_close time; v_daily boolean := coalesce((p->>'open_daily')::boolean, true);
begin
  if v_name = '' then raise exception 'NAME_REQUIRED'; end if;
  if char_length(v_name) > 80 then raise exception 'INPUT_INVALID'; end if;
  if v_addr is null then raise exception 'ADDRESS_REQUIRED'; end if;
  if v_tax is not null and v_tax !~ '^[0-9]{10}(-[0-9]{3})?$' then raise exception 'TAX_CODE_INVALID'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if v_phone is not null then
    v_phone := normalize_phone(v_phone);
    if v_phone is null or v_phone !~ '^[1-9][0-9]{7,14}$' then raise exception 'SHOP_PHONE_INVALID'; end if;
  end if;
  if not exists (select 1 from pg_timezone_names where name = v_tz) then raise exception 'TIMEZONE_INVALID'; end if;
  begin
    v_open := coalesce(nullif(p->>'open_time', ''), '06:00')::time;
    v_close := coalesce(nullif(p->>'close_time', ''), '22:00')::time;
  exception when invalid_datetime_format or datetime_field_overflow then raise exception 'TIME_INVALID';
  end;
  if v_open = v_close then raise exception 'TIME_INVALID'; end if;
  update shops set name = v_name, legal_name = v_legal, tax_code = v_tax, email = v_email, phone = v_phone,
         address = v_addr, open_daily = v_daily, open_time = v_open, close_time = v_close, timezone = v_tz
   where id = v_shop;
  perform _audit('shop_profile_save', 'shops', v_shop, jsonb_build_object('name', v_name));
  return shop_profile_get();
exception when invalid_text_representation then raise exception 'INPUT_INVALID';
end $$;

-- Các quán tôi là chủ: để chủ nhìn nhanh từng quán (không gộp dữ liệu)
create or replace function branches_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
             'shop_id', sh.id, 'code', sh.code, 'name', sh.name, 'address', sh.address,
             'is_current', sh.id = app_shop_id(),
             'active_members', (select count(*) from staff x where x.shop_id = sh.id and x.active),
             'pending_invites', (select count(*) from shop_invites i where i.shop_id = sh.id and i.status = 'pending' and i.expires_at >= now()))
           order by (sh.id = app_shop_id()) desc, sh.created_at)
      from staff s join shops sh on sh.id = s.shop_id
     where s.auth_user_id = auth.uid() and s.active and s.role = 'owner'), '[]'::jsonb);
end $$;

-- ======================================================================
-- 6) Khu vực và bàn
-- ======================================================================
create or replace function floor_overview() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid;
begin
  perform _require_perm('floor.manage'); v_shop := app_shop_id();
  return jsonb_build_object(
    'areas', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', a.id, 'name', a.name, 'active', a.active,
               'tables', coalesce((select jsonb_agg(jsonb_build_object(
                           'id', t.id, 'name', t.name, 'seats', t.seats, 'active', t.active,
                           'in_use', exists (select 1 from bills b where b.table_id = t.id and b.status = 'open'))
                           order by t.sort_order, nullif(left(regexp_replace(t.name, '\D', '', 'g'), 9), '')::integer nulls last, t.name)
                           from dining_tables t where t.area_id = a.id), '[]'::jsonb))
             order by a.active desc, a.sort_order, a.name)
        from areas a where a.shop_id = v_shop), '[]'::jsonb));
end $$;

create or replace function area_save(p_id uuid, p_name text) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_id uuid := p_id; v_name text := btrim(coalesce(p_name, ''));
begin
  perform _require_perm('floor.manage'); v_shop := app_shop_id();
  if v_name = '' or char_length(v_name) > 40 then raise exception 'NAME_REQUIRED'; end if;
  if v_id is null then
    insert into areas (name, sort_order) values (v_name, coalesce((select max(sort_order) + 1 from areas where shop_id = v_shop), 1))
    returning id into v_id;
  else
    update areas set name = v_name where id = v_id and shop_id = v_shop;
    if not found then raise exception 'NOT_FOUND'; end if;
  end if;
  perform _audit('area_save', 'areas', v_id, jsonb_build_object('name', v_name));
  return v_id;
exception when unique_violation then raise exception 'NAME_EXISTS';
end $$;

create or replace function area_set_active(p_id uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_perm('floor.manage');
  if not exists (select 1 from areas where id = p_id and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  if not p_active and exists (select 1 from dining_tables t join bills b on b.table_id = t.id and b.status = 'open'
                               where t.area_id = p_id) then
    raise exception 'TABLE_IN_USE';
  end if;
  update areas set active = p_active where id = p_id;
  perform _audit('area_set_active', 'areas', p_id, jsonb_build_object('active', p_active));
end $$;

create or replace function table_save(p_id uuid, p_area uuid, p_name text, p_seats integer) returns uuid
language plpgsql security definer set search_path = public as $$
declare v_shop uuid; v_id uuid := p_id; v_name text := btrim(coalesce(p_name, ''));
begin
  perform _require_perm('floor.manage'); v_shop := app_shop_id();
  if v_name = '' or char_length(v_name) > 20 then raise exception 'NAME_REQUIRED'; end if;
  if p_seats is null or p_seats < 1 or p_seats > 50 then raise exception 'SEATS_INVALID'; end if;
  if not exists (select 1 from areas where id = p_area and shop_id = v_shop) then raise exception 'NOT_FOUND'; end if;
  if v_id is null then
    insert into dining_tables (area_id, name, seats, sort_order)
    values (p_area, v_name, p_seats, coalesce((select max(sort_order) + 1 from dining_tables where area_id = p_area), 1))
    returning id into v_id;
  else
    if exists (select 1 from dining_tables t join bills b on b.table_id = t.id and b.status = 'open'
                where t.id = v_id and t.area_id <> p_area) then
      raise exception 'TABLE_IN_USE';   -- không chuyển khu vực khi bàn đang có đơn
    end if;
    update dining_tables set area_id = p_area, name = v_name, seats = p_seats where id = v_id and shop_id = v_shop;
    if not found then raise exception 'NOT_FOUND'; end if;
  end if;
  perform _audit('table_save', 'dining_tables', v_id, jsonb_build_object('name', v_name, 'seats', p_seats));
  return v_id;
exception when unique_violation then raise exception 'NAME_EXISTS';
end $$;

create or replace function table_set_active(p_id uuid, p_active boolean) returns void
language plpgsql security definer set search_path = public as $$
begin
  perform _require_perm('floor.manage');
  if not exists (select 1 from dining_tables where id = p_id and shop_id = app_shop_id()) then raise exception 'NOT_FOUND'; end if;
  if not p_active and exists (select 1 from bills where table_id = p_id and status = 'open') then raise exception 'TABLE_IN_USE'; end if;
  update dining_tables set active = p_active where id = p_id;
  perform _audit('table_set_active', 'dining_tables', p_id, jsonb_build_object('active', p_active));
end $$;

-- ======================================================================
-- 7) Nhật ký quản trị
-- ======================================================================
create or replace function audit_feed(p_from date, p_to date, p_actor uuid default null, p_limit integer default 100)
returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_shop uuid; v_lim integer := least(greatest(coalesce(p_limit, 100), 1), 500);
  v_from timestamptz; v_to timestamptz;
begin
  perform _require_perm('data.export'); v_shop := app_shop_id();
  if p_from is null or p_to is null or p_to < p_from or p_to - p_from > 366 then raise exception 'DATE_RANGE_INVALID'; end if;
  v_from := (p_from::timestamp at time zone 'Asia/Ho_Chi_Minh');
  v_to := ((p_to + 1)::timestamp at time zone 'Asia/Ho_Chi_Minh');
  return jsonb_build_object(
    'from', p_from, 'to', p_to,
    'actors', coalesce((select jsonb_agg(jsonb_build_object('staff_id', s.id, 'full_name', s.full_name) order by s.full_name)
                          from staff s where s.shop_id = v_shop), '[]'::jsonb),
    'events', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', e.id, 'at', e.at, 'action', e.action, 'entity', e.entity, 'entity_id', e.entity_id,
               'actor_id', e.actor, 'actor_name', (select s.full_name from staff s where s.id = e.actor),
               'detail', e.detail) order by e.at desc, e.id desc)
        from (select * from audit_log x
               where x.shop_id = v_shop and x.at >= v_from and x.at < v_to and (p_actor is null or x.actor = p_actor)
               order by x.at desc, x.id desc limit v_lim) e), '[]'::jsonb));
end $$;

-- ======================================================================
-- 8) Hỗ trợ
-- ======================================================================
create or replace function support_create(p_topic text, p_message text, p_contact text default 'in_app',
                                          p_diagnostics jsonb default null, p_consent boolean default false)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_me uuid := _require_staff(); v_code text; v_id uuid;
begin
  if p_topic not in ('setup', 'printer', 'permissions', 'data', 'other') then raise exception 'KIND_INVALID'; end if;
  if p_contact not in ('in_app', 'callback') then raise exception 'KIND_INVALID'; end if;
  if char_length(btrim(coalesce(p_message, ''))) < 5 then raise exception 'NOTE_REQUIRED'; end if;
  v_code := 'SP-' || to_char(now() at time zone 'Asia/Ho_Chi_Minh', 'DDMM') || '-' || upper(substr(md5(gen_random_uuid()::text), 1, 4));
  insert into support_requests (code, topic, message, contact, diagnostics, created_by)
  values (v_code, p_topic, btrim(p_message), p_contact,
          case when coalesce(p_consent, false) then p_diagnostics end, v_me)
  returning id into v_id;
  return jsonb_build_object('id', v_id, 'code', v_code, 'diagnostics_sent', coalesce(p_consent, false) and p_diagnostics is not null);
end $$;

create or replace function support_list() returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare v_me uuid := _require_staff();
begin
  return coalesce((
    select jsonb_agg(jsonb_build_object('id', r.id, 'code', r.code, 'topic', r.topic, 'message', r.message,
                                        'status', r.status, 'created_at', r.created_at) order by r.created_at desc)
      from (select * from support_requests
             where shop_id = app_shop_id() and (app_is_owner() or created_by = v_me)
             order by created_at desc limit 20) r), '[]'::jsonb);
end $$;

-- ======================================================================
-- 9) Bảo mật: RLS + quyền gọi
-- ======================================================================
alter table role_permissions enable row level security;
alter table support_requests enable row level security;
grant select on role_permissions, support_requests to authenticated;
drop policy if exists role_permissions_owner_read on role_permissions;
create policy role_permissions_owner_read on role_permissions for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner()));
drop policy if exists support_requests_owner_read on support_requests;
create policy support_requests_owner_read on support_requests for select to authenticated
  using (shop_id = (select app_shop_id()) and (select app_is_owner()));

revoke all on function
  my_permissions(), roles_get(text), roles_save(text, jsonb, uuid[]),
  team_overview(), team_set_invite_role(uuid, text), team_resend_invite(uuid), team_set_role(uuid, text), team_revoke(uuid),
  shop_profile_get(), shop_profile_save(jsonb), branches_overview(),
  floor_overview(), area_save(uuid, text), area_set_active(uuid, boolean),
  table_save(uuid, uuid, text, integer), table_set_active(uuid, boolean),
  audit_feed(date, date, uuid, integer), support_create(text, text, text, jsonb, boolean), support_list()
  from public, anon, authenticated;
grant execute on function
  my_permissions(), roles_get(text), roles_save(text, jsonb, uuid[]),
  team_overview(), team_set_invite_role(uuid, text), team_resend_invite(uuid), team_set_role(uuid, text), team_revoke(uuid),
  shop_profile_get(), shop_profile_save(jsonb), branches_overview(),
  floor_overview(), area_save(uuid, text), area_set_active(uuid, boolean),
  table_save(uuid, uuid, text, integer), table_set_active(uuid, boolean),
  audit_feed(date, date, uuid, integer), support_create(text, text, text, jsonb, boolean), support_list()
  to authenticated;
revoke all on function
  _perm_keys(), _perm_default(text, text), _seed_role_permissions(uuid), roles_seed_trg(), app_can(text), _require_perm(text),
  _can_manage_member(staff), invite_check_expiry(), invite_apply_role()
  from public, anon, authenticated;
