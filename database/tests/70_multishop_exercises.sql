-- Kiểm thử NHIỀU QUÁN: tạo quán, mời bằng số điện thoại, chấp nhận, cô lập dữ liệu giữa các quán.
-- Chạy sau tests/00_supabase_stub.sql và 001..010. In "SMOKE: DUNG" nếu đúng. KHÔNG chạy trên Supabase thật.
\set ON_ERROR_STOP on
truncate shops, user_settings, shop_invites, staff cascade;
delete from auth.users;
insert into auth.users (id,email,email_confirmed_at) values ('00000000-0000-0000-0000-0000000000a1','chu@test',now());
insert into auth.users (id,phone,phone_confirmed_at) values ('00000000-0000-0000-0000-0000000000b1','84901234567',now());
insert into auth.users (id,phone,phone_confirmed_at) values ('00000000-0000-0000-0000-0000000000c1','84999999999',now());
do $t$
declare o text:='00000000-0000-0000-0000-0000000000a1'; s text:='00000000-0000-0000-0000-0000000000b1'; x text:='00000000-0000-0000-0000-0000000000c1';
 shop uuid; inv uuid; n int; r record; sh2 uuid; msg text; area_b uuid; item_b uuid;
begin
 perform set_config('request.jwt.claim.sub', o, true); set local session authorization authenticated;
 shop := create_shop('Quán A','Chủ A');
 insert into ingredients(name,unit) values ('Sữa','ml');
 inv := invite_staff('0901 234 567','Lan');
 begin perform invite_staff('0901234567','Lan2'); raise exception 'phai loi'; exception when others then get stacked diagnostics msg=message_text; if msg<>'ALREADY_INVITED' then raise exception 'got %',msg; end if; end;
 begin perform invite_staff('abc','L'); raise exception 'phai loi'; exception when others then get stacked diagnostics msg=message_text; if msg<>'PHONE_INVALID' then raise exception 'got %',msg; end if; end;
 select count(*) into n from shop_invites; if n<>1 then raise exception 'owner thay % loi moi',n; end if;
 select count(*) into n from shop_team(); if n<>1 then raise exception 'team %',n; end if;
 reset session authorization;
 -- nhân viên: chưa có quán
 perform set_config('request.jwt.claim.sub', s, true); set local session authorization authenticated;
 select count(*) into n from my_profile(); if n<>0 then raise exception 'profile phai rong'; end if;
 select count(*) into n from ingredients; if n<>0 then raise exception 'thay du lieu khi chua vao quan: %',n; end if;
 select count(*) into n from my_invites(); if n<>1 then raise exception 'invites %',n; end if;
 begin perform open_shift(0); raise exception 'phai loi'; exception when others then get stacked diagnostics msg=message_text; if msg<>'NOT_STAFF' then raise exception 'got %',msg; end if; end;
 reset session authorization;
 -- người lạ không accept được
 perform set_config('request.jwt.claim.sub', x, true); set local session authorization authenticated;
 select count(*) into n from my_invites(); if n<>0 then raise exception 'nguoi la thay loi moi'; end if;
 begin perform accept_invite(inv); raise exception 'phai loi'; exception when others then get stacked diagnostics msg=message_text; if msg<>'INVITE_NOT_FOUND' then raise exception 'got %',msg; end if; end;
 reset session authorization;
 -- nhân viên chấp nhận
 perform set_config('request.jwt.claim.sub', s, true); set local session authorization authenticated;
 perform accept_invite(inv);
 select count(*) into n from ingredients; if n<>1 then raise exception 'sau accept phai thay 1 nguyen lieu: %',n; end if;
 select * into r from my_profile(); if r.role<>'staff' or r.full_name<>'Lan' or r.shop_name<>'Quán A' then raise exception 'profile sai'; end if;
 perform open_shift(100000);
 begin perform set_staff_pin((select id from staff limit 1),'1234'); raise exception 'phai loi'; exception when others then get stacked diagnostics msg=message_text; if msg<>'OWNER_ONLY' then raise exception 'got %',msg; end if; end;
 begin perform invite_staff('0911111111','X'); raise exception 'phai loi'; exception when others then get stacked diagnostics msg=message_text; if msg<>'OWNER_ONLY' then raise exception 'got %',msg; end if; end;
 reset session authorization;
 -- nhân viên tạo quán B, cô lập dữ liệu
 perform set_config('request.jwt.claim.sub', s, true); set local session authorization authenticated;
 sh2 := create_shop('Quán B','Lan chủ');
 insert into areas (name) values ('Tầng B') returning id into area_b;
 insert into menu_items (name) values ('Món B') returning id into item_b;
 select count(*) into n from ingredients; if n<>0 then raise exception 'quan B phai trong: %',n; end if;
 select count(*) into n from current_shift(); if n<>0 then raise exception 'ca quan A lot sang B'; end if;
 select count(*) into n from my_shops(); if n<>2 then raise exception 'my_shops %',n; end if;
 perform select_shop(shop);
 select count(*) into n from ingredients; if n<>1 then raise exception 'quay lai A: %',n; end if;
 select count(*) into n from current_shift(); if n<>1 then raise exception 'ca A mat'; end if;
 -- Khóa ngoại cùng quán: chèn bằng quyền cao hơn RLS (RLS là lớp chặn thứ nhất, khóa ngoại là lớp thứ hai).
 reset session authorization;
 begin
   insert into dining_tables (shop_id, area_id, name) values (shop, area_b, 'Bàn sai quán');
   raise exception 'phai chan ban tham chieu khu cua quan khac';
 exception when foreign_key_violation then null; end;
 begin
   insert into menu_sizes (shop_id, item_id, size_name, price) values (shop, item_b, 'M', 10000);
   raise exception 'phai chan size tham chieu mon cua quan khac';
 exception when foreign_key_violation then null; end;
 perform set_config('request.jwt.claim.sub', s, true); set local session authorization authenticated;
 begin perform select_shop('00000000-0000-0000-0000-000000000000'); raise exception 'phai loi'; exception when others then get stacked diagnostics msg=message_text; if msg<>'NOT_STAFF' then raise exception 'got %',msg; end if; end;
 reset session authorization;
 raise notice 'SMOKE: DUNG';
end $t$;
