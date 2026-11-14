# Quyết định thiết kế

## 2026-10-31 — Bộ giao diện nền P1

- Đưa màu, chữ, spacing và ThemeData vào `lib/core/design/`. File `core/theme/*` giữ export tương thích để các màn cũ có thể chuyển dần mà không tạo một đợt đổi import rủi ro.
- Dùng Newsreader cho tiêu đề và Inter cho nội dung. Hai font được lấy từ kho Google Fonts chính thức, có giấy phép SIL OFL 1.1; app đăng ký bản tĩnh để hiển thị offline. Chỉ giữ các weight cần thiết: Newsreader 500/600, Inter 400/500/600/700.
- Nguồn tệp font: `google/fonts` tại `ofl/newsreader/Newsreader[opsz,wght].ttf`, `ofl/inter/Inter[opsz,wght].ttf`; giấy phép được giữ tại `assets/fonts/OFL-Newsreader.txt` và `assets/fonts/OFL-Inter.txt`. Tạo ulang bằng `py -m pip install -r tool/requirements-fonts.txt` rồi `py tool/build_static_fonts.py`.
- Giữ màu mực và teal thương hiệu hiện có. Chưa thêm màu lime cho hành động chính vì không có file Figma/MCP thiết kế kết nối để lấy mẫu; chỉ thêm màu tối cho hero và màu trạng thái ngữ nghĩa.
- `DesignGalleryScreen` chỉ mở ở debug qua `/#/__design`; production luôn quay về splash nếu gọi route này.
- `check_design_tokens.dart` là cổng để chuyển hết literal màu/font về thư mục thiết kế. Màn cũ còn vi phạm cho tới khi được migrate; không lẫn lượt chuyển nền này với tuyên bố hoàn tất P1.

## 2026-10-31 — Vai trò khởi tạo và membership phiên P2

- `account_kind` trong metadata chỉ chọn luồng khởi tạo khi chưa có membership. Tài khoản có thể mang role khác nhau ở các quán; mọi quyền đọc/ghi tiếp tục được quyết định bằng membership hoạt động và `staff.role` ở database.
- Nếu giá trị account kind thiếu hoặc không hợp lệ, server trả `unknown`; app vẫn cho hộp thư lời mời và giữ đường tạo quán cho tài khoản cũ. RPC không dùng giá trị này để cấp quyền dữ liệu.
- Mã quán gần nhất trong SharedPreferences chỉ là gợi ý UI; `my_session_context` kiểm tra membership phía server trước khi cập nhật `user_settings`.
- Khi máy có quán cũ được nhớ nhưng server trả về không có membership và không có lời mời mới, hiện trạng thái bị thu hồi quyền. Nếu đang có lời mời mới thì mở hộp thư để người dùng có thể tham gia quán khác.


## 2026-10-31 — Thời hạn lời mời

- Lời mời nhân viên ở trạng thái `pending` hết hạn sau 14 ngày. Giữ lại hàng trong `shop_invites` và chuyển status thành `expired` để chủ vẫn xem được lịch sử; người nhận không thể chấp nhận lời mời đã hết hạn và được hướng dẫn xin gửi lại.
- Khi hộp thư/session/historic team tải hoặc thao tác nhận/từ chối, app gọi RPC hết hạn riêng trước khi đọc/ghi để cập nhật được lưu kể cả khi lời mời cũ bị từ chối.
- Lý do: tránh lời mời cũ hiển thị “đang chờ” vô thời hạn và cho phép chủ gửi lời mời mới theo unique index chỉ áp dụng trạng thái pending. Đây là chính sách sản phẩm hiện tại, có thể đổi bằng migration nếu đặc tả sau này yêu cầu thời hạn khác.

## 2026-10-31 — Deep link vào vai trò

- Mở thẳng `/#/home` trên Flutter web không đi qua Splash. `RoleHomeScreen` tự phục hồi session khi còn `SessionChecking`; nếu offline cho phép thử lại, nếu signed-out chuyển về Welcome. Điều này tránh màn tải mãi khi người dùng tải lại một URL con.

## 2026-10-31 — Ưu tiên báo cáo đối soát trên Tổng quan

- Hero đối soát trên trang Tổng quan lấy ca gần nhất còn `warn`/`alert` và chưa được chủ đánh dấu đã xử lý. Nếu không có, trang hiện trạng thái “Không có ca cần xử lý”; lịch sử vẫn mở trong tab Đối soát.
- Hero thể hiện chênh lệch nguyên liệu trước vì đây là tín hiệu của báo cáo; dòng tiền mặt đứng riêng để tránh khiến “tiền mặt khớp” bị hiểu là toàn bộ ca ổn. Nút chính mở chi tiết đối soát, nút phụ mở Kho.
- Hai thao tác nhanh dùng số `active_staff_count` từ database, là số người mở bill trong ca hiện hành (distinct `opened_by`), nên nhãn không khẳng định đó là số nhân viên đang đăng nhập.

## 2026-10-31 — Chia BillScreen và giảm chuyển động

- `BillScreen` giữ điều phối trạng thái/gọi controller; các widget header/thực đơn, dòng bill và form thanh toán/giảm giá được chuyển sang Dart `part` cùng library để không đổi API công khai và giữ đóng gói lớp private.
- Component tương tác dùng `Motion.of(context, duration)` để tôn trọng `MediaQuery.disableAnimations`; khi người dùng bật giảm chuyển động, trạng thái cuối hiện ngay.
- Lựa chọn này giữ các chuyển động nhẹ ở thiết lập mặc định, nhưng không bắt người dùng xem animation nếu thiết bị đã yêu cầu tắt.
