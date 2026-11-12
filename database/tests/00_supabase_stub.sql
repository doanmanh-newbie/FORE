-- CHỈ DÙNG KHI TEST TRÊN POSTGRES THƯỜNG (không phải Supabase).
-- Giả lập schema auth và các role mà Supabase có sẵn. KHÔNG chạy file này trên Supabase.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end $$;
create schema if not exists auth;
create schema if not exists extensions;
create table if not exists auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb not null default '{}'::jsonb
);
alter table auth.users add column if not exists phone text;
alter table auth.users add column if not exists phone_confirmed_at timestamptz;
alter table auth.users add column if not exists email_confirmed_at timestamptz;
alter table auth.users add column if not exists raw_user_meta_data jsonb not null default '{}'::jsonb;
alter table auth.users add column if not exists raw_app_meta_data jsonb not null default '{}'::jsonb;
create or replace function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema public, auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;
-- auth.jwt(): claims của người đang đăng nhập (test đặt bằng set_config('request.jwt.claims', '{"user_metadata":{...}}', true))
create or replace function auth.jwt() returns jsonb language sql stable as $$
  select coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
grant execute on function auth.jwt() to anon, authenticated;
