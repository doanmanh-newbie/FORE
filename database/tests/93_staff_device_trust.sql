-- Run only on the disposable local test database after rebuild_test_database.sql.
-- This test uses synthetic Auth claims and rolls back all inserted data.
begin;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values
  ('93000000-0000-0000-0000-000000000001', 'staff@test.invalid', now(), '{"account_kind":"staff","demo_email":"fake@test.invalid"}'),
  ('93000000-0000-0000-0000-000000000002', 'owner@test.invalid', null, '{"account_kind":"owner"}');
insert into shops (id, name, created_by)
values ('93000000-0000-0000-0000-000000000010', 'device trust test', '93000000-0000-0000-0000-000000000002');
insert into staff (id, shop_id, auth_user_id, full_name, role) values
  ('93000000-0000-0000-0000-000000000011', '93000000-0000-0000-0000-000000000010', '93000000-0000-0000-0000-000000000001', 'NV test', 'staff'),
  ('93000000-0000-0000-0000-000000000012', '93000000-0000-0000-0000-000000000010', '93000000-0000-0000-0000-000000000002', 'Owner test', 'owner');

do $test$
declare
  v_secret constant text := 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNO01234567';
  v_session constant text := '93000000-0000-0000-0000-000000000021';
  v_expires timestamptz;
  v_phone text;
  v_email text;
  v_message text;
begin
  -- OTP AMR plus the matching device proof registers a hash-backed 60-day session.
  perform set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000001', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '93000000-0000-0000-0000-000000000001',
    'session_id', v_session,
    'user_metadata', jsonb_build_object('account_kind', 'staff'),
    'amr', jsonb_build_array(jsonb_build_object('method', 'otp'))
  )::text, true);
  perform set_config('request.headers', jsonb_build_object('x-fore-device-token', v_secret)::text, true);
  v_expires := register_staff_device(v_secret);
  if v_expires < now() + interval '59 days 23 hours' or v_expires > now() + interval '60 days 1 hour' then
    raise exception 'device trust expiry must be 60 days: %', v_expires;
  end if;
  if not validate_staff_device() then raise exception 'registered device should validate'; end if;
  if app_staff_id() <> '93000000-0000-0000-0000-000000000011'::uuid then
    raise exception 'trusted staff should resolve a membership';
  end if;
  if (select octet_length(secret_hash) from staff_trusted_devices where user_id = auth.uid()) <> 32 then
    raise exception 'device secret must be stored as a SHA-256 digest';
  end if;

  -- Unverified metadata cannot match invitations, even when a fake alias is present.
  update auth.users set email_confirmed_at = null
   where id = '93000000-0000-0000-0000-000000000001';
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  if v_phone is not null or v_email is not null then
    raise exception 'verified contacts mismatch: phone %, email %', v_phone, v_email;
  end if;
  update auth.users set email_confirmed_at = now()
   where id = '93000000-0000-0000-0000-000000000001';
  select c.phone, c.email into v_phone, v_email from _my_verified_contacts() c;
  if v_email <> 'staff@test.invalid' then
    raise exception 'metadata alias must not replace verified Auth email: %', v_email;
  end if;

  perform set_config('request.headers', '{}', true);
  if validate_staff_device() then raise exception 'missing device proof must fail'; end if;
  if app_staff_id() is not null then raise exception 'RLS staff helper must reject missing proof'; end if;
  perform set_config('request.headers', jsonb_build_object('x-fore-device-token', repeat('x', 43))::text, true);
  if validate_staff_device() then raise exception 'wrong device proof must fail'; end if;

  -- Password-only sessions cannot mint trusted-device records.
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '93000000-0000-0000-0000-000000000001',
    'session_id', v_session,
    'user_metadata', jsonb_build_object('account_kind', 'staff'),
    'amr', jsonb_build_array(jsonb_build_object('method', 'password'))
  )::text, true);
  begin
    perform register_staff_device(v_secret);
    raise exception 'password-only registration must fail';
  exception when others then
    get stacked diagnostics v_message = message_text;
    if v_message <> 'OTP_REQUIRED' then raise; end if;
  end;

  -- Session binding and expiry independently invalidate an otherwise correct secret.
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '93000000-0000-0000-0000-000000000001',
    'session_id', '93000000-0000-0000-0000-000000000022',
    'user_metadata', jsonb_build_object('account_kind', 'staff'),
    'amr', jsonb_build_array(jsonb_build_object('method', 'otp'))
  )::text, true);
  perform set_config('request.headers', jsonb_build_object('x-fore-device-token', v_secret)::text, true);
  if validate_staff_device() then raise exception 'different Auth session must fail'; end if;

  update staff_trusted_devices set expires_at = now() - interval '1 second'
   where user_id = '93000000-0000-0000-0000-000000000001' and session_id = v_session::uuid;
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '93000000-0000-0000-0000-000000000001',
    'session_id', v_session,
    'user_metadata', jsonb_build_object('account_kind', 'staff'),
    'amr', jsonb_build_array(jsonb_build_object('method', 'otp'))
  )::text, true);
  if validate_staff_device() then raise exception 'expired device must fail'; end if;

  -- Owners keep the existing password flow and do not require a staff device proof.
  perform set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000002', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '93000000-0000-0000-0000-000000000002',
    'session_id', '93000000-0000-0000-0000-000000000023',
    'user_metadata', jsonb_build_object('account_kind', 'owner'),
    'amr', jsonb_build_array(jsonb_build_object('method', 'password'))
  )::text, true);
  perform set_config('request.headers', '{}', true);
  if not validate_staff_device() then raise exception 'owner must remain unaffected'; end if;

  -- Tự sửa user_metadata để gỡ nhãn staff không được né kiểm tra thiết bị
  -- (tài khoản chưa có hàng staff, chỉ được nhận diện qua app_metadata).
  insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
  values ('93000000-0000-0000-0000-000000000003', 'tamper@test.invalid', now(), '{"account_kind":"staff"}');
  if (select raw_app_meta_data->>'fore_account_kind' from auth.users
       where id = '93000000-0000-0000-0000-000000000003') is distinct from 'staff' then
    raise exception 'account_kind must be stamped into app_metadata on insert';
  end if;
  update auth.users set raw_user_meta_data = '{"account_kind":"owner"}'
   where id = '93000000-0000-0000-0000-000000000003';
  perform set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000003', true);
  perform set_config('request.jwt.claims', jsonb_build_object(
    'sub', '93000000-0000-0000-0000-000000000003',
    'session_id', '93000000-0000-0000-0000-000000000024',
    'user_metadata', jsonb_build_object('account_kind', 'owner'),
    'amr', jsonb_build_array(jsonb_build_object('method', 'otp'))
  )::text, true);
  perform set_config('request.headers', '{}', true);
  if validate_staff_device() then
    raise exception 'editing user_metadata must not bypass the staff device check';
  end if;

  raise notice 'STAFF DEVICE TRUST: PASS';
end
$test$;

rollback;
