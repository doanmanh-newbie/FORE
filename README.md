# Fore

Ứng dụng Flutter hỗ trợ quán đồ uống quản lý ca làm, bàn, hóa đơn, thực đơn, kho và đối soát.

## Chạy ứng dụng

1. Cài Flutter SDK và Android Studio hoặc Chrome.
2. Tạo `env.json` ở gốc repo với `SUPABASE_URL` và `SUPABASE_ANON_KEY`. App đọc cấu hình bằng Dart defines; file `.env` không được tự nạp. Không đưa khóa bí mật vào Git.
3. Cài dependencies và chạy ứng dụng:

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

Để chạy bản web:

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

## Kiểm tra

```bash
flutter analyze
flutter test
```

Hướng dẫn cài database Supabase nằm trong [`HUONG_DAN_NHIEU_QUAN.md`](HUONG_DAN_NHIEU_QUAN.md). Tám file SQL ở gốc `database/` là các module schema duy nhất. Chỉ chạy `database/dev/reset_schema.sql` trước khi cài lại nếu đã sao lưu hoặc chấp nhận xóa dữ liệu trong schema `public`. Các script trong `database/dev/` và `database/tests/` chỉ dành cho phát triển/kiểm tra. Lịch sử kiểm tra và phần còn thiếu nằm trong [`docs/audit.md`](docs/audit.md). Cấu hình mẫu Supabase nằm trong `.env.example`; không đưa khóa thật vào Git.

Thiết lập OTP email/SMS và thiết bị nhân viên 60 ngày: [`docs/supabase-auth-setup.md`](docs/supabase-auth-setup.md).

Kiến trúc thư mục và quy tắc phân lớp Dart được ghi trong [`docs/kien-truc-flutter.md`](docs/kien-truc-flutter.md).
