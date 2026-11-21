# Fore Admin Web — Hướng dẫn chạy, kiểm thử và triển khai

Trang quản trị nền tảng (`lib/main_admin.dart`) dành riêng cho super-admin của Fore, chạy bằng Flutter Web trên cùng nền tảng Supabase và bộ giao diện `lib/core/` của ứng dụng.

## 1. Chuẩn bị môi trường & Supabase

### 1.1. Chạy SQL trên Supabase
Đảm bảo project Supabase đã chạy xong `database/09_admin.sql` (bao gồm các bảng `platform_admins`, `error_logs`, `events`, `app_config`, `login_ips` và các RPC `is_platform_admin`, `admin_list_shops`, `admin_list_users`, `admin_list_errors`, `admin_event_counts`, `admin_list_logins`, `admin_set_config`).

### 1.2. Cấp quyền super-admin
Không có màn hình tự đăng ký super-admin. Tạo tài khoản bình thường trong **Supabase Authentication**, lấy `id` (UUID) của tài khoản đó rồi chạy trong **SQL Editor**:

```sql
insert into platform_admins (user_id)
values ('<auth.users.id>')
on conflict (user_id) do nothing;
```

> Nếu một tài khoản không nằm trong `platform_admins` đăng nhập vào Admin Web, hệ thống sẽ gọi `is_platform_admin()`, phát hiện sai quyền, tự động đăng xuất và hiển thị thông báo từ chối.

### 1.3. Tạo file `env.json` cục bộ (không commit)
Tạo file `env.json` ở thư mục gốc dự án (file này nằm trong `.gitignore`, **tuyệt đối không commit** và **chỉ dùng anon/publishable key, không dùng `service_role` key**):

```json
{
  "SUPABASE_URL": "https://<project-ref>.supabase.co",
  "SUPABASE_ANON_KEY": "<supabase-anon-or-publishable-key>"
}
```

## 2. Chạy cục bộ trên Chrome

### Chạy với dữ liệu Supabase thật
```bash
flutter run -d chrome -t lib/main_admin.dart --dart-define-from-file=env.json
```

### Xem nhanh giao diện với dữ liệu giả (Fake)
Không cần cấu hình Supabase:
```bash
flutter run -d chrome -t lib/main_admin.dart --dart-define=ADMIN_USE_FAKE=true
```
Tài khoản mẫu trong chế độ fake:
- Super-admin: `admin@fore.vn` / `admin1234`
- Tài khoản thường (để kiểm tra luồng bị từ chối): `user@fore.vn` / `user1234`

## 3. Kiểm tra tĩnh & chạy test

Trước khi mở Pull Request vào `main`, chạy:

```bash
flutter analyze
flutter test test/admin
flutter test
```

## 4. Build production cho Web

Build bằng file `env.json`:
```bash
flutter build web --release -t lib/main_admin.dart --dart-define-from-file=env.json
```

Hoặc truyền trực tiếp qua `--dart-define` (phù hợp với CI/CD):
```bash
flutter build web --release -t lib/main_admin.dart \
  --dart-define=SUPABASE_URL="https://<project-ref>.supabase.co" \
  --dart-define=SUPABASE_ANON_KEY="<supabase-anon-or-publishable-key>"
```

Thư mục đầu ra nằm tại `build/web/`.

## 5. Triển khai miễn phí lên Cloudflare Pages (khuyến nghị)

### Cách A — Triển khai nhanh bằng Wrangler CLI (từ thư mục `build/web`)
1. Build web cục bộ theo mục 4.
2. Cài/chạy Wrangler và đẩy thư mục `build/web`:
   ```bash
   npx wrangler pages deploy build/web --project-name fore-admin
   ```
3. Đăng nhập tài khoản Cloudflare khi được hỏi → nhận đường dẫn `https://fore-admin.pages.dev`.

### Cách B — Kết nối Git trên Cloudflare Dashboard (tự build khi push)
1. Vào **Cloudflare Dashboard → Workers & Pages → Create → Pages → Connect to Git**, chọn repository dự án và nhánh `main` (hoặc nhánh triển khai).
2. Cấu hình **Build settings**:
   - **Framework preset**: `None`
   - **Build command**:
     ```bash
     git clone https://github.com/flutter/flutter.git --depth 1 -b stable _flutter && _flutter/bin/flutter build web --release -t lib/main_admin.dart --dart-define=SUPABASE_URL="$SUPABASE_URL" --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
     ```
   - **Build output directory**: `build/web`
3. Thêm **Environment variables** (Production & Preview):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
4. Lưu và bấm **Save and Deploy**.

## 6. Triển khai miễn phí lên Vercel (lựa chọn thay thế)

1. Build cục bộ theo mục 4 để tạo thư mục `build/web`.
2. Cài Vercel CLI (hoặc dùng `npx vercel`) và triển khai trực tiếp thư mục `build/web`:
   ```bash
   npx vercel deploy build/web --prod
   ```
3. Hoặc cấu hình trên **Vercel Dashboard** với Output Directory `build/web`, thêm hai biến môi trường `SUPABASE_URL` và `SUPABASE_ANON_KEY`, và dùng Build Command tương tự mục 5 (Cách B).

## 7. Cấu hình Authentication trên Supabase cho tên miền Web

Sau khi có URL triển khai (ví dụ `https://fore-admin.pages.dev`):
- Vào **Supabase Dashboard → Authentication → URL Configuration**, thêm URL đó vào **Additional Redirect URLs** (nếu cần).
- Kiểm tra lại CORS mặc định của Supabase PostgREST đã cho phép truy cập từ trình duyệt.

## 8. Lưu ý gói miễn phí

- **Supabase gói miễn phí** sẽ tạm dừng project sau **7 ngày không hoạt động** — hãy mở ứng dụng hoặc Admin Web trước buổi chấm/báo cáo để đánh thức database.
- Gói miễn phí không có sao lưu tự động hằng ngày; không lưu khóa `service_role` vào mã nguồn, `env.json` công khai hay biến build frontend.
