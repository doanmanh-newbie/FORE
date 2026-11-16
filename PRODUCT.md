# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

- **Chủ quán đồ uống nhỏ** (người dùng chính): thường không đứng quán cả ngày; mở app để xem ca đang chạy, đọc báo cáo đối soát sau mỗi ca, xử lý ca lệch, quản lý thực đơn, kho, nhân sự. Một số chủ có **nhiều quán** và chuyển qua lại giữa các quán.
- **Nhân viên / thu ngân / quản lý ca**: dùng trong ca tại quầy để mở ca, bán hàng theo bàn hoặc mang đi, thanh toán, ghi hao hụt, nhận hàng, đếm kho mù, đóng ca. Quyền của từng vai trò (Quản lý, Thu ngân, Nhân viên) do chủ bật/tắt.

## Product Purpose

Giúp quán đồ uống vừa bán hàng hằng ngày vừa biết mỗi ca có thất thoát nguyên liệu hay lệch tiền mặt không. Thành công là chủ quán tin được con số của từng ca mà không phải có mặt ở quán.

## Positioning

Bán hàng và đối soát là hai giá trị ngang hàng. Mỗi ca, Fore tính lượng nguyên liệu lẽ ra phải dùng (công thức × số đã bán, cộng nhập, trừ hao hụt đã ghi) rồi so với số nhân viên đếm mù, và so tiền mặt trong két với doanh thu tiền mặt, để chỉ ra ca nào xanh, vàng, đỏ.

## Operating Context

- Ca làm là đơn vị làm việc: mở ca với tiền đầu két, bán, ghi hao hụt và thu/chi, đếm kho, đóng ca, rồi chủ xem đối soát và đánh dấu đã xử lý.
- Thiết bị: điện thoại Android của chủ và nhân viên; **máy tính bảng đặt ở quầy thu ngân**. Bản web Flutter dùng để thử và demo.
- Giao diện, dữ liệu và thông báo đều bằng tiếng Việt; tiền tính bằng VND; ngày kinh doanh bắt đầu lúc 06:00.
- Dữ liệu trên Supabase; mọi quyền do server quyết định theo membership từng quán.

## Capabilities and Constraints

- Hai luồng: chủ quán đăng nhập bằng email + mật khẩu; nhân viên đăng nhập bằng OTP (số điện thoại hoặc email) và phải xác minh lại trên từng thiết bị (khóa thiết bị 60 ngày).
- Nhiều quán cho một chủ; nhân viên vào quán qua lời mời có hạn.
- Có: bàn và khu vực, bill tại bàn và mang đi, thanh toán tiền mặt/chuyển khoản, thực đơn nhiều size kèm công thức, topping và tùy chọn, kho (nguyên liệu, nhà cung cấp, phiếu nhập, lô hàng, kiểm kê, hao hụt), đối soát theo ca, vai trò và phân quyền, nhật ký.
- Sổ kho, hóa đơn và nhật ký là chứng từ không sửa/xóa; sửa bằng phiếu điều chỉnh có lý do.
- Chưa quyết định: chế độ ngoại tuyến khi mất mạng, thông báo đẩy giữa chủ và nhân viên.

## Brand Commitments

- Tên sản phẩm: **Fore**. Logo vẽ bằng code từ file thiết kế gốc (`lib/core/widgets/brand_logo.dart`).
- Ngôn ngữ giao diện: tiếng Việt, xưng hô trung tính, câu ngắn.

## Evidence on Hand

- Dữ liệu mẫu cho demo: `database/dev/seed_full_demo.sql` (quán "[DEMO]", 10 ngày lịch sử), mô tả ở `docs/du-lieu-mau.md`.
- Chưa có khách hàng thật, lời chứng thực, số liệu sử dụng hay kết quả chạy thử tại quán. Không được bịa các nội dung này.

## Product Principles

1. Con số của ca phải đáng tin: không giấu lỗi, không đoán dữ liệu thiếu, không coi "chưa biết" là "ổn".
2. Thao tác trong ca phải nhanh và khó bấm nhầm, vì nhân viên vừa phục vụ khách vừa dùng app.
3. Chủ quán hiểu được ca nào cần xử lý mà không cần đọc bảng số.
4. Quyền và dữ liệu mỗi quán tách biệt; app không tự tin hơn server.

## Accessibility & Inclusion

- Tôn trọng thiết lập "giảm chuyển động" của thiết bị (đã có trong `lib/core/motion.dart`).
- Chưa xác lập chuẩn trợ năng cụ thể (ví dụ WCAG AA); cần quyết định.
