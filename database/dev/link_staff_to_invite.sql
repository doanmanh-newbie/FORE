-- Fore · dev/link_staff_to_invite.sql
-- CHỈ ĐỂ THỬ. Nối ngay một tài khoản nhân viên (đã tạo bằng nút "Tạo tài khoản nhân viên"
-- trong app) vào quán đã mời số điện thoại/email của họ, giống bấm "Chấp nhận" trong app.
-- Dùng khi nhân viên đã đăng nhập mà vẫn báo "chưa được thêm vào quán" và bạn chưa muốn chờ
-- bản app mới (bản mới tự nhận lời mời duy nhất khi đăng nhập).
--
-- Cách dùng: sửa hai dòng v_phone / v_email bên dưới (chỉ cần một trong hai), rồi chạy trong
-- Supabase > SQL Editor. Chạy lại nhiều lần vẫn an toàn.
do $$
declare
  v_phone text := '0978 091 478';   -- số nhân viên, để null nếu nhân viên dùng email
  v_email text := null;             -- email nhân viên, để null nếu dùng số điện thoại

  v_norm  text := normalize_phone(v_phone);
  v_login text;
  v_uid   uuid;
  v_staff uuid;
  r       shop_invites;
  v_n     int := 0;
begin
  -- Tài khoản đăng nhập: số điện thoại được đổi thành email giả p<số>@phone.fore-staff.app
  v_login := case
    when v_norm is not null then 'p' || v_norm || '@phone.fore-staff.app'
    else lower(btrim(v_email))
  end;
  if v_login is null then
    raise exception 'Hãy điền v_phone hoặc v_email.';
  end if;

  select id into v_uid from auth.users where lower(email) = v_login;
  if v_uid is null then
    raise exception 'Chưa có tài khoản đăng nhập % . Hãy bấm "Tạo tài khoản nhân viên" trong app trước.', v_login;
  end if;

  for r in
    select * from shop_invites
     where status = 'pending'
       and ((v_norm is not null and phone = v_norm)
         or (v_email is not null and email = lower(btrim(v_email))))
     order by created_at
  loop
    select id into v_staff from staff where shop_id = r.shop_id and auth_user_id = v_uid;
    if v_staff is null then
      insert into staff (shop_id, auth_user_id, full_name, role)
      values (r.shop_id, v_uid, r.full_name, 'staff');
    else
      update staff set active = true, role = 'staff', full_name = r.full_name
       where id = v_staff and not active;
    end if;

    update shop_invites
       set status = 'accepted', responded_at = now(), accepted_user_id = v_uid
     where id = r.id;

    -- Quán vừa nối là quán đang làm việc của tài khoản này.
    insert into user_settings (auth_user_id, active_shop_id)
    values (v_uid, r.shop_id)
    on conflict (auth_user_id) do update set active_shop_id = excluded.active_shop_id;

    v_n := v_n + 1;
  end loop;

  if v_n = 0 then
    raise notice 'Không có lời mời nào đang chờ cho % . Hãy nhờ chủ quán mời lại trong màn Nhân viên.', v_login;
  else
    raise notice 'Đã nối % vào % quán.', v_login, v_n;
  end if;
end $$;
