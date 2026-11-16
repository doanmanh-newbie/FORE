# Kho v2: nhà cung cấp, lô hàng, phiếu nhập, kiểm kê duyệt, hao hụt

Tích hợp 20 màn Figma (`kho1.zip`, `kho2.zip`) vào app, kèm API và database.
Code Figma xuất ra chỉ dùng làm **bản thiết kế** (khung 414px cố định, thanh trạng thái giả, có chỗ sai cú pháp);
màn hình được dựng lại bằng design system của dự án (`core/design`), nên không có màu/chữ nằm ngoài token
(`tool/check_design_tokens.dart` vẫn đúng).

## Cài đặt
1. Chạy `database/07_inventory.sql` sau `06_menu_options.sql` (chạy lại nhiều lần không hỏng).
2. `bash tool/build_install.sh` để sinh lại `database/dev/rebuild_test_database.sql` (đã sinh sẵn).
3. Kiểm thử trên DB TEST: `psql -d fore_test -v ON_ERROR_STOP=1 -f database/tests/91_inventory.sql`.
4. `flutter test` (có test mới trong `test/features/inventory/`).

## 20 màn → code
| Màn Figma | File |
|---|---|
| Tổng quan chủ quán | `presentation/owner_kho_home.dart` (`OwnerKhoHome`, thay tab Kho của chủ) |
| Danh sách nguyên liệu · Hồ sơ nguyên liệu · Biến động và giá | `presentation/ingredient_screens.dart` |
| Quản lý nguyên liệu và nhóm | `IngredientFormScreen`, `GroupsScreen` (cùng file) |
| Nhà cung cấp · Chi tiết nhà cung cấp | `presentation/supplier_screens.dart` |
| Nhập hàng nhiều dòng · Xác nhận và tác động giá · Gợi ý nhập | `presentation/purchase_screens.dart` |
| Nhập hàng nhanh (nhân viên) | `PoFormScreen(isOwner: false)` |
| Kiểm kê trong ca · Kiểm kê đếm | `presentation/stocktake_screens.dart` (`CountScreen`) |
| Chênh lệch sau đếm · Quyết định điều chỉnh | `StocktakeReviewScreen`, `AdjustDecisionScreen` |
| Ghi hao hụt (nhân viên) · Hao hụt góc nhìn chủ | `presentation/waste_screens.dart` |
| Kho trong ca (nhân viên) | `presentation/staff_kho_home.dart` (thay `InventoryHubView` ở tab Kho) |
| Một tuần yên tâm | `presentation/week_review_screen.dart` |
| Đổi quán | `presentation/shop_compare_sheet.dart` (đổi quán dùng đúng luồng `chooseShop` sẵn có) |

Kiến trúc: `domain/kho_models.dart` + `kho_repository.dart` (không phụ thuộc Flutter) → `data/rpc_kho_repository.dart`
(gọi RPC) → `application/` (controller, định dạng) → `presentation/`. `Provider<KhoRepository>` khai báo ở `app/app.dart`.

## Database (07_inventory.sql)
- **Sổ kho vẫn là nguồn sự thật duy nhất**. Tồn = lần đếm ca gần nhất + sổ kho sau đó (như `v_expected_stock`), nhưng
  nguyên liệu chưa từng đếm vẫn có tồn để phiếu nhập đầu tiên hiện được.
- Bảng mới: `ingredient_groups`, `suppliers`, `purchase_orders` + `purchase_order_lines` (PN-xxxx), `stock_lots` (ST-xxxx),
  `ingredient_cost_events` (lịch sử giá), `stocktakes` + `stocktake_lines` (KK-xxxx), `inventory_requests`, `inv_code_counters`.
- Sổ kho thêm loại `adjust` (điều chỉnh sau kiểm kê, **không** tạo hao hụt) và cho phép `shift_id` rỗng (chủ chốt ngoài ca).
- **Giá bình quân gia quyền**: khi xác nhận phiếu, `unit_cost = (tồn_trước × giá_bq + lượng_nhập × giá_nhập) / (tồn_trước + lượng_nhập)`.
  Giá bán không tự đổi; màn "tác động giá" cho thấy giá vốn và biên lợi nhuận từng size nếu giữ giá bán.
- **Nhân viên không bao giờ nhận số tồn hoặc giá** (đếm mù). Phiếu của nhân viên không có giá, đánh dấu `needs_pricing`,
  chủ bổ sung bằng `po_set_prices`. Phiếu đã xác nhận gắn vào ca đang mở tại thời điểm nhận để đối soát ca vẫn đúng.
- Lô còn lại được **suy ra** (tồn xếp vào lô mới nhất trước), không sửa đường bán hàng nên không rủi ro cho `pay_bill`.
- Kiểm kê: nhân viên đếm mù → gửi (hệ thống chụp tồn + giá lúc gửi) → chủ xem chênh lệch, có thể yêu cầu đếm lại
  hoặc duyệt từng dòng "điều chỉnh / giữ nguyên" **bắt buộc có lý do**. Chênh lệch = số đếm − tồn lúc gửi.
- Gợi ý nhập: mức dùng 7 ngày gần nhất (bán + hao hụt); gợi ý khi tồn ≤ ngưỡng hoặc còn ít hơn (số ngày giao + 2) ngày dùng;
  lượng = đủ cho (số ngày giao + 4) ngày, làm tròn 500 ml/g. Chỉ tạo **phiếu nháp**, không gửi đơn đi đâu.
- Quyền: RLS bật cho mọi bảng mới (chủ đọc), không ai ghi trực tiếp; mọi thao tác qua hàm `security definer`.

## Khác với bản Figma (có chủ đích)
- **Màn "Ghi hao hụt" của nhân viên không hiện "Tồn hiện tại".** Hiện số tồn cho nhân viên làm hỏng đếm mù
  (họ đọc số hệ thống trước khi đếm). Thay bằng chọn lô (mã lô + hạn dùng, không số lượng). Nếu bạn muốn hiện, đây là quyết định của chủ quán.
- Phông/màu theo token của dự án (Newsreader + Inter), không dùng Lora/Be Vietnam Pro trong file Figma.
- Chủ quán tự đếm kho dùng chung phiếu đếm mù của nhân viên.
- "Một tuần yên tâm" lấy "ngày kho ổn" từ đối soát ca thật (`reconcile_shift`), không phải số giả.

## Chưa kiểm chứng được (môi trường tạo ra không có Flutter SDK và PostgreSQL)
Code **chưa được biên dịch hay chạy**. Đã làm: kiểm tra tên cột/hàm với schema hiện có, kiểm tra tĩnh tên hàm + tham số RPC
giữa Dart và SQL, mã lỗi đều có câu tiếng Việt. Cần chạy: `flutter analyze`, `flutter test`, `91_inventory.sql`,
`tool/check_install_drift.sh`. Khả năng cao còn vài lỗi nhỏ lúc biên dịch/chạy lần đầu; gửi log lại để sửa.

## Chưa làm
- Đơn vị nhập lô theo thùng/gói (hiện nhập theo đơn vị gốc quy ra lít/kg/cái).
- Gắn lô vào đường bán hàng (trừ lô theo HSD thật); hiện lô là suy ra.
- Thông báo đẩy khi gần hết hạn/hết hàng (hiện hiện trong "Ưu tiên hôm nay").

---

# Tab "Thêm" của chủ quán (đợt 1)

Đánh giá bản thiết kế `Untitled.pdf` (24 màn) và tích hợp **phần đã có chỗ dựa**:

- `lib/features/more/owner_more_hub.dart` (`OwnerMoreHub`, `MoreEntry`): hồ sơ, đổi quán, tìm chức năng (không dấu cũng ra),
  mục ghim (tối đa 3), các nhóm lối vào, **Chế độ gọn**, đăng xuất. `MoreView` cũ vẫn dùng cho nhân viên.
- `lib/features/more/more_prefs.dart` (`MorePrefs`): mục ghim và chế độ gọn lưu **trên thiết bị** (`shared_preferences`), không đi qua database.
- Danh sách lối vào dựng ở `owner_actions.dart::_more`. **Mục chưa có màn đích thì không đưa vào** (không có nút bấm vào chỗ trống);
  khi có màn mới chỉ cần thêm một `MoreEntry`.
- Tab Kho của chủ vẫn giữ khối "Tồn dự kiến theo lần đếm gần nhất" (cảnh báo tồn âm) và "Thao tác kho" của bản cũ,
  đặt dưới phần tổng quan mới.

## Chưa có backend (không tích hợp trong đợt này)
Vai trò & phân quyền (DB chỉ có `owner`/`staff`), hồ sơ quán (bảng `shops` chỉ có `name`), thuế/phí/hóa đơn, thanh toán/QR,
máy in, kết nối ngoài, khách hàng, tích điểm, ưu đãi, gói dùng & thanh toán, xuất dữ liệu/sao lưu, hỗ trợ, lịch ca làm.
Thứ tự đề xuất: hồ sơ quán + khu vực/bàn → **vai trò & quyền** (làm trước mọi thứ phụ thuộc) → thuế/phí/bản in, ca làm →
thanh toán, kết nối, khách hàng, tích điểm, ưu đãi, gói. Điểm tích lũy "dùng chung 2 quán" trái nguyên tắc tách dữ liệu
từng quán, cần quyết định kiến trúc trước khi làm.

## Tab "Thêm" (đợt 2): nhân sự, quyền, hồ sơ quán, khu vực và bàn, nhật ký, hỗ trợ

Cài `database/08_settings.sql` sau `07_inventory.sql` (test: `database/tests/92_settings.sql`). Code Flutter ở `lib/features/settings/`.

| Màn (bản thiết kế tab1–tab3) | Trạng thái | Ghi chú |
|---|---|---|
| Nhân sự · Mời · Hồ sơ thành viên | Đã làm | `team_screens.dart`. Mời bằng số điện thoại (hệ thống hiện tại), hết hạn 7 ngày, gửi lại/hủy, đổi vai trò, thu hồi (không xóa lịch sử, không thu hồi người đang giữ ca) |
| Vai trò và phân quyền | Đã làm | `roles_screen.dart`. Chỉ hiện quyền database ĐÃ áp dụng; áp dụng nhiều quán một lúc |
| Hồ sơ quán · Quản lý chi nhánh | Đã làm | Thêm cột vào `shops` (mã quán, tên pháp lý, MST, liên hệ, địa chỉ, giờ mở cửa) |
| Khu vực và bàn | Đã làm | Thêm `dining_tables.seats`; không ẩn/chuyển bàn đang có đơn |
| Nhật ký và dữ liệu | Đã làm | Sao chép CSV vào bộ nhớ tạm (chống CSV injection); chưa có tệp tải về |
| Hỗ trợ và cập nhật | Đã làm | Yêu cầu lưu mã SP-xxxx; chẩn đoán chỉ lưu khi bạn bật và thấy trước nội dung |
| Thuế/phí/bản in · Thanh toán/QR · Máy in · Kết nối · Khách hàng · Tích điểm · Ưu đãi · Gói dùng · Sao lưu · 2FA/đổi mật khẩu · Lịch ca làm | **Chưa làm** | Cần nhà cung cấp bên ngoài (ngân hàng, hóa đơn điện tử, thanh toán), phần cứng (máy in), hoặc đổi lõi bán hàng (thuế/phí vào hóa đơn, ưu đãi) — xem lý do bên dưới |

### Mô hình quyền (quan trọng)
- `staff.role` (`owner`/`staff`) **không đổi**: mọi hàm cũ vẫn đúng. Vai trò chi tiết là cột mới `staff.job_role` (`manager`/`cashier`/`staff`), mặc định `staff` (ít quyền nhất).
- Chủ quán luôn có mọi quyền, không bị hạ/thu hồi/đổi vai trò. `app_can(quyền)` / `_require_perm(quyền)` là cổng kiểm tra.
- Quyền đang áp dụng: `inventory.record` (mặc định BẬT cho mọi vai trò để giữ hành vi cũ), `inventory.costs`, `inventory.approve`, `data.export`, `members.manage`, `shop.manage`, `floor.manage`.
  Các hàm Kho ở 07 đã chuyển sang `_require_perm`. Các hàm owner-only ở module 02–06 (thực đơn, đối soát…) **chưa** đọc quyền theo vai trò, nên chưa có công tắc cho chúng.
- Mời người mới vẫn chỉ chủ quán (hàm `invite_staff` cũ là owner-only); `members.manage` = xem, đổi vai trò, thu hồi.
- Lời mời mang vai trò sang khi được nhận (trigger trên `shop_invites`); lời mời hết hạn thì không nhận được nữa.

### Lệch có chủ đích so với bản thiết kế
- Lời mời theo **số điện thoại** (đúng hệ thống hiện có); email là tùy chọn. Bản thiết kế dùng email.
- Điểm tích lũy "dùng chung 2 quán" chưa làm: trái nguyên tắc tách dữ liệu từng quán.
- Không có "Truy cập gần đây", "thiết bị đăng nhập": database chưa ghi dữ liệu này.

### Vì sao chưa làm các mục còn lại
Thuế/phí/làm tròn/ưu đãi phải đi vào lõi tính tiền hóa đơn (`pay_bill`): làm nửa vời sẽ có công tắc không có tác dụng. Thanh toán/QR/hóa đơn điện tử/kết nối cần nhà cung cấp và quyết định pháp lý. Máy in cần lớp in thật. Đổi mật khẩu/2FA/thoát thiết bị khác cần mở rộng `AuthRepository`.
Đề xuất làm tiếp theo thứ tự: thuế/phí/làm tròn (đi cùng sửa `pay_bill` có test) → ca làm → khách hàng/tích điểm/ưu đãi → thanh toán/in/kết nối.
