# Fore — bản nhiều quán (chủ / nhân viên)

## 1. Database (Supabase → SQL Editor)
Bản cũ chỉ có 1 quán nên **phải dựng lại** (dữ liệu nghiệp vụ sẽ mất; tài khoản Supabase Auth vẫn còn):
1. Nếu cần reset, chạy `database/dev/reset_schema.sql` chỉ sau khi đã sao lưu hoặc chấp nhận xóa dữ liệu.
2. Chạy lần lượt đúng tám module: `01_foundation.sql` → `02_operations_reconciliation.sql` → `03_read_apis.sql` → `04_membership_sessions.sql` → `05_menu_management.sql` → `06_menu_options.sql` → `07_inventory.sql` (kho: nhà cung cấp, lô hàng, phiếu nhập, kiểm kê duyệt, hao hụt) → `08_settings.sql` (vai trò và quyền, nhân sự, hồ sơ quán, khu vực và bàn, nhật ký, hỗ trợ).

Tám module trên là nguồn SQL triển khai duy nhất. Không chạy các file vá cũ. `database/dev/` và `database/tests/` chứa script phát triển/kiểm tra; `database/dev/rebuild_test_database.sql` chỉ dành cho database TEST và được tạo bởi `tool/build_install.sh`.

Sau đó **không còn** hàm `claim_first_owner` / `link_staff_account`. Chủ quán tự tạo quán trong app; nhân viên được mời bằng số điện thoại.

## 2. Đăng nhập (Supabase → Authentication)
Chủ quán đăng nhập bằng email và mật khẩu. Nhân viên xác minh email hoặc số điện thoại bằng OTP; tài khoản nhân viên không dùng mật khẩu suy ra từ số điện thoại/email.

- Email OTP: bật Email provider và sửa mẫu Magic Link để chứa mã `{{ .Token }}`. Cấu hình SMTP để gửi email production.
- Điện thoại: bật Phone provider và cấu hình SMS provider trong Supabase.
- Nhân viên chỉ nhận lời mời khi liên hệ trùng email/số điện thoại đã được Auth xác minh.
- Thiết bị được ghi nhớ tối đa 60 ngày; đổi thiết bị/profile hoặc xóa secure storage thì xác minh OTP lại.

Xem chi tiết tại [`docs/supabase-auth-setup.md`](docs/supabase-auth-setup.md).

## 3. Luồng sử dụng
- Màn đầu: **Chủ quán** hoặc **Nhân viên** (công tắc ngay trên form đăng nhập).
- Chủ: đăng ký email + mật khẩu → **Tạo quán** → Tab *Thêm* → *Nhân viên* → *Thêm nhân viên* (nhập số điện thoại hoặc email + tên).
- Nhân viên: bấm **Tạo tài khoản nhân viên**, chọn email hoặc số điện thoại thật, nhập tên và ngày sinh, sau đó nhập OTP nhận được. Khi đăng nhập lại, xác minh OTP; cùng thiết bị được nhớ tối đa 60 ngày.
  Chưa có quán thì vào không gian nhân viên có hộp thư; lời mời tự hiện (kéo xuống để làm mới). Bấm **Chấp nhận và vào quán** để tải dữ liệu quán.
- Một người thuộc nhiều quán: tab *Thêm* → bấm tên quán để đổi quán / tạo quán mới.

## 4. Bảo mật cần biết
Lời mời chỉ xác minh email/số điện thoại đã được xác nhận bởi Supabase Auth. Các tài khoản nhân viên cũ dùng liên hệ tổng hợp hoặc chưa xác minh cần được mời lại theo liên hệ thật; dữ liệu membership và lịch sử không bị xóa tự động.
Mỗi quán có dữ liệu tách riêng (`shop_id` trên mọi bảng + RLS + các hàm đều lọc theo quán).

## 5. Việc bạn cần làm sau khi giải nén
`flutter pub get` → `dart format lib test` → `flutter analyze` → `flutter test`, rồi gửi mình lỗi nếu có (mình không chạy được Flutter trong môi trường này).
Xóa file cũ không còn dùng: `lib/features/auth/login_screen.dart` và `lib/features/auth/presentation/not_linked_screen.dart`.
