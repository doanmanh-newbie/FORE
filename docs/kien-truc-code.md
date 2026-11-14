# Cách tổ chức code (OOP)

Mỗi tính năng chia 4 lớp. Lớp trên chỉ biết lớp dưới nó qua **interface**, không biết cài đặt.

```
presentation/   Màn hình (Widget). Chỉ vẽ và chuyển sự kiện cho controller.
application/    Controller (ChangeNotifier). Giữ trạng thái, kiểm tra ô nhập, gọi repository.
domain/         Lớp dữ liệu (AuthUser, Profile) và interface (AuthRepository).
data/           Cài đặt interface bằng Supabase. Nơi DUY NHẤT được import supabase_flutter.
```

## Bốn ý OOP dùng trong code

| Ý | Ví dụ trong code |
|---|---|
| Trừu tượng (interface) | `AuthRepository` là hợp đồng; `SupabaseAuthRepository` và `FakeAuthRepository` (test) cùng cài đặt |
| Kế thừa + đa hình | `FieldValidator` có các lớp con `RequiredValidator`, `EmailFormatValidator`, `MinLengthValidator`...; ghép bằng `CompositeValidator` |
| Đóng gói | Controller giữ trạng thái riêng, màn hình chỉ đọc getter; không ai sửa trực tiếp |
| Sealed class | `AppFailure` (các loại lỗi) và `SessionState` (các trạng thái phiên): `switch` bắt buộc xử lý đủ, thiếu là báo lỗi lúc biên dịch |

Dependency injection: `main.dart` tạo `SupabaseAuthRepository` rồi đưa vào `ForeApp`.
Test đưa `FakeAuthRepository` vào, không cần mạng.

## Thêm một tính năng mới (ví dụ Mở ca)

1. `domain/`: lớp dữ liệu và interface (`ShiftRepository`).
2. `data/`: `SupabaseShiftRepository` gọi `open_shift`, đổi lỗi database (`NO_OPEN_SHIFT`...) thành `AppFailure` mới.
3. `application/`: `OpenShiftController`.
4. `presentation/`: màn hình.
5. `test/`: dùng repository giả để test controller.

## Quy tắc

- Màn hình không import `supabase_flutter`. Controller không import `package:flutter/material.dart`.
- Công thức đối soát ở database; app chỉ gọi và hiển thị.
- Câu thông báo lỗi tiếng Việt nằm ở `core/errors/failure_messages.dart`, mã lỗi tiếng Anh viết hoa.
