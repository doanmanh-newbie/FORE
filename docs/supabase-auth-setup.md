# Thiết lập đăng nhập OTP cho nhân viên

Chủ quán vẫn đăng nhập bằng email và mật khẩu. Nhân viên xác minh email hoặc số điện thoại bằng OTP; sau khi xác minh, thiết bị hiện tại được ghi nhớ tối đa 60 ngày. Thiết bị/trình duyệt mới hoặc mất dữ liệu secure storage sẽ yêu cầu OTP lại.

## Cấu hình Supabase

1. Trong **Authentication → Sign In / Providers**, bật Email OTP. Mẫu **Magic Link** phải gửi mã 6 số bằng biến `{{ .Token }}`; ứng dụng yêu cầu nhập mã nên không dùng mẫu chỉ chứa liên kết. Thử gửi và nhập mã trước khi đưa cho người dùng. [Hướng dẫn email OTP và mẫu email của Supabase](https://supabase.com/docs/guides/auth/auth-email-passwordless)
2. Để gửi OTP đến email thật ở production, cấu hình SMTP của nhà cung cấp email trong Supabase và kiểm tra giới hạn gửi. Không đưa thông tin SMTP vào ứng dụng Flutter.
3. Nếu dùng đăng nhập bằng số điện thoại, bật **Phone** và cấu hình nhà cung cấp SMS cùng thông tin xác thực trong Supabase. Kiểm tra OTP đến đúng số quốc tế, gồm mã quốc gia; không dùng test number như tài khoản production. [Hướng dẫn phone login/SMS](https://supabase.com/docs/guides/auth/phone-login)
4. Triển khai tám module SQL theo [`HUONG_DAN_NHIEU_QUAN.md`](../HUONG_DAN_NHIEU_QUAN.md). Không chạy `database/dev/reset_schema.sql` trên cơ sở dữ liệu có dữ liệu cần giữ.

Supabase cho phép `signInWithOtp` không tạo người dùng mới trong luồng đăng nhập (`shouldCreateUser: false`); đăng ký nhân viên mới mới bật tạo tài khoản. [Tham chiếu Flutter `signInWithOtp`](https://supabase.com/docs/reference/dart/auth-signinwithotp)

## Mời nhân viên

- Chủ mời theo email hoặc số điện thoại mà nhân viên có thể xác minh bằng OTP.
- Lời mời chỉ khớp với email/số điện thoại đã được Supabase Auth xác minh. Metadata hoặc số/email mẫu không được dùng làm bằng chứng.
- Tài khoản cũ dùng số điện thoại tổng hợp/không xác minh không thể nhận lời mời theo bí danh cũ. Chủ cần gửi lời mời mới đến liên hệ thật của nhân viên; không xóa tài khoản, membership hay lịch sử cũ tự động.

## Giới hạn và khắc phục

- Nếu OTP không đến: kiểm tra provider đang bật, mẫu email có `{{ .Token }}`, cấu hình SMTP/SMS, định dạng số và giới hạn gửi của Supabase/provider.
- Nếu đăng nhập OTP xong nhưng app quay lại màn đăng nhập: kiểm tra đã triển khai RPC `register_staff_device`, `validate_staff_device` và cập nhật `my_session_context` từ module `04_membership_sessions.sql`.
- Web chỉ ghi nhớ trong cùng browser profile. Xóa dữ liệu site, đổi profile/trình duyệt hoặc thiết bị sẽ yêu cầu OTP lại. Dùng HTTPS khi triển khai web công khai.
- Secret thiết bị được lưu cục bộ bằng secure storage; database chỉ lưu hash gắn với Auth session và thời hạn. Không chia sẻ/copy profile trình duyệt hoặc ghi secret vào log.
