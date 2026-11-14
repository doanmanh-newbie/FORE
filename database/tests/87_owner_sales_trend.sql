-- Regression for owner-only seven-day business-day sales chart.
\set ON_ERROR_STOP on
truncate shops, user_settings, shop_invites, staff cascade;
delete from auth.users;
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data)
values
  ('00000000-0000-0000-0000-0000000000a1', 'trend-owner@test.vn', now(), '{"account_kind":"owner"}'),
  ('00000000-0000-0000-0000-0000000000b1', 'trend-staff@test.vn', now(), '{"account_kind":"staff"}');

do $test$
declare
  v_owner constant text := '00000000-0000-0000-0000-0000000000a1';
  v_staff_user constant text := '00000000-0000-0000-0000-0000000000b1';
  v_shop uuid;
  v_staff uuid;
  v_shift uuid;
  v_start timestamptz := date_trunc('day', now());
  v_chart jsonb;
begin
  perform set_config('request.jwt.claim.sub', v_owner, true);
  set local session authorization authenticated;
  v_shop := create_shop('Quán biểu đồ test', 'Chủ QA');
  reset session authorization;

  select id into v_staff from staff where shop_id = v_shop and role = 'owner';
  insert into staff (shop_id, auth_user_id, full_name, role)
  values (v_shop, v_staff_user::uuid, 'Nhân viên QA', 'staff');
  insert into shifts (shop_id, opened_by, status, opened_at)
  values (v_shop, v_staff, 'open', v_start - interval '6 days')
  returning id into v_shift;
  insert into bills (
    shop_id, shift_id, bill_type, status, opened_by, paid_by, paid_at,
    payment_method, total_amount
  ) values
    (v_shop, v_shift, 'take_away', 'paid', v_staff, v_staff,
     v_start - interval '2 days' + interval '2 hours', 'cash', 23000),
    (v_shop, v_shift, 'take_away', 'paid', v_staff, v_staff,
     v_start - interval '1 day' + interval '3 hours', 'transfer', 17000);

  perform set_config('request.jwt.claim.sub', v_owner, true);
  set local session authorization authenticated;
  v_chart := owner_sales_trend(v_start, 7);
  if jsonb_array_length(v_chart) <> 7
     or (v_chart->4->>'sales')::bigint <> 23000
     or (v_chart->5->>'sales')::bigint <> 17000
     or (v_chart->6->>'sales')::bigint <> 0 then
    raise exception 'owner seven-day sales trend wrong: %', v_chart;
  end if;
  reset session authorization;

  perform set_config('request.jwt.claim.sub', v_staff_user, true);
  set local session authorization authenticated;
  begin
    perform owner_sales_trend(v_start, 7);
    raise exception 'staff can read owner sales trend';
  exception when others then
    if sqlerrm <> 'OWNER_ONLY' then raise; end if;
  end;
  raise notice 'OWNER SALES TREND: PASS';
end
$test$;
