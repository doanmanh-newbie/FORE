# Kiến trúc Flutter của Fore

Fore dùng cấu trúc **feature-first** kết hợp các lớp trách nhiệm. Mỗi tính năng giữ màn hình, nghiệp vụ và truy cập dữ liệu của chính nó; `core/` chỉ chứa thành phần dùng chung.

```text
lib/
  app/                  Khởi tạo app, đăng ký dependency và định tuyến
  core/                 Thành phần dùng chung: lỗi, định dạng, giao diện, RPC
  features/
    <feature>/
      domain/           Mô hình và hợp đồng repository
      data/             Supabase/API implementation của hợp đồng
      application/      Controller điều phối nghiệp vụ và trạng thái màn hình
      presentation/     Màn hình và widget của tính năng
```

## Quy tắc phụ thuộc

- `presentation` nhận trạng thái từ controller và gọi hành động; không tự viết SQL hoặc gọi bảng Supabase.
- `application` điều phối luồng nghiệp vụ và phụ thuộc vào hợp đồng trong `domain`.
- `data` triển khai repository, chịu trách nhiệm chuyển đổi dữ liệu API và lỗi dịch vụ.
- `app/` là composition root: tạo implementation cụ thể rồi tiêm vào các màn hình/controller.
- `domain` không phụ thuộc Flutter, Supabase hay widget.
- Không đặt khóa `service_role` trong Flutter. Quyền sở hữu quán phải được xác minh ở database, không chỉ ẩn nút trên giao diện.

## Cấu trúc các tính năng chính

```text
features/owner/
  application/          OwnerDashboardController
  data/                 OwnerDashboardRepository, SupabaseOwnerMenuRepository
  domain/               Dashboard/menu models và repository contracts
  presentation/         Dashboard, thông báo, quản lý thực đơn và widget dashboard

features/shift/
  application/          Luồng vào/mở ca
  data/                 Repository của luồng mở ca
  domain/               Mô hình và hợp đồng mở ca
  presentation/         Màn hình mở ca
  operations/           Bán hàng trong ca và đóng ca, chia cùng bốn lớp
```

Các widget trình bày dashboard được tách thành `owner_dashboard_widgets.dart` và `owner_dashboard_formatters.dart`; hai file là `part` của dashboard để giữ các thành phần nội bộ không thành API công khai.

## Nguyên tắc khi thêm tính năng

1. Thêm model và interface repository vào `domain/`.
2. Viết Supabase/API implementation trong `data/`.
3. Đặt trạng thái tải, kiểm tra đầu vào và luồng hành động vào controller trong `application/`.
4. Giữ widget trong `presentation/` tập trung vào hiển thị, điều hướng và nhập liệu.
5. Đăng ký implementation tại `app/app.dart`; dùng fake repository trong test.
6. Không xóa file chỉ vì không thấy import ngay. Kiểm tra điểm vào, tài liệu, test, scripts và quy trình SQL trước.
