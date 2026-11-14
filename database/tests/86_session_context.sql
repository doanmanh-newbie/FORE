-- Test hồi quy RPC phiên mới. Chạy sau stub và migration 001..018 trên DB TEST riêng.
\set ON_ERROR_STOP on
truncate shops, user_settings, shop_invites, staff cascade;
delete from auth.users;
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values ('00000000-0000-0000-0000-0000000000a1', 'owner@test.vn', now(), '{"account_kind":"owner","full_name":"Chủ A"}');
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values ('00000000-0000-0000-0000-0000000000b1', 'p84901234567@phone.fore-staff.app', now(), '{"account_kind":"staff","demo_phone":"84901234567","full_name":"Lan"}');

do $test$
declare
  v_owner text := '00000000-0000-0000-0000-0000000000a1';
  v_staff text := '00000000-0000-0000-0000-0000000000b1';
  v_context jsonb;
  v_dashboard jsonb;
  v_shop uuid;
  v_invite uuid;
  v_expired_invite uuid;
  v_status text;
  v_expired_count integer;
begin
  perform set_config('request.jwt.claim.sub', v_owner, true);
  set local session authorization authenticated;
  v_context := my_session_context();
  if v_context->>'account_kind' <> 'owner'
     or jsonb_array_length(v_context->'shops') <> 0
     or (v_context->>'pending_invite_count')::int <> 0 then
    raise exception 'owner without shop context wrong: %', v_context;
  end if;
  v_shop := create_shop('Quán phiên test', 'Chủ A');
  v_context := my_session_context(v_shop);
  if v_context->>'account_kind' <> 'owner'
     or jsonb_array_length(v_context->'shops') <> 1
     or v_context#>>'{shops,0,role}' <> 'owner'
     or v_context#>>'{shops,0,is_current}' <> 'true' then
    raise exception 'owner membership context wrong: %', v_context;
  end if;
  perform invite_staff('0901234567', 'Lan');
  reset session authorization;

  perform set_config('request.jwt.claim.sub', v_staff, true);
  set local session authorization authenticated;
  v_context := my_session_context();
  if v_context->>'account_kind' <> 'staff'
     or jsonb_array_length(v_context->'shops') <> 0
     or (v_context->>'pending_invite_count')::int <> 1 then
    raise exception 'staff invite context wrong: %', v_context;
  end if;
  select invite_id into v_invite from my_invites() limit 1;
  -- A remembered shop outside this user's active membership must not be selected.
  perform my_session_context(v_shop);
  v_context := my_session_context();
  if jsonb_array_length(v_context->'shops') <> 0 then
    raise exception 'foreign shop leaked to staff context: %', v_context;
  end if;
  perform decline_invite(v_invite);
  reset session authorization;

  perform set_config('request.jwt.claim.sub', v_owner, true);
  set local session authorization authenticated;
  v_dashboard := owner_dashboard(now() - interval '12 hours', now() + interval '12 hours');
  if not exists (
    select 1 from jsonb_array_elements(v_dashboard->'notifications') n
     where n->>'id' = 'invite:' || v_invite::text
       and n->>'title' = 'Lan đã từ chối lời mời'
  ) then
    raise exception 'owner invite response notification missing: %', v_dashboard->'notifications';
  end if;

  -- Lời mời hơn 14 ngày tự chuyển expired khi chủ/nhân viên tải lại.
  perform invite_staff('0901234567', 'Lan lần hai');
  select id into v_expired_invite from shop_invites
   where shop_id = v_shop and status = 'pending';
  reset session authorization;
  update shop_invites set created_at = now() - interval '15 days'
   where id = v_expired_invite;

  perform set_config('request.jwt.claim.sub', v_staff, true);
  set local session authorization authenticated;
  v_expired_count := expire_my_invites();
  if v_expired_count <> 1 or exists (select 1 from my_invites()) then
    raise exception 'stale invite did not expire: count=%', v_expired_count;
  end if;
  begin
    perform accept_invite(v_expired_invite);
    raise exception 'expired invite was accepted';
  exception when others then
    if sqlerrm <> 'INVITE_EXPIRED' then raise; end if;
  end;
  reset session authorization;

  perform set_config('request.jwt.claim.sub', v_owner, true);
  set local session authorization authenticated;
  select status into v_status from shop_invites where id = v_expired_invite;
  if v_status <> 'expired' then
    raise exception 'owner invite history status wrong: %', v_status;
  end if;
  reset session authorization;

  -- Tự sửa user_metadata không đổi được loại tài khoản mà máy chủ báo về.
  update auth.users set raw_user_meta_data = '{"account_kind":"staff"}'
   where id = v_owner::uuid;
  perform set_config('request.jwt.claim.sub', v_owner, true);
  set local session authorization authenticated;
  if my_session_context()->>'account_kind' <> 'owner' then
    raise exception 'account_kind must come from app_metadata, not user_metadata';
  end if;
  reset session authorization;
  raise notice 'SESSION CONTEXT + INVITE EXPIRY: PASS';
end
$test$;
