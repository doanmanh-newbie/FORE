-- Kiểm thử push FCM trong 09_admin.sql: đăng ký / gỡ token, RLS token, và hàng đợi owner_notifications
-- (đóng ca, hủy bill đã thu, yêu cầu sửa kho). Bọc trong transaction rồi rollback; KHÔNG chạy trên Supabase thật.
-- Chạy sau tests/00_supabase_stub.sql + dev/rebuild_test_database.sql. Đúng hết in "PUSH: TAT CA DEU DUNG".
\set ON_ERROR_STOP on
begin;

insert into auth.users (id, email) values
  ('97000000-0000-0000-0000-0000000000a1', 'chu97@test.invalid'),
  ('97000000-0000-0000-0000-0000000000b1', 'nv97@test.invalid'),
  ('97000000-0000-0000-0000-0000000000c1', 'khac97@test.invalid');
insert into shops (id, name) values ('97000000-0000-0000-0000-0000000000f1', 'Quán 97');
insert into staff (id, shop_id, auth_user_id, full_name, role) values
  ('97000000-0000-0000-0000-000000000011', '97000000-0000-0000-0000-0000000000f1', '97000000-0000-0000-0000-0000000000a1', 'Chủ 97', 'owner'),
  ('97000000-0000-0000-0000-000000000012', '97000000-0000-0000-0000-0000000000f1', '97000000-0000-0000-0000-0000000000b1', 'Lan', 'staff');
insert into user_settings (auth_user_id, active_shop_id) values
  ('97000000-0000-0000-0000-0000000000a1', '97000000-0000-0000-0000-0000000000f1'),
  ('97000000-0000-0000-0000-0000000000b1', '97000000-0000-0000-0000-0000000000f1');

do $test$
declare
  owner_u constant uuid := '97000000-0000-0000-0000-0000000000a1';
  staff_u constant uuid := '97000000-0000-0000-0000-0000000000b1';
  other_u constant uuid := '97000000-0000-0000-0000-0000000000c1';
  shop    constant uuid := '97000000-0000-0000-0000-0000000000f1';
  owner_s constant uuid := '97000000-0000-0000-0000-000000000011';
  staff_s constant uuid := '97000000-0000-0000-0000-000000000012';
  tok     constant text := 'fcm-token-97-aaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  sh uuid; b uuid; n int; msg text; r record;
begin
  -- ========== Token ==========
  set local session authorization authenticated;
  perform set_config('request.jwt.claim.sub', '', true);
  begin perform register_fcm_token(tok, 'android'); msg := 'ok';
  exception when others then get stacked diagnostics msg = message_text; end;
  if msg <> 'NOT_LOGGED_IN' then raise exception 'chua dang nhap: mong NOT_LOGGED_IN, nhan %', msg; end if;

  perform set_config('request.jwt.claim.sub', owner_u::text, true);
  begin perform register_fcm_token('ngan', 'android'); msg := 'ok';
  exception when others then get stacked diagnostics msg = message_text; end;
  if msg <> 'INPUT_INVALID' then raise exception 'token ngan: mong INPUT_INVALID, nhan %', msg; end if;

  perform register_fcm_token(tok, 'ANDROID');
  perform register_fcm_token(tok, 'android');            -- gọi lại: không trùng dòng
  perform register_fcm_token(tok || '-ios', 'symbian');  -- nền tảng lạ -> 'other'
  select count(*) into n from device_tokens;
  if n <> 2 then raise exception 'chu phai thay 2 token cua minh, nhan %', n; end if;
  if (select platform from device_tokens where token = tok || '-ios') <> 'other' then
    raise exception 'nen tang la phai luu other'; end if;

  -- RLS: người khác không thấy token của chủ; ghi trực tiếp bị chặn
  perform set_config('request.jwt.claim.sub', other_u::text, true);
  select count(*) into n from device_tokens;
  if n <> 0 then raise exception 'RLS: nguoi khac thay % token cua chu', n; end if;
  begin insert into device_tokens (token, user_id, platform) values (tok || '-x', other_u, 'web'); msg := 'ok';
  exception when others then get stacked diagnostics msg = returned_sqlstate; end;
  if msg <> '42501' then raise exception 'ghi thang device_tokens phai bi chan, nhan %', msg; end if;
  -- gỡ token của người khác: không có tác dụng
  perform unregister_fcm_token(tok);

  -- Máy dùng chung: người khác đăng nhập trên cùng máy -> token chuyển sang người đó
  perform register_fcm_token(tok, 'android');
  reset session authorization;
  if (select user_id from device_tokens where token = tok) <> other_u then
    raise exception 'token phai chuyen sang nguoi dang nhap moi'; end if;

  set local session authorization authenticated;
  perform set_config('request.jwt.claim.sub', owner_u::text, true);
  perform register_fcm_token(tok, 'android');
  perform unregister_fcm_token(tok || '-ios');
  select count(*) into n from device_tokens;
  if n <> 1 then raise exception 'sau khi go con 1 token, nhan %', n; end if;
  reset session authorization;

  -- ========== Hàng đợi thông báo cho chủ ==========
  insert into shifts (id, shop_id, opened_by) values (gen_random_uuid(), shop, staff_s) returning id into sh;
  -- Nhân viên đóng ca -> báo chủ
  update shifts set status = 'closed', closed_by = staff_s, closed_at = now(), closing_cash = 0 where id = sh;
  select * into r from owner_notifications where shop_id = shop and kind = 'shift_closed';
  if r.id is null or r.body not like 'Lan đã đóng ca%' or (r.data ->> 'shift_id')::uuid <> sh
     or (r.data ->> 'shop_id')::uuid <> shop or r.sent_at is not null then
    raise exception 'dong ca: thong bao sai: %', r; end if;
  -- Chủ tự đóng ca -> không báo
  insert into shifts (id, shop_id, opened_by) values (gen_random_uuid(), shop, owner_s) returning id into sh;
  update shifts set status = 'closed', closed_by = owner_s, closed_at = now(), closing_cash = 0 where id = sh;
  select count(*) into n from owner_notifications where shop_id = shop and kind = 'shift_closed';
  if n <> 1 then raise exception 'chu tu dong ca khong duoc bao, nhan % thong bao', n; end if;

  -- Hủy bill đã thu -> báo chủ; hủy bill chưa thu -> không
  insert into shifts (id, shop_id, opened_by) values (gen_random_uuid(), shop, staff_s) returning id into sh;
  insert into bills (shop_id, shift_id, bill_type, opened_by, status, payment_method, total_amount, paid_at, paid_by)
  values (shop, sh, 'take_away', staff_s, 'paid', 'cash', 45000, now(), staff_s) returning id into b;
  update bills set status = 'cancelled', cancelled_by = staff_s, cancelled_at = now(),
                   cancel_reason = 'Khách đổi ý', approved_by = owner_s where id = b;
  select * into r from owner_notifications where shop_id = shop and kind = 'paid_bill_cancelled';
  if r.id is null or r.body not like '%45000đ%Lan%Khách đổi ý%' or (r.data ->> 'bill_id')::uuid <> b then
    raise exception 'huy bill da thu: thong bao sai: %', r; end if;
  insert into bills (shop_id, shift_id, bill_type, opened_by) values (shop, sh, 'take_away', staff_s) returning id into b;
  update bills set status = 'cancelled', cancelled_by = staff_s, cancelled_at = now(), cancel_reason = 'Mở nhầm' where id = b;
  select count(*) into n from owner_notifications where shop_id = shop and kind = 'paid_bill_cancelled';
  if n <> 1 then raise exception 'huy bill chua thu khong duoc bao, nhan %', n; end if;

  -- Yêu cầu sửa kho -> báo chủ
  insert into inventory_requests (shop_id, kind, ref_id, note, created_by)
  values (shop, 'waste', gen_random_uuid(), 'Nhập nhầm 2kg đường', staff_s);
  select * into r from owner_notifications where shop_id = shop and kind = 'inventory_request';
  if r.id is null or r.body <> 'Lan: Nhập nhầm 2kg đường' or r.data ->> 'request_kind' <> 'waste' then
    raise exception 'yeu cau sua kho: thong bao sai: %', r; end if;

  -- RLS thông báo: chủ đọc được, nhân viên không
  set local session authorization authenticated;
  perform set_config('request.jwt.claim.sub', owner_u::text, true);
  select count(*) into n from owner_notifications;
  if n <> 3 then raise exception 'chu phai doc 3 thong bao cua quan, nhan %', n; end if;
  perform set_config('request.jwt.claim.sub', staff_u::text, true);
  select count(*) into n from owner_notifications;
  if n <> 0 then raise exception 'nhan vien khong duoc doc thong bao cua chu, nhan %', n; end if;
  reset session authorization;

  raise notice 'PUSH: TAT CA DEU DUNG';
end $test$;

rollback;
