-- Kiểm thử module 08_settings.sql: quyền theo vai trò, nhân sự (mời có vai trò, đổi vai trò, thu hồi), hồ sơ quán,
-- khu vực và bàn, nhật ký, hỗ trợ, tổng quan các quán.
-- Chạy sau tests/00_supabase_stub.sql và 01..08: psql -d fore_test -v ON_ERROR_STOP=1 -f tests/92_settings.sql
-- Đúng hết sẽ in "SETTINGS: TAT CA DEU DUNG". KHÔNG chạy trên Supabase thật (có xóa sạch dữ liệu).
\set ON_ERROR_STOP on

-- CHỐT CHẶN: file này xóa sạch dữ liệu (truncate + xóa auth.users). Tự dừng nếu thấy đây là Supabase.
do $guard$ begin
  if exists (select 1 from pg_roles where rolname in ('supabase_admin', 'supabase_auth_admin')) then
    raise exception 'DUNG LAI: day la Supabase. File test nay xoa sach du lieu, chi chay tren Postgres TEST rieng.';
  end if;
end $guard$;

truncate shops, user_settings, shop_invites, staff, ingredients, menu_items, menu_sizes, recipe_lines, areas, dining_tables, shifts, bills, bill_lines,
         purchases, stock_counts, waste_logs, stock_ledger, audit_log, pin_attempts, menu_categories, recipe_versions,
         price_changes, menu_events restart identity cascade;
delete from auth.users;
insert into shops (id, name) values ('00000000-0000-0000-0000-0000000000f1', 'Quán A');
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-0000000000a1', 'owner@test'),
  ('00000000-0000-0000-0000-0000000000b1', 'nv1@test'),
  ('00000000-0000-0000-0000-0000000000b2', 'nv2@test');
insert into staff (shop_id, auth_user_id, full_name, role) values
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000a1', 'Chủ', 'owner'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b1', 'NV1', 'staff'),
  ('00000000-0000-0000-0000-0000000000f1', '00000000-0000-0000-0000-0000000000b2', 'NV2', 'staff');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-0000000000a1', false);
insert into ingredients (name, group_name, unit) values ('Sữa tươi', 'Sữa', 'ml');

create or replace function pg_temp.expect_err(p_sql text, p_code text) returns void language plpgsql as $f$
declare msg text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics msg = message_text;
    if msg <> p_code then raise exception 'cho loi %, nhan duoc % (lenh: %)', p_code, msg, p_sql; end if;
    return;
  end;
  raise exception 'cho loi %, nhung lenh chay thanh cong: %', p_code, p_sql;
end $f$;

do $test$
declare
  owner_u constant text := '00000000-0000-0000-0000-0000000000a1';
  nv1     constant text := '00000000-0000-0000-0000-0000000000b1';
  nv2     constant text := '00000000-0000-0000-0000-0000000000b2';
  shop constant uuid := '00000000-0000-0000-0000-0000000000f1';
  nv1_id uuid; nv2_id uuid; owner_id uuid; j jsonb; area1 uuid; area2 uuid; t1 uuid; inv uuid; sh uuid; milk uuid;
begin
  select id into owner_id from staff where auth_user_id = owner_u::uuid;
  select id into nv1_id from staff where auth_user_id = nv1::uuid;
  select id into nv2_id from staff where auth_user_id = nv2::uuid;
  select id into milk from ingredients limit 1;

  -- ===== Mặc định quyền: giữ hành vi cũ =====
  if (select count(*) from role_permissions where shop_id = shop) <> 21 then raise exception 'phai co 3 vai tro x 7 quyen'; end if;
  if not (select allowed from role_permissions where shop_id = shop and job_role = 'staff' and permission = 'inventory.record') then
    raise exception 'nhan vien mac dinh duoc ghi nhan kho (giu hanh vi cu)'; end if;
  if (select allowed from role_permissions where shop_id = shop and job_role = 'manager' and permission = 'inventory.approve') then
    raise exception 'quan ly mac dinh khong duoc duyet dieu chinh kho'; end if;
  if (select code from shops where id = shop) !~ '^Q[0-9]{4}$' then raise exception 'quan phai co ma quan'; end if;

  -- ===== Nhân viên thường: không vào nhân sự / hồ sơ / khu vực / nhật ký =====
  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  j := my_permissions();
  if (j->>'is_owner')::boolean or (j->'permissions'->>'members.manage')::boolean then raise exception 'nv khong phai chu, khong quan ly thanh vien'; end if;
  if not (j->'permissions'->>'inventory.record')::boolean then raise exception 'nv duoc ghi nhan kho theo mac dinh'; end if;
  perform pg_temp.expect_err('select team_overview()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"X","address":"Y"}')$$, 'PERMISSION_DENIED');
  perform pg_temp.expect_err('select floor_overview()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err($$select audit_feed(current_date - 1, current_date + 1)$$, 'PERMISSION_DENIED');
  perform pg_temp.expect_err($$select roles_save('staff', '{"data.export": true}')$$, 'OWNER_ONLY');
  perform pg_temp.expect_err('select branches_overview()', 'OWNER_ONLY');
  j := shop_profile_get();
  if (j->>'can_edit')::boolean then raise exception 'nv khong duoc sua ho so quan'; end if;
  reset session authorization;

  -- ===== Chủ: hồ sơ quán + kiểm tra dữ liệu =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"","address":"x"}')$$, 'NAME_REQUIRED');
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"A"}')$$, 'ADDRESS_REQUIRED');
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"A","address":"x","tax_code":"123"}')$$, 'TAX_CODE_INVALID');
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"A","address":"x","email":"khong"}')$$, 'EMAIL_INVALID');
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"A","address":"x","phone":"12"}')$$, 'SHOP_PHONE_INVALID');
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"A","address":"x","timezone":"Mars/Base"}')$$, 'TIMEZONE_INVALID');
  perform pg_temp.expect_err($$select shop_profile_save('{"name":"A","address":"x","open_time":"06:00","close_time":"06:00"}')$$, 'TIME_INVALID');
  j := shop_profile_save('{"name":"Fore Nguyễn Du","legal_name":"Hộ kinh doanh Fore","tax_code":"0123456789","email":"Nd@Fore.Example",
                           "phone":"0901234567","address":"12 Nguyễn Du","open_time":"06:00","close_time":"22:00"}');
  if j->>'email' <> 'nd@fore.example' then raise exception 'email phai viet thuong'; end if;
  if j->>'phone' <> '84901234567' then raise exception 'sdt phai chuan hoa, nhan %', j->>'phone'; end if;
  if (j->>'missing_invoice_info')::boolean then raise exception 'du thong tin hoa don thi het canh bao'; end if;
  if (select name from shops where id = shop) <> 'Fore Nguyễn Du' then raise exception 'ten quan phai doi'; end if;

  -- ===== Quyền theo vai trò thật sự có hiệu lực =====
  j := roles_get('manager');
  if (j->'permissions'->>'inventory.approve')::boolean then raise exception 'manager mac dinh khong duyet kho'; end if;
  perform pg_temp.expect_err($$select roles_save('khong-co', '{}')$$, 'ROLE_INVALID');
  perform pg_temp.expect_err($$select roles_save('manager', '{"quyen.la": true}')$$, 'PERMISSION_UNKNOWN');
  perform pg_temp.expect_err($$select roles_save('manager', '{"data.export": "yes"}')$$, 'INPUT_INVALID');
  perform roles_save('staff', '{"inventory.record": false}');
  perform roles_save('manager', '{"members.manage": true, "shop.manage": true, "inventory.costs": true}');
  reset session authorization;

  perform set_config('request.jwt.claim.sub', nv1, true); set local session authorization authenticated;
  perform pg_temp.expect_err(format($$select inv_waste_add(%L, 100, 'spill')$$, milk), 'PERMISSION_DENIED');
  reset session authorization;

  -- nv2 thành quản lý: có quyền thành viên + hồ sơ + xem giá, vẫn không duyệt kho
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform team_set_role(nv2_id, 'manager');
  perform pg_temp.expect_err(format($$select team_set_role(%L, 'manager')$$, owner_id), 'OWNER_PROTECTED');
  perform pg_temp.expect_err(format($$select team_revoke(%L)$$, owner_id), 'OWNER_PROTECTED');
  perform pg_temp.expect_err(format($$select team_revoke(%L)$$, owner_id), 'OWNER_PROTECTED');
  reset session authorization;

  perform set_config('request.jwt.claim.sub', nv2, true); set local session authorization authenticated;
  j := team_overview();
  if jsonb_array_length(j->'members') <> 3 then raise exception 'phai thay 3 thanh vien'; end if;
  perform shop_profile_save('{"name":"Fore Nguyễn Du","address":"12 Nguyễn Du"}');
  perform inv_overview();
  perform pg_temp.expect_err('select st_list()', 'PERMISSION_DENIED');
  perform pg_temp.expect_err(format($$select team_set_role(%L, 'manager')$$, nv1_id), 'OWNER_ONLY');
  perform pg_temp.expect_err(format($$select team_set_role(%L, 'cashier')$$, owner_id), 'OWNER_PROTECTED');
  perform pg_temp.expect_err(format($$select team_revoke(%L)$$, nv2_id), 'SELF_PROTECTED');
  perform pg_temp.expect_err($$select roles_save('staff', '{"data.export": true}')$$, 'OWNER_ONLY');
  perform team_set_role(nv1_id, 'cashier');
  reset session authorization;

  -- ===== Mời có vai trò; hết hạn; nhận lời mời mang theo vai trò =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  inv := invite_staff('0911222333', 'Hà Thu', 'thu@fore.example');
  perform team_set_invite_role(inv, 'cashier');
  perform pg_temp.expect_err(format($$select team_set_invite_role(%L, 'ceo')$$, inv), 'ROLE_INVALID');
  j := team_overview();
  if (select i->>'job_role' from jsonb_array_elements(j->'invites') i where i->>'id' = inv::text) <> 'cashier' then
    raise exception 'loi moi phai mang vai tro thu ngan'; end if;
  perform team_resend_invite(inv);
  reset session authorization;
  update shop_invites set expires_at = now() - interval '1 day' where id = inv;
  perform pg_temp.expect_err(format($$update shop_invites set status = 'accepted', accepted_user_id = %L where id = %L$$, nv1, inv), 'INVITE_EXPIRED');
  update shop_invites set expires_at = now() + interval '1 day' where id = inv;
  update shop_invites set status = 'accepted', accepted_user_id = nv2::uuid where id = inv;
  if (select job_role from staff where id = nv2_id) <> 'cashier' then raise exception 'nhan loi moi phai ap vai tro cua loi moi'; end if;
  update staff set job_role = 'manager' where id = nv2_id;

  -- ===== Thu hồi: không xóa lịch sử, chặn người đang giữ ca =====
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  sh := open_shift(0);
  reset session authorization;
  perform set_config('request.jwt.claim.sub', owner_u, true); set local session authorization authenticated;
  perform team_revoke(nv1_id);
  if (select active from staff where id = nv1_id) then raise exception 'phai bi thu hoi'; end if;
  if (select deactivated_at from staff where id = nv1_id) is null then raise exception 'phai ghi ngay thu hoi'; end if;
  if not exists (select 1 from staff where id = nv1_id) then raise exception 'khong duoc xoa dong thanh vien'; end if;
  perform team_revoke(nv1_id);  -- gọi lại không lỗi
  if not exists (select 1 from audit_log where action = 'revoke_member' and entity_id = nv1_id) then raise exception 'phai ghi nhat ky thu hoi'; end if;

  -- ===== Khu vực và bàn =====
  perform pg_temp.expect_err($$select area_save(null, '')$$, 'NAME_REQUIRED');
  area1 := area_save(null, 'Tầng trệt');
  area2 := area_save(null, 'Sân vườn');
  perform pg_temp.expect_err($$select area_save(null, 'tầng trệt')$$, 'NAME_EXISTS');
  perform pg_temp.expect_err(format($$select table_save(null, %L, 'B01', 0)$$, area1), 'SEATS_INVALID');
  t1 := table_save(null, area1, 'B01', 2);
  perform table_save(null, area1, 'B02', 4);
  perform pg_temp.expect_err(format($$select table_save(null, %L, 'B01', 4)$$, area1), 'NAME_EXISTS');
  perform table_save(t1, area2, 'B01', 6);   -- chuyển sang khu vực khác (chưa có đơn)
  j := floor_overview();
  if jsonb_array_length(j->'areas') <> 2 then raise exception 'phai co 2 khu vuc'; end if;
  perform table_set_active(t1, false);
  if (select active from dining_tables where id = t1) then raise exception 'ban phai tam an'; end if;
  perform table_set_active(t1, true);

  -- ===== Nhật ký, hỗ trợ, tổng quan quán =====
  j := audit_feed(current_date - 1, current_date + 1);
  if jsonb_array_length(j->'events') < 3 then raise exception 'nhat ky phai co su kien'; end if;
  perform pg_temp.expect_err($$select audit_feed(current_date, current_date - 3)$$, 'DATE_RANGE_INVALID');
  j := support_create('printer', 'May in bep khong ket noi duoc', 'in_app', '{"app":"2.8.0"}', false);
  if (j->>'diagnostics_sent')::boolean then raise exception 'khong dong y thi khong luu chan doan'; end if;
  if (select diagnostics from support_requests where code = j->>'code') is not null then raise exception 'chan doan phai rong khi khong dong y'; end if;
  j := support_create('data', 'Can xuat du lieu thang truoc', 'callback', '{"app":"2.8.0"}', true);
  if (select diagnostics from support_requests where code = j->>'code') is null then raise exception 'dong y thi luu chan doan'; end if;
  perform pg_temp.expect_err($$select support_create('khong-co', 'noi dung dai du', 'in_app', null, false)$$, 'KIND_INVALID');
  perform pg_temp.expect_err($$select support_create('other', 'ngan', 'in_app', null, false)$$, 'NOTE_REQUIRED');
  if jsonb_array_length(support_list()) <> 2 then raise exception 'phai co 2 yeu cau ho tro'; end if;
  if jsonb_array_length(branches_overview()) <> 1 then raise exception 'chu co 1 quan'; end if;
  reset session authorization;

  raise notice 'SETTINGS: TAT CA DEU DUNG';
end $test$;
