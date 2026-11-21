-- Kiểm thử 09_admin.sql: chặn người thường gọi RPC admin (FORBIDDEN), super-admin gọi được và nhận đúng dữ liệu,
-- RLS: người dùng không đọc được error_logs / events / login_ips của người khác.
-- Chạy trên DB test sau tests/00_supabase_stub.sql + 01..08 (hoặc dev/rebuild_test_database.sql) + 09_admin.sql.
-- Không xóa dữ liệu (bọc trong transaction rồi rollback). KHÔNG chạy trên Supabase thật.
-- Đúng hết sẽ in "ADMIN: TAT CA DEU DUNG".
\set ON_ERROR_STOP on
begin;

-- A: chủ quán 1 (sẽ được cấp super-admin ở giữa test); B: chủ quán 2 (người thường)
insert into auth.users (id, email, raw_user_meta_data) values
  ('96000000-0000-0000-0000-0000000000a1', 'a96@test96.invalid', '{"full_name":"An 96"}'),
  ('96000000-0000-0000-0000-0000000000b1', 'b96@test96.invalid', '{"full_name":"Bình 96"}');
insert into shops (id, name) values
  ('96000000-0000-0000-0000-0000000000f1', 'Quán 96 A'),
  ('96000000-0000-0000-0000-0000000000f2', 'Quán 96 B');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('96000000-0000-0000-0000-0000000000f1', '96000000-0000-0000-0000-0000000000a1', 'An', 'owner'),
  ('96000000-0000-0000-0000-0000000000f2', '96000000-0000-0000-0000-0000000000b1', 'Bình', 'owner');
insert into user_settings (auth_user_id, active_shop_id) values
  ('96000000-0000-0000-0000-0000000000a1', '96000000-0000-0000-0000-0000000000f1'),
  ('96000000-0000-0000-0000-0000000000b1', '96000000-0000-0000-0000-0000000000f2');

do $test$
declare
  a      constant uuid := '96000000-0000-0000-0000-0000000000a1';
  b      constant uuid := '96000000-0000-0000-0000-0000000000b1';
  shop_a constant uuid := '96000000-0000-0000-0000-0000000000f1';
  shop_b constant uuid := '96000000-0000-0000-0000-0000000000f2';
  admin_calls constant text[] := array[
    'select * from admin_list_shops()',
    'select * from admin_list_users(null, 10, 0)',
    'select * from admin_list_errors(10, null)',
    'select * from admin_event_counts(now() - interval ''1 day'', now() + interval ''1 day'')',
    'select * from admin_list_logins(null, 10)',
    'select * from admin_set_config(''maintenance'', ''true''::jsonb)'
  ];
  q text; msg text; st text; n int; v_id bigint; r record; cfg jsonb;
begin
  -- ========== Chuẩn bị: mỗi người ghi 1 lỗi, 1 sự kiện, 1 lần đăng nhập (qua RPC, đúng role authenticated) ==========
  set local session authorization authenticated;
  perform set_config('request.headers', '{"x-forwarded-for":"203.0.113.5, 10.0.0.1","user-agent":"FlutterTest/1.0"}', true);

  perform set_config('request.jwt.claim.sub', a::text, true);
  v_id := log_error('Lỗi của A', 'stack A', null, '1.0.0', 'android', '{"screen":"pos"}');
  if v_id is null then raise exception 'log_error phai tra ve id'; end if;
  perform log_event('test96_shift_open', '{"cash":0}');
  perform record_login();
  -- shop_id của quán mình không thuộc về thì không được giữ (lưu null)
  perform log_error('A ghi nham quan B', null, shop_b);

  perform set_config('request.jwt.claim.sub', b::text, true);
  perform log_error('Lỗi của B', 'stack B', shop_b, '1.0.1', 'ios', null);
  perform log_event('test96_shift_open', null);
  perform record_login();

  begin perform log_event('Ten Sai!', null); msg := 'ok';
  exception when others then get stacked diagnostics msg = message_text; end;
  if msg <> 'INPUT_INVALID' then raise exception 'log_event ten sai: mong INPUT_INVALID, nhan %', msg; end if;

  reset session authorization;
  -- Kiểm tra dữ liệu đã ghi (quyền quản trị, bỏ qua RLS)
  if not exists (select 1 from error_logs where user_id = a and message = 'Lỗi của A' and shop_id = shop_a
                  and app_version = '1.0.0' and platform = 'android' and context ->> 'screen' = 'pos') then
    raise exception 'log_error: dong cua A sai (shop_id phai lay quan dang chon)'; end if;
  if not exists (select 1 from error_logs where user_id = a and message = 'A ghi nham quan B' and shop_id is null) then
    raise exception 'log_error: shop_id quan khong thuoc ve phai luu null'; end if;
  select count(*) into n from login_ips where user_id in (a, b) and ip = '203.0.113.5' and user_agent = 'FlutterTest/1.0';
  if n <> 2 then raise exception 'record_login: mong 2 dong IP 203.0.113.5, nhan %', n; end if;

  -- ========== 1) Người thường gọi RPC admin: FORBIDDEN ==========
  set local session authorization authenticated;
  perform set_config('request.jwt.claim.sub', a::text, true);
  if is_platform_admin() then raise exception 'A chua duoc cap ma is_platform_admin() = true'; end if;
  foreach q in array admin_calls loop
    begin execute q; msg := 'ok';
    exception when others then get stacked diagnostics msg = message_text; end;
    if msg <> 'FORBIDDEN' then raise exception 'Nguoi thuong goi [%]: mong FORBIDDEN, nhan %', q, msg; end if;
  end loop;

  -- ========== 3) RLS: A không đọc được dòng của B, không ghi giả danh B ==========
  select count(*) into n from error_logs where user_id = b;
  if n <> 0 then raise exception 'RLS error_logs: A doc duoc % dong cua B', n; end if;
  select count(*) into n from events where user_id = b;
  if n <> 0 then raise exception 'RLS events: A doc duoc % dong cua B', n; end if;
  select count(*) into n from login_ips where user_id = b;
  if n <> 0 then raise exception 'RLS login_ips: A doc duoc % dong cua B', n; end if;
  -- ... nhưng đọc được dòng của chính mình
  select count(*) into n from error_logs where user_id = a;
  if n <> 2 then raise exception 'RLS error_logs: A phai doc duoc 2 dong cua minh, nhan %', n; end if;
  select count(*) into n from events where user_id = a;
  if n <> 1 then raise exception 'RLS events: A phai doc duoc 1 dong cua minh, nhan %', n; end if;
  select count(*) into n from login_ips where user_id = a;
  if n <> 1 then raise exception 'RLS login_ips: A phai doc duoc 1 dong cua minh, nhan %', n; end if;
  -- Người thường không đọc trực tiếp app_config, không thấy danh sách super-admin của người khác
  select count(*) into n from app_config;
  if n <> 0 then raise exception 'RLS app_config: nguoi thuong doc duoc % dong', n; end if;

  begin insert into error_logs (user_id, message) values (b, 'gia danh B'); st := 'ok';
  exception when others then get stacked diagnostics st = returned_sqlstate; end;
  if st <> '42501' then raise exception 'Ghi error_logs gia danh B phai bi chan (42501), nhan %', st; end if;
  begin insert into events (user_id, name) values (b, 'gia_danh'); st := 'ok';
  exception when others then get stacked diagnostics st = returned_sqlstate; end;
  if st <> '42501' then raise exception 'Ghi events gia danh B phai bi chan (42501), nhan %', st; end if;
  begin insert into login_ips (user_id, ip) values (a, '1.2.3.4'); st := 'ok';
  exception when others then get stacked diagnostics st = returned_sqlstate; end;
  if st <> '42501' then raise exception 'Ghi thang login_ips phai bi chan (42501), nhan %', st; end if;
  -- Ghi trực tiếp dòng của chính mình thì được, kể cả kèm shop_id quán mình
  -- (policy không được gọi hàm mà authenticated không có quyền, ví dụ _my_shop_ids)
  insert into events (user_id, name) values (a, 'test96_direct');
  insert into events (user_id, shop_id, name) values (a, shop_a, 'test96_direct_shop');
  insert into error_logs (user_id, shop_id, message) values (a, shop_a, 'ghi thang kem quan');
  -- ... nhưng kèm quán mình không thuộc về thì bị chặn
  begin insert into events (user_id, shop_id, name) values (a, shop_b, 'quan_nguoi_khac'); st := 'ok';
  exception when others then get stacked diagnostics st = returned_sqlstate; end;
  if st <> '42501' then raise exception 'Ghi events kem quan nguoi khac phai bi chan (42501), nhan %', st; end if;

  -- ========== 2) Cấp super-admin bằng tay cho A, gọi lại các RPC admin ==========
  reset session authorization;
  insert into platform_admins (user_id) values (a);
  set local session authorization authenticated;
  perform set_config('request.jwt.claim.sub', a::text, true);
  if not is_platform_admin() then raise exception 'A da duoc cap ma is_platform_admin() = false'; end if;

  -- admin_list_shops
  select * into r from admin_list_shops() s where s.id = shop_b;
  if r.id is null or r.name <> 'Quán 96 B' or r.owner_user_id <> b or r.owner_name <> 'Bình'
     or r.owner_email <> 'b96@test96.invalid' or r.member_count <> 1 then
    raise exception 'admin_list_shops: dong quan B sai: %', r; end if;

  -- admin_list_users: tìm kiếm, phân trang, total_count
  select count(*) into n from admin_list_users('@TEST96.invalid', 50, 0);
  if n <> 2 then raise exception 'admin_list_users tim theo email: mong 2, nhan %', n; end if;
  select * into r from admin_list_users('test96', 1, 0);
  if r.total_count <> 2 or r.email <> 'a96@test96.invalid' or not r.is_platform_admin
     or r.full_name <> 'An 96' or r.shop_count <> 1 or r.shop_names <> 'Quán 96 A' or r.last_login_at is null then
    raise exception 'admin_list_users trang 1: sai: %', r; end if;
  select * into r from admin_list_users('test96', 1, 1);
  if r.email <> 'b96@test96.invalid' or r.is_platform_admin then
    raise exception 'admin_list_users trang 2: sai: %', r; end if;
  select count(*) into n from admin_list_users('Bình 96', 50, 0);
  if n <> 1 then raise exception 'admin_list_users tim theo ten: mong 1, nhan %', n; end if;
  select count(*) into n from admin_list_users('khong-ai-co-chuoi-nay-96', 50, 0);
  if n <> 0 then raise exception 'admin_list_users tim khong khop: mong 0, nhan %', n; end if;

  -- admin_list_errors: thấy lỗi của mọi người, có email + tên quán; p_before lọc đúng
  select * into r from admin_list_errors(200, null) e where e.user_id = b;
  if r.message <> 'Lỗi của B' or r.stack <> 'stack B' or r.user_email <> 'b96@test96.invalid'
     or r.shop_name <> 'Quán 96 B' or r.platform <> 'ios' then
    raise exception 'admin_list_errors: dong cua B sai: %', r; end if;
  select count(*) into n from admin_list_errors(200, null) e where e.user_id in (a, b);
  if n <> 4 then raise exception 'admin_list_errors: mong 4 dong cua A+B, nhan %', n; end if;
  select count(*) into n from admin_list_errors(200, now()) e where e.user_id in (a, b);
  if n <> 0 then raise exception 'admin_list_errors p_before=now(): mong 0, nhan %', n; end if;
  select count(*) into n from admin_list_errors(1, null);
  if n <> 1 then raise exception 'admin_list_errors p_limit=1: mong 1, nhan %', n; end if;

  -- admin_event_counts: gom theo ngày + tên, đếm người dùng khác nhau
  select * into r from admin_event_counts(now() - interval '1 day', now() + interval '1 day') c
   where c.name = 'test96_shift_open';
  if r.event_count <> 2 or r.user_count <> 2 or r.day <> (now() at time zone 'Asia/Ho_Chi_Minh')::date then
    raise exception 'admin_event_counts: sai: %', r; end if;
  begin perform admin_event_counts(now(), now() - interval '1 day'); msg := 'ok';
  exception when others then get stacked diagnostics msg = message_text; end;
  if msg <> 'DATE_RANGE_INVALID' then raise exception 'admin_event_counts khoang nguoc: mong DATE_RANGE_INVALID, nhan %', msg; end if;

  -- admin_list_logins: lọc theo người dùng
  select count(*) into n from admin_list_logins(b, 10);
  if n <> 1 then raise exception 'admin_list_logins(B): mong 1, nhan %', n; end if;
  select * into r from admin_list_logins(b, 10);
  if r.ip <> '203.0.113.5' or r.user_agent <> 'FlutterTest/1.0' or r.user_email <> 'b96@test96.invalid' then
    raise exception 'admin_list_logins(B): sai: %', r; end if;

  -- admin_set_config + get_app_config (người thường đọc được cấu hình qua RPC)
  select * into r from admin_set_config('maintenance', 'true'::jsonb);
  if r.key <> 'maintenance' or r.value <> 'true'::jsonb or r.updated_by <> a then
    raise exception 'admin_set_config: sai: %', r; end if;
  perform admin_set_config('min_version', '"1.2.0"'::jsonb);
  perform admin_set_config('maintenance', 'false'::jsonb);   -- sửa khóa đã có
  begin perform admin_set_config('Khoa Sai!', '1'::jsonb); msg := 'ok';
  exception when others then get stacked diagnostics msg = message_text; end;
  if msg <> 'INPUT_INVALID' then raise exception 'admin_set_config khoa sai: mong INPUT_INVALID, nhan %', msg; end if;

  perform set_config('request.jwt.claim.sub', b::text, true);
  cfg := get_app_config();
  if cfg -> 'maintenance' <> 'false'::jsonb or cfg ->> 'min_version' <> '1.2.0' then
    raise exception 'get_app_config: sai: %', cfg; end if;

  -- RLS: super-admin đọc được dòng của người khác
  perform set_config('request.jwt.claim.sub', a::text, true);
  select count(*) into n from error_logs where user_id = b;
  if n <> 1 then raise exception 'RLS: super-admin phai doc duoc loi cua B, nhan %', n; end if;
  select count(*) into n from login_ips where user_id = b;
  if n <> 1 then raise exception 'RLS: super-admin phai doc duoc login cua B, nhan %', n; end if;

  reset session authorization;
  raise notice 'ADMIN: TAT CA DEU DUNG';
end $test$;

rollback;
