-- =====================================================================
-- Fore · 09_admin.sql · Quản trị nền tảng (super-admin) + chức năng kiểu Firebase
--  1) Bảng: platform_admins, error_logs, events, app_config, login_ips
--  2) is_platform_admin(): người đang đăng nhập có phải super-admin không
--  3) RPC cho app (mọi người đã đăng nhập): log_error, log_event, record_login, get_app_config
--  4) RPC cho admin web (chỉ super-admin, sai thì 'FORBIDDEN'):
--     admin_list_shops, admin_list_users, admin_list_errors, admin_event_counts,
--     admin_list_logins, admin_set_config
--  5) RLS: người dùng chỉ ghi/đọc dòng của chính mình; super-admin đọc toàn bộ
--
-- Cấp quyền super-admin: KHÔNG có màn hình tự đăng ký. Chèn tay bằng SQL Editor:
--   insert into platform_admins (user_id) values ('<auth.users.id>');
--
-- Chạy SAU 08_settings.sql (cần bảng shops, staff, bills của nhiều quán).
-- File chạy lại được nhiều lần (create ... if not exists / create or replace / drop policy if exists).
-- =====================================================================

-- ---------- 1) Bảng ----------

-- Danh sách super-admin của nền tảng (không thuộc quán nào)
create table if not exists platform_admins (
  user_id     uuid primary key,                    -- auth.users.id
  created_at  timestamptz not null default now()
);

-- Lỗi app gửi lên (FlutterError.onError, PlatformDispatcher.onError)
create table if not exists error_logs (
  id           bigint generated always as identity primary key,
  created_at   timestamptz not null default now(),
  user_id      uuid default auth.uid(),            -- auth.users.id
  shop_id      uuid references shops(id),          -- quán đang chọn lúc lỗi (có thể null)
  app_version  text,
  platform     text,                               -- android / ios / web ...
  message      text not null,
  stack        text,
  context      jsonb
);
create index if not exists error_logs_created_idx on error_logs (created_at desc, id desc);
create index if not exists error_logs_user_idx    on error_logs (user_id, created_at desc);

-- Sự kiện sử dụng (mở ca, đóng ca, thanh toán...)
create table if not exists events (
  id          bigint generated always as identity primary key,
  created_at  timestamptz not null default now(),
  user_id     uuid default auth.uid(),
  shop_id     uuid references shops(id),
  name        text not null,
  props       jsonb
);
create index if not exists events_created_idx   on events (created_at);
create index if not exists events_name_time_idx on events (name, created_at);
create index if not exists events_user_idx      on events (user_id, created_at desc);

-- Cấu hình từ xa (bảo trì, phiên bản tối thiểu...). Khác app_settings (con số của từng quán).
create table if not exists app_config (
  key         text primary key check (key ~ '^[a-z0-9_.]{1,64}$'),
  value       jsonb not null,
  updated_at  timestamptz not null default now(),
  updated_by  uuid                                 -- auth.users.id của super-admin sửa gần nhất
);

-- Lịch sử IP đăng nhập (ghi qua record_login, IP lấy từ header của PostgREST, app không tự khai)
create table if not exists login_ips (
  id          bigint generated always as identity primary key,
  user_id     uuid not null default auth.uid(),
  ip          text,                                -- text: header có thể không phải IP hợp lệ, không làm hỏng lần ghi
  user_agent  text,
  created_at  timestamptz not null default now()
);
create index if not exists login_ips_user_idx    on login_ips (user_id, created_at desc);
create index if not exists login_ips_created_idx on login_ips (created_at desc);

-- ---------- 2) Kiểm tra super-admin ----------
create or replace function is_platform_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from platform_admins where user_id = auth.uid())
$$;

-- Hàm nội bộ: shop_id gửi lên chỉ được giữ nếu người gọi đúng là thành viên quán đó;
-- không có thì lấy quán đang chọn. Không raise lỗi để hàm ghi log không bao giờ làm app lỗi thêm.
create or replace function _log_shop_id(p_shop_id uuid) returns uuid
language sql stable security definer set search_path = public as $$
  select case
           when p_shop_id is null then app_shop_id()
           when p_shop_id in (select _my_shop_ids()) then p_shop_id
           else null
         end
$$;

-- ---------- 3) RPC cho app ----------

-- Ghi một lỗi của app. Trả về id dòng vừa ghi.
create or replace function log_error(
  p_message     text,
  p_stack       text  default null,
  p_shop_id     uuid  default null,
  p_app_version text  default null,
  p_platform    text  default null,
  p_context     jsonb default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_id bigint;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  insert into error_logs (user_id, shop_id, app_version, platform, message, stack, context)
  values (v_uid,
          _log_shop_id(p_shop_id),
          left(nullif(btrim(p_app_version), ''), 50),
          left(nullif(btrim(p_platform), ''), 30),
          left(coalesce(nullif(btrim(p_message), ''), '(không có nội dung)'), 2000),
          left(p_stack, 20000),
          p_context)
  returning id into v_id;
  return v_id;
end $$;

-- Ghi một sự kiện sử dụng. Trả về id dòng vừa ghi.
create or replace function log_event(
  p_name    text,
  p_props   jsonb default null,
  p_shop_id uuid  default null
) returns bigint
language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_name text := btrim(p_name); v_id bigint;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  if v_name is null or v_name !~ '^[a-z0-9_.]{1,64}$' then raise exception 'INPUT_INVALID'; end if;
  insert into events (user_id, shop_id, name, props)
  values (v_uid, _log_shop_id(p_shop_id), v_name, p_props)
  returning id into v_id;
  return v_id;
end $$;

-- Ghi IP + user agent sau khi đăng nhập. IP lấy từ header x-forwarded-for do PostgREST chuyển vào
-- (phần tử đầu tiên là IP của máy khách); app không truyền IP nên không tự khai sai được.
create or replace function record_login() returns void
language plpgsql security definer set search_path = public as $$
declare
  v_uid     uuid := auth.uid();
  v_headers json;
  v_ip      text;
begin
  if v_uid is null then raise exception 'NOT_LOGGED_IN'; end if;
  v_headers := nullif(current_setting('request.headers', true), '')::json;
  v_ip := nullif(btrim(split_part(v_headers ->> 'x-forwarded-for', ',', 1)), '');
  insert into login_ips (user_id, ip, user_agent)
  values (v_uid, left(v_ip, 64), left(nullif(btrim(v_headers ->> 'user-agent'), ''), 500));
end $$;

-- Toàn bộ cấu hình từ xa dạng một object: {"maintenance": false, "min_version": "1.2.0", ...}
create or replace function get_app_config() returns jsonb
language plpgsql stable security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'NOT_LOGGED_IN'; end if;
  return coalesce((select jsonb_object_agg(c.key, c.value) from app_config c), '{}'::jsonb);
end $$;

-- ---------- 4) RPC cho admin web (đầu hàm luôn kiểm tra super-admin) ----------

-- Danh sách quán
create or replace function admin_list_shops()
returns table (
  id            uuid,
  name          text,
  code          text,
  created_at    timestamptz,
  owner_user_id uuid,
  owner_name    text,
  owner_email   text,
  member_count  bigint,
  last_bill_at  timestamptz
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  return query
  select s.id, s.name, s.code, s.created_at,
         o.auth_user_id, o.full_name, u.email::text,
         (select count(*) from staff m where m.shop_id = s.id and m.active),
         (select max(b.opened_at) from bills b where b.shop_id = s.id)
    from shops s
    left join lateral (
      select st.auth_user_id, st.full_name from staff st
       where st.shop_id = s.id and st.role = 'owner' and st.active
       order by st.created_at, st.id limit 1
    ) o on true
    left join auth.users u on u.id = o.auth_user_id
   order by s.created_at desc, s.id;
end $$;

-- Danh sách người dùng (tìm theo email / số điện thoại / tên), phân trang bằng limit/offset.
-- total_count = tổng số dòng khớp tìm kiếm (giống nhau trên mọi dòng) để admin web tính số trang.
create or replace function admin_list_users(
  p_search text    default null,
  p_limit  integer default 50,
  p_offset integer default 0
)
returns table (
  user_id           uuid,
  email             text,
  phone             text,
  full_name         text,
  shop_count        bigint,
  shop_names        text,
  last_login_at     timestamptz,
  is_platform_admin boolean,
  total_count       bigint
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare
  v_q      text    := lower(nullif(btrim(p_search), ''));
  v_limit  integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if not is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  return query
  with base as (
    select u.id, u.email::text as email, u.phone::text as phone,
           nullif(btrim(u.raw_user_meta_data ->> 'full_name'), '') as full_name
      from auth.users u
  ), filtered as (
    select b.* from base b
     where v_q is null
        or position(v_q in lower(coalesce(b.email, ''))) > 0
        or position(v_q in lower(coalesce(b.phone, ''))) > 0
        or position(v_q in lower(coalesce(b.full_name, ''))) > 0
  )
  select f.id, f.email, f.phone, f.full_name,
         (select count(*) from staff m where m.auth_user_id = f.id and m.active),
         (select string_agg(sh.name, ', ' order by sh.name)
            from staff m join shops sh on sh.id = m.shop_id
           where m.auth_user_id = f.id and m.active),
         (select max(l.created_at) from login_ips l where l.user_id = f.id),
         exists (select 1 from platform_admins pa where pa.user_id = f.id),
         count(*) over ()
    from filtered f
   order by f.email nulls last, f.id
   limit v_limit offset v_offset;
end $$;

-- Nhật ký lỗi mới nhất trước. Trang sau: truyền p_before = created_at của dòng cuối trang trước.
create or replace function admin_list_errors(
  p_limit  integer     default 50,
  p_before timestamptz default null
)
returns table (
  id          bigint,
  created_at  timestamptz,
  user_id     uuid,
  user_email  text,
  shop_id     uuid,
  shop_name   text,
  app_version text,
  platform    text,
  message     text,
  stack       text,
  context     jsonb
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_limit integer := least(greatest(coalesce(p_limit, 50), 1), 200);
begin
  if not is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  return query
  select e.id, e.created_at, e.user_id, u.email::text, e.shop_id, s.name,
         e.app_version, e.platform, e.message, e.stack, e.context
    from error_logs e
    left join auth.users u on u.id = e.user_id
    left join shops s on s.id = e.shop_id
   where p_before is null or e.created_at < p_before
   order by e.created_at desc, e.id desc
   limit v_limit;
end $$;

-- Thống kê sự kiện theo NGÀY (giờ Việt Nam) và tên sự kiện, trong [p_from, p_to).
create or replace function admin_event_counts(
  p_from timestamptz,
  p_to   timestamptz
)
returns table (
  day         date,
  name        text,
  event_count bigint,
  user_count  bigint
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
begin
  if not is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  if p_from is null or p_to is null or p_from >= p_to or p_to - p_from > interval '366 days' then
    raise exception 'DATE_RANGE_INVALID';
  end if;
  return query
  select (e.created_at at time zone 'Asia/Ho_Chi_Minh')::date as d, e.name,
         count(*), count(distinct e.user_id)
    from events e
   where e.created_at >= p_from and e.created_at < p_to
   group by d, e.name
   order by d, e.name;
end $$;

-- IP đăng nhập, mới nhất trước. p_user_id = null: của mọi người dùng.
create or replace function admin_list_logins(
  p_user_id uuid    default null,
  p_limit   integer default 100
)
returns table (
  id         bigint,
  user_id    uuid,
  user_email text,
  ip         text,
  user_agent text,
  created_at timestamptz
)
language plpgsql stable security definer set search_path = public as $$
#variable_conflict use_column
declare v_limit integer := least(greatest(coalesce(p_limit, 100), 1), 500);
begin
  if not is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  return query
  select l.id, l.user_id, u.email::text, l.ip, l.user_agent, l.created_at
    from login_ips l
    left join auth.users u on u.id = l.user_id
   where p_user_id is null or l.user_id = p_user_id
   order by l.created_at desc, l.id desc
   limit v_limit;
end $$;

-- Thêm hoặc sửa một khóa cấu hình từ xa. Trả về dòng sau khi lưu.
create or replace function admin_set_config(
  p_key   text,
  p_value jsonb
) returns app_config
language plpgsql security definer set search_path = public as $$
declare v_key text := lower(btrim(p_key)); v_row app_config;
begin
  if not is_platform_admin() then raise exception 'FORBIDDEN'; end if;
  if v_key is null or v_key !~ '^[a-z0-9_.]{1,64}$' or p_value is null then
    raise exception 'INPUT_INVALID';
  end if;
  insert into app_config as c (key, value, updated_at, updated_by)
  values (v_key, p_value, now(), auth.uid())
  on conflict (key) do update
    set value = excluded.value, updated_at = excluded.updated_at, updated_by = excluded.updated_by
  returning c.* into v_row;
  return v_row;
end $$;

-- ---------- 5) Phân quyền (RLS) ----------
alter table platform_admins enable row level security;
alter table error_logs      enable row level security;
alter table events          enable row level security;
alter table app_config      enable row level security;
alter table login_ips       enable row level security;

-- Thu hết quyền rồi cấp lại tối thiểu. Không ai có quyền UPDATE/DELETE trực tiếp:
-- dọn log cũ chỉ làm bằng SQL Editor (quyền quản trị).
revoke all on platform_admins, error_logs, events, app_config, login_ips from public, anon, authenticated;

-- platform_admins: mỗi người chỉ thấy dòng của mình; super-admin thấy cả danh sách. Không ghi trực tiếp.
grant select on platform_admins to authenticated;
drop policy if exists platform_admins_read on platform_admins;
create policy platform_admins_read on platform_admins for select to authenticated
  using (user_id = (select auth.uid()) or (select is_platform_admin()));

-- error_logs, events: ghi được dòng của CHÍNH MÌNH (app thường đi qua log_error/log_event);
-- đọc dòng của mình; super-admin đọc toàn bộ.
grant select, insert (user_id, shop_id, app_version, platform, message, stack, context) on error_logs to authenticated;
drop policy if exists error_logs_insert_own on error_logs;
drop policy if exists error_logs_read       on error_logs;
create policy error_logs_insert_own on error_logs for insert to authenticated
  with check (user_id = (select auth.uid())
              and (shop_id is null or shop_id in (select _my_shop_ids())));
create policy error_logs_read on error_logs for select to authenticated
  using (user_id = (select auth.uid()) or (select is_platform_admin()));

grant select, insert (user_id, shop_id, name, props) on events to authenticated;
drop policy if exists events_insert_own on events;
drop policy if exists events_read       on events;
create policy events_insert_own on events for insert to authenticated
  with check (user_id = (select auth.uid())
              and (shop_id is null or shop_id in (select _my_shop_ids())));
create policy events_read on events for select to authenticated
  using (user_id = (select auth.uid()) or (select is_platform_admin()));

-- login_ips: chỉ ghi qua record_login() (IP phải lấy từ header, không cho app tự khai);
-- đọc dòng của mình; super-admin đọc toàn bộ.
grant select on login_ips to authenticated;
drop policy if exists login_ips_read on login_ips;
create policy login_ips_read on login_ips for select to authenticated
  using (user_id = (select auth.uid()) or (select is_platform_admin()));

-- app_config: app đọc qua get_app_config(); chỉ super-admin đọc trực tiếp; ghi qua admin_set_config().
grant select on app_config to authenticated;
drop policy if exists app_config_admin_read on app_config;
create policy app_config_admin_read on app_config for select to authenticated
  using ((select is_platform_admin()));

-- ---------- Quyền chạy hàm ----------
revoke all on function _log_shop_id(uuid) from public, anon, authenticated;

revoke all on function
  is_platform_admin(),
  log_error(text, text, uuid, text, text, jsonb),
  log_event(text, jsonb, uuid),
  record_login(),
  get_app_config(),
  admin_list_shops(),
  admin_list_users(text, integer, integer),
  admin_list_errors(integer, timestamptz),
  admin_event_counts(timestamptz, timestamptz),
  admin_list_logins(uuid, integer),
  admin_set_config(text, jsonb)
from public, anon;

grant execute on function
  is_platform_admin(),
  log_error(text, text, uuid, text, text, jsonb),
  log_event(text, jsonb, uuid),
  record_login(),
  get_app_config(),
  admin_list_shops(),
  admin_list_users(text, integer, integer),
  admin_list_errors(integer, timestamptz),
  admin_event_counts(timestamptz, timestamptz),
  admin_list_logins(uuid, integer),
  admin_set_config(text, jsonb)
to authenticated;
