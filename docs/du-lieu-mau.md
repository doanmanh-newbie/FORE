# Dữ liệu mẫu để thử giao diện

File: `database/dev/seed_full_demo.sql` (cài xong 01 → 08 rồi mới chạy).

**Chỉ chạy trên project Supabase thử.** Script chỉ *thêm* dữ liệu, không xóa/sửa quán thật, nhưng sổ kho, hóa đơn, nhật ký là chứng từ
bất biến nên dữ liệu demo không gỡ lại được từng phần (muốn sạch thì dựng lại project thử).
Chạy MỘT lần; chạy lại sẽ báo lỗi để không nhân đôi. Chưa được chạy thử trong môi trường tạo ra nó (không có PostgreSQL),
nên nếu báo lỗi hãy gửi nguyên văn lỗi để sửa.

## Cách chạy
1. Đăng ký một tài khoản trong app (đó là tài khoản **chủ**). Tùy chọn: đăng ký thêm tài khoản thứ hai để thử giao diện nhân viên.
2. Mở file, sửa `v_owner_email` (và `v_staff_email` nếu muốn) ở **cả hai khối** `do $seed$` và `do $seed2$`.
3. Dán cả file vào SQL Editor, Run. Thấy `NOTICE: Đã tạo quán [DEMO] Fore Nguyễn Du ...` là xong.
4. Đăng nhập app bằng tài khoản chủ: quán đang chọn là **[DEMO] Fore Nguyễn Du**; **[DEMO] Fore Thảo Điền** để thử đổi quán.

## Có gì trong quán chính
| Khu vực | Dữ liệu | Thử gì |
|---|---|---|
| Nhân sự | Chủ, Văn Hải (Quản lý), Ngọc Lan (Thu ngân), Bảo Trân (Nhân viên), Thu Hà (đã thu hồi) + 2 lời mời (1 còn hạn, 1 hết hạn) | Tab Nhân sự: Đang làm / Lời mời / Đã nghỉ, gửi lại, hủy, đổi vai trò, thu hồi |
| Quyền | Quản lý được bật "Xem giá vốn" và "Quản lý thành viên" | Vai trò và phân quyền |
| Hồ sơ | Tên pháp lý, MST, địa chỉ, giờ mở cửa | Hồ sơ và thông tin quán |
| Khu vực/bàn | 3 khu vực, 14 bàn đang dùng + 1 bàn tạm ẩn | Khu vực và bàn |
| Thực đơn | 10 món × 2 size có công thức, 1 món **chưa có công thức**, 2 topping, tùy chọn mức đường | Thực đơn, cảnh báo thiếu công thức |
| Kho | 19 nguyên liệu / 7 nhóm, 5 nhà cung cấp, lô hàng có hạn dùng (chanh sắp hết hạn), giá nhập có tăng (sữa +6%) | Tổng quan Kho, Nguyên liệu, Nhà cung cấp, Sổ biến động và giá |
| Phiếu nhập | Phiếu đã nhập (nhiều ngày), 1 phiếu **nhân viên nhận hàng chờ bổ sung giá**, 1 phiếu nháp từ gợi ý, 1 phiếu hủy | Phiếu nhập hàng, Bổ sung giá, Gợi ý nhập |
| Kiểm kê | 1 đã duyệt (có điều chỉnh), 1 **đã gửi chờ duyệt** (có lệch), 1 **chờ đếm lại**, (1 nháp nếu có tài khoản nhân viên thật) | Chênh lệch sau đếm, Quyết định điều chỉnh, Đếm mù |
| Hao hụt | 1–2 lần/ca, nhiều lý do; 1 yêu cầu sửa của nhân viên | Hao hụt của chủ, Yêu cầu sửa phiếu |
| Ca & đối soát | 10 ngày × 2 ca đã đóng + 1 ca **đang mở**, hóa đơn tiền mặt/chuyển khoản, thu/chi tiền mặt | Tổng quan, Đối soát (có ca xanh/vàng/đỏ cả kho lẫn tiền) |
| Nhật ký/hỗ trợ | Vài sự kiện quản trị, 2 yêu cầu hỗ trợ | Nhật ký và dữ liệu, Hỗ trợ |

## Quán thứ hai
Quán nhỏ (5 bàn, 3 nguyên liệu, 2 món, 1 ca hôm qua) để thử Đổi quán và Quản lý chi nhánh.

## Lưu ý
- Tên nhân viên demo không có tài khoản đăng nhập (không số điện thoại, chưa đặt PIN). Muốn thử giao diện nhân viên hãy điền `v_staff_email`.
- Số liệu "ngẫu nhiên nhưng cố định": cùng ngày chạy ra cùng kết quả. Mức vàng/đỏ của đối soát được dựng theo ngưỡng mặc định; nếu bạn đã đổi ngưỡng, màu có thể khác.
