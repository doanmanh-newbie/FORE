-- Mã quán: chủ lấy/đổi mã, nhân viên nhập mã là vào quán; mã sai và người đã bị gỡ thì bị chặn.
-- Chạy trên DB test sau rebuild_test_database.sql (không chạy trên Supabase thật).
begin;

insert into auth.users (id, email, raw_app_meta_data) values
  ('95000000-0000-0000-0000-0000000000a1', 'owner95@test.invalid', '{"fore_account_kind":"owner"}'),
  ('95000000-0000-0000-0000-0000000000b1', 'staff95@test.invalid', '{"fore_account_kind":"staff"}');
insert into shops (id, name) values ('95000000-0000-0000-0000-0000000000f1', 'Quán 95');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('95000000-0000-0000-0000-0000000000f1', '95000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner');
insert into user_settings (auth_user_id, active_shop_id) values
  ('95000000-0000-0000-0000-0000000000a1', '95000000-0000-0000-0000-0000000000f1');

do $test$
declare v_code text; v_code2 text; v_shop uuid; msg text;
begin
  perform set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-0000000000a1', true);
  v_code := shop_join_code();
  if v_code !~ '^[A-HJKMNP-Z2-9]{6}$' then raise exception 'ma quan sai dang: %', v_code; end if;
  if shop_join_code() <> v_code then raise exception 'xem lai phai giu nguyen ma'; end if;
  v_code2 := shop_join_code(true);
  if v_code2 = v_code then raise exception 'doi ma phai ra ma moi'; end if;

  perform set_config('request.jwt.claim.sub', '95000000-0000-0000-0000-0000000000b1', true);
  perform set_config('request.jwt.claims', '{"user_metadata":{"full_name":"Lan"}}', true);
  begin perform join_shop_by_code(v_code); msg := 'ok';
  exception when others then get stacked diagnostics msg = message_text; end;
  if msg <> 'SHOP_CODE_INVALID' then raise exception 'ma cu phai bi tu choi, nhan %', msg; end if;

  v_shop := join_shop_by_code(lower(v_code2));
  if v_shop <> '95000000-0000-0000-0000-0000000000f1'
     or not exists (select 1 from staff where auth_user_id = '95000000-0000-0000-0000-0000000000b1'
                     and shop_id = v_shop and active and full_name = 'Lan' and role = 'staff') then
    raise exception 'nhap ma dung phai thanh nhan vien cua quan'; end if;
  if app_shop_id() <> v_shop then raise exception 'phai chuyen sang quan vua vao'; end if;

  update staff set active = false where auth_user_id = '95000000-0000-0000-0000-0000000000b1';
  begin perform join_shop_by_code(v_code2); msg := 'ok';
  exception when others then get stacked diagnostics msg = message_text; end;
  if msg <> 'MEMBERSHIP_REVOKED' then raise exception 'nguoi bi go phai bi chan, nhan %', msg; end if;

  raise notice 'SHOP JOIN CODE: PASS';
end $test$;

rollback;
