# Thiết lập đăng nhập cho nhân viên

Chủ quán và nhân viên đều đăng nhập bằng **mật khẩu**. Nhân viên đăng ký bằng số điện thoại hoặc email cùng mật khẩu, vào luôn mà không cần xác nhận OTP hay email. Không còn bước xác minh thiết bị.

## Cấu hình Supabase

1. Trong **Authentication → Sign In / Providers → Email**, bật Email và **tắt "Confirm email"** để đăng ký xong vào được ngay. Không cần cấu hình SMTP cho đăng nhập.
2. Số điện thoại không dùng nhà cung cấp SMS. App đăng ký số `0901 234 567` thành email nội bộ `p84901234567@phone.fore-staff.app`; server nhận ra dạng này để khớp lời mời theo số điện thoại. Nếu Supabase từ chối tên miền này (`email_address_invalid`), nhân viên dùng email thật.
3. Mật khẩu tối thiểu 8 ký tự (khớp `AppConfig.minPasswordLength`).
4. Triển khai tám module SQL theo [`HUONG_DAN_NHIEU_QUAN.md`](../HUONG_DAN_NHIEU_QUAN.md). Không chạy `database/dev/reset_schema.sql` trên cơ sở dữ liệu có dữ liệu cần giữ.
5. SMTP riêng chỉ cần khi gửi email khác (đặt lại mật khẩu cho chủ quán). Không đưa thông tin SMTP vào ứng dụng Flutter.

## Mời nhân viên

- Chủ mời theo số điện thoại hoặc email. Nhân viên đăng ký bằng đúng số/email đó thì lời mời hiện trong hộp thư.
- **Lưu ý bảo mật:** vì không còn xác minh OTP, lời mời khớp theo số/email do người dùng tự khai. Ai biết số/email được mời đều có thể đăng ký bằng nó và nhận lời mời. Chủ nên kiểm tra tên trong danh sách nhân viên và thu hồi nếu lạ. Muốn chặt hơn thì quay lại xác minh OTP (cần SMTP/SMS).

## Khắc phục

- Đăng ký báo "Supabase đang bật Confirm email": tắt ở bước 1.
- Báo "Số điện thoại hoặc email này không dùng được": Supabase từ chối tên miền email; dùng email thật.
- Tài khoản nhân viên cũ đăng ký bằng OTP vẫn đăng nhập được nếu đặt mật khẩu qua "Quên mật khẩu" (với email thật).
