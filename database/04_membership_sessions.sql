-- Fore · 04_membership_sessions.sql
-- Grouped install module. Apply after the previous numbered module.
-- Generated from the former ordered SQL sources; preserve source order within this file.

-- >>> 013_staff_birth_date.sql
-- Fore · 013_staff_birth_date.sql
-- Thêm ngày sinh hồ sơ nhân viên và đồng bộ khi họ nhận lời mời.
-- Chạy sau 012_owner_dashboard.sql; không cần reset dữ liệu.

alter table staff add column if not exists birth_date date;

create or replace function accept_invite(p_invite uuid) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  r shop_invites;
  v_staff uuid;
  v_name text;
  v_birth_date date;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  r := _invite_for_me(p_invite);
  v_name := coalesce(nullif(btrim(auth.jwt() -> 'user_metadata' ->> 'full_name'), ''), r.full_name);
  begin
    v_birth_date := nullif(auth.jwt() -> 'user_metadata' ->> 'birth_date', '')::date;
  exception when invalid_datetime_format then
    raise exception 'BIRTH_DATE_INVALID';
  end;

  select id into v_staff from staff where shop_id = r.shop_id and auth_user_id = v_uid;
  if v_staff is null then
    insert into staff (shop_id, auth_user_id, full_name, birth_date, role)
    values (r.shop_id, v_uid, v_name, v_birth_date, 'staff')
    returning id into v_staff;
  else
    update staff
       set active = true, role = 'staff', full_name = v_name,
           birth_date = coalesce(v_birth_date, birth_date)
     where id = v_staff;
  end if;

  update shop_invites set status = 'accepted', responded_at = now(), accepted_user_id = v_uid where id = r.id;
  insert into user_settings (auth_user_id, active_shop_id) values (v_uid, r.shop_id)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
    values (r.shop_id, v_staff, 'accept_invite', 'shop_invites', r.id, null);
  return v_staff;
end $$;

revoke all on function accept_invite(uuid) from public, anon;
grant execute on function accept_invite(uuid) to authenticated;


-- >>> 014_invite_phone_or_email.sql
-- Cho phép chủ mời nhân viên bằng điện thoại, email hoặc cả hai.
-- Chạy sau 013_staff_birth_date.sql.
alter table shop_invites alter column phone drop not null;
drop index if exists one_pending_invite;
create unique index if not exists one_pending_invite_phone
  on shop_invites (shop_id, phone) where status = 'pending' and phone is not null;
create unique index if not exists one_pending_invite_email
  on shop_invites (shop_id, email) where status = 'pending' and email is not null;

create or replace function invite_staff(p_phone text, p_full_name text, p_email text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := _require_owner();
  v_phone text := case when nullif(btrim(p_phone), '') is null then null else normalize_phone(p_phone) end;
  v_email text := nullif(lower(btrim(p_email)), '');
  v_id uuid;
begin
  -- Có nhập số mà không đọc được thì báo sai số, không được lặng lẽ bỏ qua rồi chỉ mời bằng email.
  if nullif(btrim(p_phone), '') is not null and (v_phone is null or v_phone !~ '^[1-9][0-9]{7,14}$') then
    raise exception 'PHONE_INVALID';
  end if;
  if v_phone is null and v_email is null then raise exception 'CONTACT_REQUIRED'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if exists (
    select 1 from staff s join auth.users u on u.id = s.auth_user_id
    where s.shop_id = app_shop_id() and s.active and (
      (v_phone is not null and u.phone_confirmed_at is not null and normalize_phone(u.phone) = v_phone)
      or (v_email is not null and u.email_confirmed_at is not null and lower(u.email) = v_email)))
  then raise exception 'ALREADY_MEMBER'; end if;
  begin
    insert into shop_invites (shop_id, phone, email, full_name, invited_by)
    values (app_shop_id(), v_phone, v_email, btrim(p_full_name), v_me) returning id into v_id;
  exception when unique_violation then raise exception 'ALREADY_INVITED';
  end;
  perform _audit('invite_staff', 'shop_invites', v_id,
    jsonb_build_object('phone', v_phone, 'email', v_email, 'name', btrim(p_full_name)));
  return v_id;
end $$;
revoke all on function invite_staff(text, text, text) from public, anon;
grant execute on function invite_staff(text, text, text) to authenticated;


-- >>> 015_legacy_staff_contact_helpers.sql
-- Tương thích đọc danh sách tài khoản thử nghiệm cũ; không dùng email giả/metadata để xác thực,
-- đăng nhập hoặc khớp lời mời. Nhân viên cần dùng OTP với contact thật đã xác minh.
-- =====================================================================

-- Chỉ dùng để hiển thị số cũ trong team; không phải bằng chứng xác minh số điện thoại.
create or replace function _phone_login_domain() returns text
language sql immutable as $$ select 'phone.fore-staff.app'::text $$;

-- Email này có phải email giả đại diện cho số điện thoại không?
create or replace function _is_phone_login(p_email text) returns boolean
language sql immutable as $$
  select lower(btrim(coalesce(p_email, ''))) ~ ('^p[0-9]{8,15}@' || replace(_phone_login_domain(), '.', '\.') || '$')
$$;

-- Số điện thoại của một tài khoản (dạng 84901234567): số đã xác thực của Supabase,
-- hoặc số nằm trong email giả. `null` nếu tài khoản không có số.
create or replace function _auth_phone(p_phone text, p_phone_confirmed_at timestamptz, p_email text) returns text
language sql immutable as $$
  select coalesce(
    case when p_phone_confirmed_at is not null then normalize_phone(p_phone) end,
    case when _is_phone_login(p_email)
         then substring(lower(btrim(p_email)) from '^p([0-9]+)@') end)
$$;

-- Email thật của một tài khoản (đã xác nhận, không tính email giả). `null` nếu không có.
create or replace function _auth_email(p_email text, p_email_confirmed_at timestamptz) returns text
language sql immutable as $$
  select case when p_email_confirmed_at is not null and not _is_phone_login(p_email)
              then lower(btrim(p_email)) end
$$;

revoke all on function _phone_login_domain(), _is_phone_login(text), _auth_phone(text, timestamptz, text),
  _auth_email(text, timestamptz) from public, anon, authenticated;

-- Liên hệ của người đang đăng nhập, dùng để tìm lời mời gửi cho họ.
create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public as $$
begin
  select _auth_phone(u.phone, u.phone_confirmed_at, u.email),
         _auth_email(u.email, u.email_confirmed_at)
    into phone, email
    from auth.users u where u.id = auth.uid();
end $$;

-- Mời nhân viên: nhận ra người đã là thành viên dù họ đăng ký bằng số điện thoại, email thật hay email giả.
create or replace function invite_staff(p_phone text, p_full_name text, p_email text default null) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_me uuid := _require_owner();
  v_phone text := case when nullif(btrim(p_phone), '') is null then null else normalize_phone(p_phone) end;
  v_email text := nullif(lower(btrim(p_email)), '');
  v_id uuid;
begin
  -- Có nhập số mà không đọc được thì báo sai số, không được lặng lẽ bỏ qua rồi chỉ mời bằng email.
  if nullif(btrim(p_phone), '') is not null and (v_phone is null or v_phone !~ '^[1-9][0-9]{7,14}$') then
    raise exception 'PHONE_INVALID';
  end if;
  if v_phone is null and v_email is null then raise exception 'CONTACT_REQUIRED'; end if;
  if coalesce(btrim(p_full_name), '') = '' then raise exception 'NAME_REQUIRED'; end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'EMAIL_INVALID'; end if;
  if exists (
    select 1 from staff s join auth.users u on u.id = s.auth_user_id
    where s.shop_id = app_shop_id() and s.active and (
      (v_phone is not null and _auth_phone(u.phone, u.phone_confirmed_at, u.email) = v_phone)
      or (v_email is not null and _auth_email(u.email, u.email_confirmed_at) = v_email)))
  then raise exception 'ALREADY_MEMBER'; end if;
  begin
    insert into shop_invites (shop_id, phone, email, full_name, invited_by)
    values (app_shop_id(), v_phone, v_email, btrim(p_full_name), v_me) returning id into v_id;
  exception when unique_violation then raise exception 'ALREADY_INVITED';
  end;
  perform _audit('invite_staff', 'shop_invites', v_id,
    jsonb_build_object('phone', v_phone, 'email', v_email, 'name', btrim(p_full_name)));
  return v_id;
end $$;

-- Danh sách nhân viên cho chủ: số điện thoại lấy từ email giả, không hiện email giả ra màn hình.
create or replace function shop_team()
returns table (staff_id uuid, full_name text, role text, active boolean, phone text, email text, has_pin boolean, joined_at timestamptz)
language plpgsql stable security definer set search_path = public as $$
begin
  perform _require_owner();
  return query
    select s.id, s.full_name, s.role, s.active,
           _auth_phone(u.phone, u.phone_confirmed_at, u.email),
           case when _is_phone_login(u.email) then null else u.email::text end,
           s.pin_hash is not null, s.created_at
      from staff s left join auth.users u on u.id = s.auth_user_id
     where s.shop_id = app_shop_id()
     order by (s.role = 'owner') desc, s.active desc, s.created_at;
end $$;

revoke all on function invite_staff(text, text, text), shop_team() from public, anon;
grant execute on function invite_staff(text, text, text), shop_team() to authenticated;


-- >>> 016_audit_actor_same_shop.sql
-- Fore · 016_audit_actor_same_shop.sql · Sửa nhật ký khi một người thuộc NHIỀU quán
-- Chạy sau 015_simple_staff_login.sql; không cần reset dữ liệu.
--
-- LỖI: `audit_log_actor_same_shop_fk` (001) bắt buộc (shop_id, actor) phải cùng một quán. Trigger
-- `audit_row_change` lấy shop_id từ DÒNG bị đổi nhưng actor từ `app_staff_id()` (nhân viên ở quán ĐANG CHỌN).
-- Nên người đã ở quán A mà tạo quán B (`create_shop`) hoặc chấp nhận lời mời vào quán B (`accept_invite`)
-- sẽ ghi (shop B, nhân viên của A) và bị khóa ngoại chặn: thao tác thất bại.
--
-- SỬA: actor là nhân viên của CHÍNH QUÁN CỦA DÒNG đó (nếu người này chưa là nhân viên ở đó thì để trống,
-- ví dụ lúc hệ thống tự gieo cấu hình cho quán vừa tạo).
create or replace function audit_row_change() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_old jsonb; v_new jsonb; v_shop uuid; v_actor uuid;
begin
  if tg_op in ('UPDATE','DELETE') then v_old := to_jsonb(old) - 'pin_hash'; end if;
  if tg_op in ('INSERT','UPDATE') then v_new := to_jsonb(new) - 'pin_hash'; end if;
  v_shop := coalesce((v_new->>'shop_id')::uuid, (v_old->>'shop_id')::uuid, app_shop_id());
  select s.id into v_actor from staff s
   where s.auth_user_id = auth.uid() and s.shop_id = v_shop and s.active;
  insert into audit_log (shop_id, actor, action, entity, entity_id, detail)
  values (v_shop, v_actor, lower(tg_op), tg_table_name,
          coalesce(v_new->>'id', v_old->>'id')::uuid,
          jsonb_build_object('old', v_old, 'new', v_new));
  return coalesce(new, old);
end $$;


-- >>> 017_staff_invite_contact_fallback.sql
-- Fore · 017_legacy_staff_contact_display.sql
-- Legacy helper giữ lại để hiển thị team cũ; không xác minh hoặc nhận lời mời bằng alias.
-- Chạy sau 015_simple_staff_login.sql và 016_audit_actor_same_shop.sql.
-- Không thay đổi dữ liệu hiện có; lời mời pending sẽ khớp ngay sau khi chạy.
-- TEST ONLY: không dùng cơ chế đăng nhập không xác minh này cho môi trường production.

-- Giữ migration tự chứa để dùng được cả với bộ cài hợp nhất.
create or replace function _is_demo_staff_phone_email(p_email text)
returns boolean
language sql immutable as $$
  select lower(btrim(coalesce(p_email, ''))) ~ '^p[0-9]{8,15}@phone[.]fore-staff[.]app$'
$$;

create or replace function _demo_staff_phone(
  p_phone text,
  p_phone_confirmed_at timestamptz,
  p_email text,
  p_metadata jsonb
) returns text
language sql immutable as $$
  select coalesce(
    normalize_phone(p_metadata ->> 'demo_phone'),
    case when p_phone_confirmed_at is not null then normalize_phone(p_phone) end,
    case when _is_demo_staff_phone_email(p_email)
      then substring(lower(btrim(p_email)) from '^p([0-9]+)@') end
  )
$$;

create or replace function _demo_staff_email(
  p_email text,
  p_email_confirmed_at timestamptz,
  p_metadata jsonb
) returns text
language sql immutable as $$
  select coalesce(
    nullif(lower(btrim(p_metadata ->> 'demo_email')), ''),
    case when p_email_confirmed_at is not null
           and not _is_demo_staff_phone_email(p_email)
      then lower(btrim(p_email)) end,
    case when p_email is not null and not _is_demo_staff_phone_email(p_email)
      then lower(btrim(p_email)) end
  )
$$;
revoke all on function _is_demo_staff_phone_email(text),
  _demo_staff_phone(text, timestamptz, text, jsonb),
  _demo_staff_email(text, timestamptz, jsonb)
  from public, anon, authenticated;

create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public, auth as $$
declare
  v_meta jsonb;
  v_raw_phone text;
  v_phone_confirmed_at timestamptz;
  v_raw_email text;
  v_email_confirmed_at timestamptz;
begin
  select u.raw_user_meta_data, u.phone::text, u.phone_confirmed_at,
         u.email::text, u.email_confirmed_at
    into v_meta, v_raw_phone, v_phone_confirmed_at,
         v_raw_email, v_email_confirmed_at
    from auth.users u
   where u.id = auth.uid();

  -- Metadata do app mới ghi được; các tài khoản cũ fallback về danh tính Auth.
  -- _auth_phone nhận diện email giả p<phone>@phone.fore-staff.app.
  phone := _demo_staff_phone(
    v_raw_phone, v_phone_confirmed_at, v_raw_email, v_meta);
  email := _demo_staff_email(v_raw_email, v_email_confirmed_at, v_meta);
end $$;
revoke all on function _my_verified_contacts() from public, anon, authenticated;

-- Chỉ contact Auth đã xác minh mới ngăn chủ gửi lời mời trùng cho thành viên hiện có.
create or replace function invite_staff(
  p_phone text,
  p_full_name text,
  p_email text default null
) returns uuid
language plpgsql security definer set search_path = public, auth as $$
declare
  v_me uuid := _require_owner();
  v_phone text := case
    when nullif(btrim(p_phone), '') is null then null
    else normalize_phone(p_phone)
  end;
  v_email text := nullif(lower(btrim(p_email)), '');
  v_id uuid;
begin
  -- Nếu chủ đã nhập số nhưng số không hợp lệ, không âm thầm bỏ số rồi mời bằng email.
  if nullif(btrim(p_phone), '') is not null
     and (v_phone is null or v_phone !~ '^[1-9][0-9]{7,14}$') then
    raise exception 'PHONE_INVALID';
  end if;
  if v_phone is null and v_email is null then
    raise exception 'CONTACT_REQUIRED';
  end if;
  if coalesce(btrim(p_full_name), '') = '' then
    raise exception 'NAME_REQUIRED';
  end if;
  if v_email is not null and v_email !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then
    raise exception 'EMAIL_INVALID';
  end if;

  if exists (
    select 1
      from staff s
      join auth.users u on u.id = s.auth_user_id
     where s.shop_id = app_shop_id()
       and s.active
       and (
         (v_phone is not null and u.phone_confirmed_at is not null
           and normalize_phone(u.phone::text) = v_phone)
         or
         (v_email is not null and u.email_confirmed_at is not null
           and not _is_phone_login(u.email::text)
           and lower(btrim(u.email::text)) = v_email)
       )
  ) then
    raise exception 'ALREADY_MEMBER';
  end if;

  begin
    insert into shop_invites(shop_id, phone, email, full_name, invited_by)
    values (app_shop_id(), v_phone, v_email, btrim(p_full_name), v_me)
    returning id into v_id;
  exception when unique_violation then
    raise exception 'ALREADY_INVITED';
  end;

  perform _audit('invite_staff', 'shop_invites', v_id,
    jsonb_build_object('phone', v_phone, 'email', v_email, 'name', btrim(p_full_name)));
  return v_id;
end $$;
revoke all on function invite_staff(text, text, text) from public, anon;
grant execute on function invite_staff(text, text, text) to authenticated;


-- >>> 018_session_context.sql
-- Fore · 018_session_context.sql
-- Trạng thái phiên do máy chủ quyết định. account_kind chỉ chọn luồng khởi tạo;
-- quyền truy cập luôn lấy từ membership staff đang hoạt động trong từng quán.

create or replace function my_session_context(p_preferred_shop uuid default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_active_shop uuid;
  v_account_kind text;
  v_shops jsonb;
  v_pending_invites integer := 0;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if not validate_staff_device() then raise exception 'STAFF_DEVICE_UNTRUSTED'; end if;

  -- Client có thể gửi lần chọn gần nhất, nhưng chỉ membership đang hoạt động mới được dùng.
  if p_preferred_shop is not null and exists (
    select 1 from staff s
     where s.auth_user_id = v_uid and s.shop_id = p_preferred_shop and s.active
  ) then
    insert into user_settings (auth_user_id, active_shop_id)
    values (v_uid, p_preferred_shop)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;
  end if;

  -- app_metadata do _stamp_account_kind đóng dấu; user_metadata người dùng sửa được nên không tin.
  select case when u.raw_app_meta_data->>'fore_account_kind' in ('owner', 'staff')
              then u.raw_app_meta_data->>'fore_account_kind'
              else 'unknown' end
    into v_account_kind
    from auth.users u where u.id = v_uid;
  v_account_kind := coalesce(v_account_kind, 'unknown');
  v_active_shop := app_shop_id();

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'shop_id', s.shop_id,
      'shop_name', sh.name,
      'staff_id', s.id,
      'full_name', s.full_name,
      'role', s.role,
      'active', s.active,
      'has_pin', s.pin_hash is not null,
      'is_current', s.shop_id = v_active_shop
    ) order by s.created_at, s.id
  ), '[]'::jsonb)
    into v_shops
    from staff s join shops sh on sh.id = s.shop_id
   where s.auth_user_id = v_uid and s.active;

  select count(*)::integer into v_pending_invites from my_invites();

  return jsonb_build_object(
    'account_kind', v_account_kind,
    'shops', v_shops,
    'active_shop_id', v_active_shop,
    'pending_invite_count', v_pending_invites
  );
end;
$$;

revoke all on function my_session_context(uuid) from public, anon;
grant execute on function my_session_context(uuid) to authenticated;


-- >>> 019_invite_expiry.sql
-- Fore · 019_invite_expiry.sql
-- Lời mời chờ quá 14 ngày được đóng thành expired khi người nhận hoặc chủ tải lại.
-- Dữ liệu chỉ đổi trạng thái; không xóa lời mời hay membership.

alter table shop_invites drop constraint if exists shop_invites_status_check;
alter table shop_invites add constraint shop_invites_status_check
  check (status in ('pending', 'accepted', 'declined', 'cancelled', 'expired'));

create or replace function expire_my_invites() returns integer
language plpgsql security definer set search_path = public as $$
declare
  v_phone text;
  v_email text;
  v_count integer;
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;

  update shop_invites i
     set status = 'expired', responded_at = now()
   where i.status = 'pending'
     and i.created_at <= now() - interval '14 days'
     and (
       (v_phone is not null and i.phone = v_phone)
       or (v_email is not null and i.email = v_email)
       or (i.shop_id = app_shop_id() and app_is_owner())
     );
  get diagnostics v_count = row_count;
  return v_count;
end $$;

-- Đọc lại hộp thư cũng phải áp dụng thời hạn trước khi trả lời lời mời.
-- Hàm này phải VOLATILE vì cập nhật status qua expire_my_invites().
create or replace function my_invites()
returns table (invite_id uuid, shop_id uuid, shop_name text, invited_name text,
               invited_by_name text, created_at timestamptz)
language plpgsql volatile security definer set search_path = public as $$
declare
  v_phone text;
  v_email text;
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  perform expire_my_invites();
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  return query
    select i.id, i.shop_id, sh.name, i.full_name, inv.full_name, i.created_at
      from shop_invites i
      join shops sh on sh.id = i.shop_id
      join staff inv on inv.id = i.invited_by
     where i.status = 'pending'
       and ((v_phone is not null and i.phone = v_phone)
         or (v_email is not null and i.email = v_email))
     order by i.created_at desc;
end $$;

create or replace function _invite_for_me(p_invite uuid) returns shop_invites
language plpgsql security definer set search_path = public as $$
declare
  v_phone text;
  v_email text;
  r shop_invites;
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  select * into r from shop_invites i
   where i.id = p_invite and i.status = 'pending'
     and ((v_phone is not null and i.phone = v_phone)
       or (v_email is not null and i.email = v_email))
   for update;
  if found then return r; end if;

  if exists (
    select 1 from shop_invites i
     where i.id = p_invite and i.status = 'expired'
       and ((v_phone is not null and i.phone = v_phone)
         or (v_email is not null and i.email = v_email))
  ) then
    raise exception 'INVITE_EXPIRED';
  end if;
  raise exception 'INVITE_NOT_FOUND';
end $$;

revoke all on function expire_my_invites() from public, anon;
grant execute on function expire_my_invites() to authenticated;
revoke all on function my_invites() from public, anon;
grant execute on function my_invites() to authenticated;
revoke all on function _invite_for_me(uuid) from public, anon, authenticated;


-- >>> 020_owner_sales_trend.sql
-- Fore · 020_owner_sales_trend.sql
-- Bảy ngày kinh doanh, tính từ 06:00 theo thời gian truyền từ app.
-- Ngày hiện tại chỉ tính đến giờ hiện tại; chỉ chủ quán mới đọc được chuỗi này.

create or replace function owner_sales_trend(
  p_business_start timestamptz,
  p_days integer default 7
) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  v_shop uuid := app_shop_id();
  v_trend jsonb;
begin
  if v_shop is null or not app_is_owner() then
    raise exception 'OWNER_ONLY';
  end if;
  if p_business_start is null
     or p_business_start > now()
     or p_business_start < now() - interval '36 hours'
     or p_days is null or p_days < 1 or p_days > 14 then
    raise exception 'DATE_RANGE_INVALID';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'business_start', d.business_start,
      'sales', coalesce(s.total, 0)::bigint
    ) order by d.business_start
  ), '[]'::jsonb)
    into v_trend
    from generate_series(p_days - 1, 0, -1) as offsets(day_offset)
    cross join lateral (
      select p_business_start - day_offset * interval '1 day' as business_start
    ) d
    cross join lateral (
      select sum(b.total_amount)::bigint as total
        from bills b
       where b.shop_id = v_shop
         and b.status = 'paid'
         and b.paid_at >= d.business_start
         and b.paid_at < least(d.business_start + interval '1 day', now())
    ) s;

  return v_trend;
end $$;

revoke all on function owner_sales_trend(timestamptz, integer) from public, anon;
grant execute on function owner_sales_trend(timestamptz, integer) to authenticated;


-- >>> 021_staff_otp_device_trust.sql
-- Nhân viên phải xác minh OTP trên từng thiết bị. Mỗi Auth session có một proof 60 ngày;
-- Flutter chỉ giữ proof trong secure storage, database chỉ giữ SHA-256 digest.
create table if not exists staff_trusted_devices (
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid not null,
  secret_hash bytea not null check (octet_length(secret_hash) = 32),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  primary key (user_id, session_id)
);
alter table staff_trusted_devices enable row level security;
revoke all on staff_trusted_devices from public, anon, authenticated;

-- user_metadata do chính người dùng sửa được (auth.updateUser), app_metadata thì không.
-- Chép account_kind sang app_metadata ngay lúc tạo tài khoản và chỉ tin bản chép đó,
-- để không ai tự gỡ nhãn "staff" nhằm né kiểm tra thiết bị.
create or replace function _stamp_account_kind() returns trigger
language plpgsql security definer set search_path = public, auth as $$
begin
  if not (coalesce(new.raw_app_meta_data, '{}'::jsonb) ? 'fore_account_kind') then
    new.raw_app_meta_data := coalesce(new.raw_app_meta_data, '{}'::jsonb)
      || jsonb_build_object('fore_account_kind', new.raw_user_meta_data->>'account_kind');
  end if;
  return new;
end $$;

drop trigger if exists stamp_account_kind on auth.users;
create trigger stamp_account_kind before insert on auth.users
  for each row execute function _stamp_account_kind();

-- Tài khoản có sẵn: lấy theo metadata hiện tại (đã có thể bị sửa, nên rà lại nếu nghi ngờ).
update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
     || jsonb_build_object('fore_account_kind', raw_user_meta_data->>'account_kind')
 where not (coalesce(raw_app_meta_data, '{}'::jsonb) ? 'fore_account_kind');

-- Tài khoản mới chưa có hàng staff nên account_kind chỉ nhận dạng luồng đăng ký;
-- khi có membership, role trong bảng staff vẫn là nguồn phân quyền quyết định.
create or replace function _auth_user_is_staff(p_user uuid) returns boolean
language sql stable security definer set search_path = public, auth as $$
  select exists (
    select 1 from staff s where s.auth_user_id = p_user and s.active and s.role = 'staff'
  ) or exists (
    select 1 from auth.users u
     where u.id = p_user and u.raw_app_meta_data->>'fore_account_kind' = 'staff'
  )
$$;

create or replace function staff_device_is_trusted() returns boolean
language sql stable security definer set search_path = public, auth, extensions as $$
  select case
    when auth.uid() is null then false
    when not _auth_user_is_staff(auth.uid()) then true
    else exists (
      select 1
        from staff_trusted_devices d
       where d.user_id = auth.uid()
         and d.session_id = nullif(auth.jwt()->>'session_id', '')::uuid
         and d.secret_hash = extensions.digest(
           coalesce(nullif(current_setting('request.headers', true), '')::jsonb
             ->> 'x-fore-device-token', ''), 'sha256')
         and d.expires_at > now()
    )
  end
$$;

create or replace function validate_staff_device() returns boolean
language sql stable security definer set search_path = public, auth as $$
  select staff_device_is_trusted()
$$;

create or replace function register_staff_device(p_secret text) returns timestamptz
language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  v_uid uuid := auth.uid();
  v_session uuid;
  v_expires timestamptz := now() + interval '60 days';
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if not _auth_user_is_staff(v_uid) then raise exception 'NOT_STAFF'; end if;
  if p_secret is null or p_secret !~ '^[A-Za-z0-9_-]{40,100}$' then
    raise exception 'DEVICE_TOKEN_INVALID';
  end if;
  if not exists (
    select 1 from jsonb_array_elements(coalesce(auth.jwt()->'amr', '[]'::jsonb)) method
     where method->>'method' in ('otp', 'signup')
  ) then raise exception 'OTP_REQUIRED'; end if;
  begin
    v_session := nullif(auth.jwt()->>'session_id', '')::uuid;
  exception when invalid_text_representation then
    raise exception 'SESSION_INVALID';
  end;
  if v_session is null then raise exception 'SESSION_INVALID'; end if;

  insert into staff_trusted_devices (user_id, session_id, secret_hash, expires_at)
  values (v_uid, v_session, extensions.digest(p_secret, 'sha256'), v_expires)
  on conflict (user_id, session_id) do update
    set secret_hash = excluded.secret_hash,
        created_at = now(),
        expires_at = excluded.expires_at;
  return v_expires;
end $$;

-- Chỉ email/số đã được Supabase Auth xác nhận mới được dùng để nhận lời mời.
create or replace function _my_verified_contacts(out phone text, out email text)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  if not staff_device_is_trusted() then raise exception 'STAFF_DEVICE_UNTRUSTED'; end if;
  select case when u.phone_confirmed_at is not null then normalize_phone(u.phone) end,
         case when u.email_confirmed_at is not null then lower(btrim(u.email)) end
    into phone, email
    from auth.users u
   where u.id = auth.uid();
end $$;

-- RLS and all RPCs that use _require_staff resolve this replacement dynamically.
create or replace function app_staff_id() returns uuid
language sql stable security definer set search_path = public as $$
  select s.id
    from staff s
   where s.auth_user_id = auth.uid()
     and s.active
     and s.shop_id = app_shop_id()
     and (s.role = 'owner' or staff_device_is_trusted())
$$;

revoke all on function _auth_user_is_staff(uuid), staff_device_is_trusted() from public, anon, authenticated;
revoke all on function validate_staff_device(), register_staff_device(text) from public, anon;
grant execute on function validate_staff_device(), register_staff_device(text) to authenticated;

