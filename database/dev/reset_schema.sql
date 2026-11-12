-- FORE DATABASE RESET — DESTRUCTIVE
-- Run ONLY when you intentionally want to delete every Fore table, view, function,
-- policy, and business record in schema public, then reinstall the six grouped SQL modules.
-- Supabase Auth users in schema auth are not deleted. This does not back up data.
drop schema public cascade;
create schema public;
grant usage on schema public to postgres, anon, authenticated, service_role;
grant all on schema public to postgres, service_role;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
