-- Hồi quy lời mời cho đăng nhập nhân viên đơn giản: số điện thoại qua email giả nhận lời mời
-- ngay cả khi tài khoản cũ không có demo_phone metadata.
-- Chạy sau tests/00_supabase_stub.sql và 001..017. In "SMOKE: DUNG" nếu đúng.
-- File này TRUNCATE và DELETE dữ liệu; chỉ chạy trên database test riêng, KHÔNG chạy trên Supabase thật.
\set ON_ERROR_STOP on
truncate shops, user_settings, shop_invites, staff cascade;
delete from auth.users;
insert into auth.users (id,email,email_confirmed_at) values ('00000000-0000-0000-0000-0000000000a1','chu@test.vn',now());
insert into auth.users (id,email,email_confirmed_at) values ('00000000-0000-0000-0000-0000000000b1','p84901234567@phone.fore-staff.app',now());
insert into auth.users (id,email,email_confirmed_at) values ('00000000-0000-0000-0000-0000000000c1','nv@gmail.com',now());
do $t$
declare o text:='00000000-0000-0000-0000-0000000000a1'; s text:='00000000-0000-0000-0000-0000000000b1'; e text:='00000000-0000-0000-0000-0000000000c1';
 n int; msg text; r record; inv uuid;
begin
 if _auth_phone(null,null,'p84901234567@phone.fore-staff.app') <> '84901234567' then raise exception 'email gia -> so'; end if;
 if _auth_phone(null,null,'nv@gmail.com') is not null then raise exception 'email that khong phai so'; end if;
 if _auth_email('p84901234567@phone.fore-staff.app', now()) is not null then raise exception 'email gia khong phai email'; end if;
 perform set_config('request.jwt.claim.sub', o, true); set local session authorization authenticated;
 perform create_shop('Quán A','Chủ A');
 perform invite_staff('0901 234 567','Lan');
 perform invite_staff('', 'Hùng', 'NV@gmail.com');
 begin perform invite_staff('abc', 'Sai so', 'khac@gmail.com'); raise exception 'phai loi';
 exception when others then get stacked diagnostics msg = message_text; if msg <> 'PHONE_INVALID' then raise exception 'so sai kem email: got %', msg; end if; end;
 begin perform invite_staff('', 'Trong', ''); raise exception 'phai loi';
 exception when others then get stacked diagnostics msg = message_text; if msg <> 'CONTACT_REQUIRED' then raise exception 'rong: got %', msg; end if; end;
 reset session authorization;

 -- nhân viên đăng ký bằng SỐ ĐIỆN THOẠI (email giả) thấy lời mời gửi theo số
 perform set_config('request.jwt.claim.sub', s, true);
 perform set_config('request.jwt.claims', '{"user_metadata":{"full_name":"Lan Nguyen","birth_date":"2001-05-20"}}', true);
 set local session authorization authenticated;
 select count(*) into n from my_invites(); if n <> 1 then raise exception 'sdt: thay % loi moi', n; end if;
 select invite_id into inv from my_invites() limit 1;
 perform accept_invite(inv);
 select * into r from my_profile(); if r.role <> 'staff' or r.full_name <> 'Lan Nguyen' then raise exception 'profile %', r; end if;
 reset session authorization;
 if (select birth_date from staff where full_name='Lan Nguyen') <> date '2001-05-20' then raise exception 'ngay sinh'; end if;

 -- nhân viên đăng ký bằng EMAIL THẬT thấy lời mời gửi theo email
 perform set_config('request.jwt.claim.sub', e, true);
 perform set_config('request.jwt.claims', '{"user_metadata":{"full_name":"Hung"}}', true);
 set local session authorization authenticated;
 select count(*) into n from my_invites(); if n <> 1 then raise exception 'email: thay % loi moi', n; end if;
 reset session authorization;

 -- chủ: đội ngũ hiện đúng số, không lộ email giả; mời lại người đã là thành viên bị chặn
 perform set_config('request.jwt.claim.sub', o, true); set local session authorization authenticated;
 select * into r from shop_team() where full_name = 'Lan Nguyen';
 if r.phone <> '84901234567' or r.email is not null then raise exception 'team %', r; end if;
 begin perform invite_staff('0901234567','Lan lai'); raise exception 'phai loi';
 exception when others then get stacked diagnostics msg = message_text; if msg <> 'ALREADY_MEMBER' then raise exception 'got %', msg; end if; end;
 reset session authorization;
 raise notice 'SMOKE: DUNG';
end $t$;
