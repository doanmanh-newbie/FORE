# Cập nhật Thực đơn lần 2: ảnh món, topping, tùy chọn pha chế, sao chép có đối chiếu

## 1. Database (làm trước)
Thực đơn, ảnh món, topping và tùy chọn đã nằm trong tám module schema chính. Cài theo thứ tự trong `HUONG_DAN_NHIEU_QUAN.md`; không chạy các file patch cũ.

Bucket ảnh món `menu-images` được tạo trong `database/05_menu_management.sql`.

## 2. App
`flutter pub get` (thêm gói `image_picker`), `flutter analyze`, `flutter test`.
- Android: chọn ảnh/chụp ảnh chạy được không cần sửa manifest. Khi build iOS sau này cần thêm `NSPhotoLibraryUsageDescription` và `NSCameraUsageDescription` vào Info.plist.
- Màn mới nằm ở `lib/features/owner/menu/`: `menu_image_view.dart`, `menu_image_service.dart`, `menu_extras_views.dart`, `menu_copy_views.dart` (viết lại).

## 3. Chưa làm
- Màn BÁN HÀNG của nhân viên chưa chọn topping/tùy chọn, bill chưa cộng giá topping và chưa trừ kho topping. Hiện chỉ có cấu hình + xem trước của chủ quán.
- Ảnh chưa cắt thủ công: app thu nhỏ ảnh (tối đa 1024px) và hiển thị cắt vuông ở giữa.
- Sao chép: chưa có nút "Tạo nguyên liệu ở quán nhận" ngay trong màn đối chiếu (tạo ở tab Kho của quán nhận rồi đối chiếu lại).
- Định lượng nguyên liệu vẫn chỉ nhận số nguyên.
