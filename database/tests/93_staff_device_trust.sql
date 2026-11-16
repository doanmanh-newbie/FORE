-- Nhân viên đăng nhập bằng mật khẩu: không cần OTP/thiết bị tin cậy; số điện thoại đăng ký qua
-- email giả p<số>@phone.fore-staff.app vẫn khớp lời mời. Chạy trên DB test sau rebuild_test_database.sql.
begin;

insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, raw_app_meta_data)
values
  ('93000000-0000-0000-0000-000000000001', 'p84901234567@phone.fore-staff.app', now(),
   '{"account_kind":"staff"}', '{"fore_account_kind":"staff"}'),
  ('93000000-0000-0000-0000-000000000002', 'lan@test.invalid', now(),
   '{"account_kind":"staff"}', '{"fore_account_kind":"staff"}');

do $test$
declare v_phone text; v_email text;
begin
  perform set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000001', true);
  if not staff_device_is_trusted() then raise exception 'nhan vien dang nhap mat khau phai duoc coi la tin cay'; end if;
  select phone, email into v_phone, v_email from _my_verified_contacts();
  if v_phone is distinct from '84901234567' or v_email is not null then
    raise exception 'so dien thoai trong email gia phai khop loi moi, nhan %/%', v_phone, v_email; end if;

  perform set_config('request.jwt.claim.sub', '93000000-0000-0000-0000-000000000002', true);
  select phone, email into v_phone, v_email from _my_verified_contacts();
  if v_email is distinct from 'lan@test.invalid' or v_phone is not null then
    raise exception 'email that phai khop loi moi, nhan %/%', v_phone, v_email; end if;

  raise notice 'STAFF PASSWORD LOGIN: PASS';
end $test$;

rollback;
