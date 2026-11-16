# Audit hiện trạng Fore

Ngày lập: 2026-10-31

> Cập nhật topology SQL ngày 2026-11-06: sáu module `database/01_foundation.sql` đến `database/06_menu_options.sql` là nguồn schema hiện hành. Các ghi chú lịch sử bên dưới có thể nhắc tới cấu trúc cũ (`install/`, patches hoặc nhóm bốn file).
> Cập nhật 2026-11-08: thêm module `database/07_inventory.sql` (Kho v2: nhà cung cấp, lô, phiếu nhập, kiểm kê duyệt, hao hụt). Chi tiết và phần chưa kiểm chứng: [`docs/kho-v2.md`](kho-v2.md).

## Phạm vi và cách đọc

Đây là kiểm kê ban đầu trước khi thực hiện các giai đoạn P0–P5. Các điểm nêu trong yêu cầu được xem là giả thuyết cần kiểm chứng; chưa coi là lỗi đã xác nhận nếu chưa có bằng chứng từ mã, test hoặc app đang chạy.

## Trạng thái working tree

- Nhánh hiện tại: `luong-dang-chu-quan`.
- Working tree có nhiều thay đổi chưa commit từ trước, gồm cả mã Flutter, database, tài liệu, file bị xóa và file mới. Vì vậy không tạo nhánh/commit trong trạng thái này để tránh gộp thay đổi của người dùng vào commit của đợt audit.
- `docs/audit.md` được thêm bởi đợt này.
- Chưa chạy test hay thay đổi migration trong bước ghi nhận ban đầu.

## Kiểm kê ban đầu

| Khu vực | Hiện trạng nhìn thấy | Bằng chứng / việc cần kiểm chứng |
|---|---|---|
| Flutter | Có `lib/main.dart`, `lib/app/`, `lib/core/` và các feature. Một số feature có lớp `domain/data/application/presentation`; Owner và Shift vừa được di chuyển/tách lớp trong working tree. | Đếm file/dòng, kiểm tra phụ thuộc UI→Supabase, hai module navigation/card và các file được cho là chết. |
| Giao diện | Có theme trong `lib/core/theme/`; các màn vẫn có thể chứa style viết cứng. | Quét `fontSize:`, `TextStyle(`, `Color(0x` ngoài theme; xem app thực tế nếu máy chủ đang chạy. |
| Database | Có migration gốc `001`–`017`, nhóm `install/`, bản ghép `dev/rebuild_test_database.sql`, `dev/`, `sim/`, `tests/`. Có hai migration mang tiền tố `015_`. | So sánh định nghĩa hàm giữa các nguồn cài; kiểm tra thứ tự migration, stub test và các test 70/85. |
| Test database | Có bộ SQL test dùng psql; `psql` chưa được tìm thấy trong PATH lúc kiểm kê. | Kiểm tra thêm Docker/Supabase CLI và xác định có thể chạy test trên PostgreSQL tạm an toàn hay không. |
| Đăng nhập | Các màn đăng ký/chào mừng và `SessionController` đang có thay đổi chưa commit; yêu cầu mô tả cờ `ownerIntent`. | Truy vết toàn bộ nơi đọc/ghi `ownerIntent`, xác định hợp đồng server hiện có trước khi thiết kế migration mới. |
| Dữ liệu bí mật | Có `.env` và `env.json` cục bộ đã được phát hiện; không đọc/ghi giá trị trong audit. | Không in hoặc commit thông tin đăng nhập/cấu hình. |

## Điểm P0 đã xác nhận sơ bộ

1. **Hai migration `015_` tồn tại:** `database/015_simple_staff_login.sql` và `database/015_staff_demo_contacts.sql`. Cần kiểm tra khác biệt và thứ tự hiệu lực.
2. **Có hai nguồn cài bổ sung:** các file `database/install/01`–`07` và `database/dev/rebuild_test_database.sql`. Chưa xác nhận drift cho đến khi so sánh định nghĩa hàm.
3. **Test kế thừa đã dọn:** `database/tests/80_simple_staff_login.sql` đã bị xóa trước audit vì được cho là superseded bởi `85`; cần xác nhận bộ test hiện tại và hướng dẫn không còn phụ thuộc file cũ.
4. **Các file `ForeCard`, `ForeBottomNav`, file chết và số dòng nêu trong yêu cầu:** chưa kiểm chứng.

## Giới hạn môi trường hiện tại

- Chưa xác định được `psql` trong PATH. Không chạy script reset, seed hoặc test phá hủy dữ liệu trên Supabase thật.
- Các tài khoản trong yêu cầu được xem là bí mật; không đăng nhập hay ghi chúng vào log/commit trong bước audit.
- App tham chiếu `http://localhost:59897/`; cần xác nhận dịch vụ còn chạy trước khi dùng giao diện làm bằng chứng.

## Kết quả theo giai đoạn

Chưa có giai đoạn P0–P5 nào được nghiệm thu tại thời điểm tạo audit này.

## Kết quả kiểm chứng sau kiểm kê (2026-10-31)

Phần này thay thế các mục được ghi là "cần kiểm chứng" ở trên khi có kết quả cụ thể.

### P0

1. **Migration 015 có xung đột:** `015_simple_staff_login.sql` và `015_staff_demo_contacts.sql` cùng định nghĩa `_my_verified_contacts()` và `invite_staff(...)`. Thứ tự chạy có thể ghi đè hành vi.
2. **Drift helper đã xác nhận bằng tìm kiếm mã:** `_auth_email`, `_auth_phone`, `_is_phone_login`, `_phone_login_domain` có trong migration gốc nhưng không tìm thấy trong `database/install/` hoặc `database/dev/rebuild_test_database.sql`.
3. **Stub thiếu metadata:** `database/tests/00_supabase_stub.sql` khai báo `auth.users` với `id,email,phone,phone_confirmed_at,email_confirmed_at`, nhưng thiếu `raw_user_meta_data`, trong khi migration demo và 017 đọc cột này.
4. **Test 70 chưa xác minh được runtime:** test gọi `invite_staff` với số hợp lệ ở các trường hợp chính; chưa thể xác định lỗi `CONTACT_REQUIRED` chỉ từ đọc mã.
5. `database/tests/80_simple_staff_login.sql` đã bị xóa trước đợt này vì 85 là bài hồi quy mới hơn, có thêm các kịch bản của 017. Không còn chỗ nào tham chiếu `80_simple_staff_login.sql`; có một comment test nhắc tới file khác `80_app_contract_exercises.sql`.
6. **Trùng widget:** có hai `ForeBottomNav` (core và shell) cùng hai `ForeCard` (core `fore_card.dart` và `fore_button.dart`). Có import/test còn dùng bản shell và bản trong `fore_button.dart`, nên chưa xóa.
7. `MainShell` và `NotLinkedScreen` không thấy điểm sử dụng ngoài khai báo; `main_shell.dart` và các màn liên quan đang có thay đổi chưa commit, cần giữ cho tới khi đối chiếu định tuyến/test.
8. Số dòng xác nhận: `bill_screen.dart` 916; `owner_home_screen.dart` 757; `owner_menu_management_screen.dart` 657; `owner_dashboard_widgets.dart` 549; `home_tab.dart` 523; `open_shift_screen.dart` 501.
9. Quét sơ bộ ngoài `core/theme/`: 70 `fontSize:`, 64 `TextStyle(`, 15 `Color(0x`.
10. `ownerIntent` đang được đọc/ghi trong route, `SessionController`, welcome/register/splash/team/invite/empty-space. Chưa có bằng chứng `my_session_context()` hoặc `account_kind` server-side hiện hành.

### Chặn nghiệm thu P0

- `psql` và Supabase CLI không có trong PATH. Docker CLI có nhưng daemon chưa chạy (`docker info` không kết nối được Docker Engine), vì vậy chưa thể khởi tạo PostgreSQL tạm cho test database.
- `flutter analyze` và `flutter analyze --no-pub -v` đều không trả output trong tối đa 90 giây; đã dừng thủ công. Chưa có kết quả analyze, test hoặc build.
- Do thiếu cổng kiểm thử, **chưa sửa SQL/migration, chưa bắt đầu P1 và chưa nghiệm thu P0**.
- Repo đang ở nhánh `luong-dang-chu-quan` với nhiều thay đổi chưa commit. Không stage/commit/đổi nhánh để tránh gom thay đổi có sẵn vào một giai đoạn mới.
- UI tại `http://localhost:59897/` chưa được kiểm tra; không dùng tài khoản trong nội dung yêu cầu khi chưa có môi trường test xác nhận.

## Cập nhật kiểm thử (2026-10-31, lượt tiếp tục)

- `flutter analyze`: **PASS**, mã thoát 0, `No issues found!` (63,8 giây).
- `flutter test`: **PASS**, mã thoát 0, 228 test qua. Test header từng lỗi overflow 45 px đã sửa bằng cách giới hạn chữ trong `StatusChip`; test header riêng sau sửa cũng PASS.
- Dart analyzer trực tiếp (`dart.exe --suppress-analytics analyze lib`): PASS. Dùng Dart binary trực tiếp tránh lỗi quyền telemetry của tài khoản chạy công cụ.
- Đã thử khởi động Docker Desktop và đợi 30 giây; Docker Engine vẫn chưa sẵn sàng, không thể nạp PostgreSQL.
- Bộ SQL database chưa chạy. P0 vẫn chưa đạt cổng nghiệm thu; chưa tiến tới P1 và chưa chỉnh migration.

## P0 database retest after fixes (2026-10-31)

- `database/tests/00_supabase_stub.sql`: thêm `raw_user_meta_data`, role `service_role`, schema `extensions` để mô phỏng Supabase cho cả migration, install và rebuild.
- `database/017_staff_invite_contact_fallback.sql`: sửa kiểm tra số nhập sai để trả `PHONE_INVALID` thay vì rơi xuống `CONTACT_REQUIRED`/bỏ số và tiếp tục mời bằng email.
- Gộp chuỗi migration thành nguồn đánh số duy nhất: bỏ `015_staff_demo_contacts.sql` đã được logic mới trong `017` thay thế; chạy `tool/build_install.sh` để sinh `install/*` và `dev/rebuild_test_database.sql`.
- Thêm `tool/check_install_drift.sh`. Đã chạy trên PostgreSQL 16 tạm với ba database độc lập: **INSTALL DRIFT: PASS**, hash định nghĩa toàn bộ hàm public khớp giữa migrations, install và rebuild.
- Test SQL trên migration chain: `10,20,30,40,50,60,70,85` đều pass; `51_concurrency.sh` pass.
- Test SQL trên install path: `10,20,30,40,50,60,70,85` đều pass; `51_concurrency.sh` pass.
- Test SQL trên rebuild path: `10,20,30,40,50,60,70,85` đều pass; `51_concurrency.sh` pass.
- `flutter analyze`: pass, 0 issues. `flutter test`: pass, 228 tests (đã chạy ở lượt trước; sửa SQL/stub không đổi Dart).
- Các DB và container test là tài nguyên tạm, chỉ cục bộ; chưa chạy trên Supabase.

P0 database gates hiện xanh. Các mục cleanup code được nêu ở P0 và các pha P1–P5 vẫn chưa hoàn tất; không đánh dấu toàn dự án hoàn thành.

## P0 code cleanup checkpoint (2026-10-31)

- Hợp nhất hai lớp `ForeCard` về `lib/core/widgets/fore_card.dart`; bốn màn trước đây lấy `ForeCard` từ `fore_button.dart` nay import component chuẩn. `ForeButton` vẫn còn riêng trong file nút.
- Xóa `lib/features/auth/presentation/not_linked_screen.dart` sau khi xác nhận không còn reference.
- Giữ `features/shell/presentation/main_shell.dart` và `features/shell/presentation/fore_bottom_nav.dart`: `main_shell.dart` có thay đổi sẵn trong working tree và test/import vẫn liên kết tới bottom nav shell. Chưa xóa hoặc gộp module này để tránh làm mất thay đổi có sẵn.
- Sau dọn `ForeCard`: `flutter analyze` PASS, 0 issues; `flutter test` PASS, 228 tests.
- P0 còn mục gộp/xóa bottom navigation và `MainShell`; do working-tree ownership/usage hiện tại chưa thể xóa an toàn. Chưa sang P1 theo thứ tự yêu cầu.

### Cập nhật P0 cleanup tiếp theo (2026-10-31)

- Đã xác nhận `MainShell` không được dùng trong app route hay test integration; các `ComingSoonTab`, `CloseShiftTab`, `MoreTab` và `ForeBottomNav` trong module shell chỉ được `MainShell` gọi. Đây là prototype không còn nằm trên luồng app thật.
- Đã xóa module shell prototype không có caller: `main_shell.dart`, `fore_bottom_nav.dart`, `close_shift_tab.dart`, `coming_soon_tab.dart`, `more_tab.dart`. Thanh nav live ở `lib/core/widgets/fore_bottom_nav.dart` vẫn giữ nguyên.
- Chuyển `test/fore_bottom_nav_test.dart` sang test widget thanh nav live: tab hoạt động gọi đúng callback, tab bị vô hiệu không gọi callback.
- `flutter analyze`: PASS, không có vấn đề.
- `flutter test`: PASS, 228 test.
- `git diff --check`: PASS. `rg` không còn reference `MainShell`, `ShellTab` hoặc các file module shell đã xóa.
- P0 cleanup này đã xử lý prototype navigation. P1–P5 vẫn chưa được triển khai/ nghiệm thu; chưa tuyên bố toàn bộ sản phẩm hoàn tất.

### Cập nhật cổng P0/P1 (2026-10-31)

- P0 cleanup: prototype `features/shell` đã gỡ vì không được route gọi; nav thật ở `core/widgets` giữ nguyên. `features/ops/shift` đã được chuyển vào dưới `features/shift/operations`, các use case mở ca và đóng ca vẫn tách controller chuyên trách nhưng cùng một feature tree.
- P0 database evidence giữ nguyên từ lần chạy PostgreSQL tạm: drift check pass; tests 10,20,30,40,50,60,70,85 và 51 concurrency pass trên migration/install/rebuild. Không sửa SQL ở lượt P1.
- P0 Flutter evidence: `flutter analyze` pass; `flutter test` pass 228 sau cleanup nav. P1 hiện nâng tổng test lên 230.
- P1: tạo `lib/core/design/` cho color, typography, spacing, theme; thêm font tĩnh Newsreader 500/600 và Inter 400/500/600/700, giữ OFL; thêm gallery route debug `/#/__design` và nút mở gallery trên màn Welcome debug.
- Tách ActionTile thành component riêng và có file riêng cho AppHeader, PageTitleBlock, StatusPill, KpiCard, StatTile, ActionTile, HeroCard, SeverityChip, AttentionItem, ListRow, SectionHeader, EmptyState, ErrorState, SkeletonBox, Primary/Secondary/TertiaryButton, BottomNav, AppSheet và AppFormField.
- Các màn hiện có đã chuyển 78 chỗ literal màu/cỡ chữ thành token. `dart run tool/check_design_tokens.dart`: PASS.
- `flutter analyze`: PASS, không issue. `flutter test`: PASS, 230 tests. Test gallery ở 360×800 scale 1.0/1.3: PASS, không có layout exception.
- `git diff --check`: PASS (chỉ hiện cảnh báo line ending CRLF trên working tree Windows).
- Cố mở gallery trên app local thật qua MCP: cổng cũ 59897 không còn process lắng nghe; khởi chạy Flutter web local mới bị Windows từ chối bind socket (`errno 10013`). Vì vậy chưa chụp/đối chiếu gallery bằng browser thật trong lượt này; widget test là bằng chứng layout hiện có.
- P1 gate design token và gallery test xanh. Chưa nghiệm thu toàn bộ P1 về screenshot/Figma; không dùng MCP để tuyên bố đã kiểm tra hình thật. P3–P5 còn nguyên là việc cần thực hiện.

## P2 — Phiên đăng nhập và vai trò (đang thực hiện)

- Đã xóa `ownerIntent` hoàn toàn khỏi `lib/` và thay trạng thái mơ hồ `SessionNoShop` bằng `SessionNeedsShop` / `SessionAwaitingInvite` / `SessionReady`.
- Tạo migration `018_session_context.sql`: RPC `my_session_context(p_preferred_shop)` trả `account_kind`, các membership đang hoạt động, quán hiện tại và số lời mời chờ. Server chỉ áp dụng quán được nhớ nếu người dùng vẫn là thành viên hoạt động.
- Đăng ký chủ/nhân viên gửi `account_kind` vào metadata; quyền ở mỗi quán vẫn luôn dựa trên vai trò membership `staff.role`.
- Thêm lựa chọn quán gần nhất theo user ID trong SharedPreferences, sau đó xác minh qua RPC; bộ test trạng thái bao gồm chủ chưa có quán, nhân viên chưa có lời mời, vai trò khác nhau giữa các quán, khôi phục và chọn lại quán.
- Header chủ/nhân viên mở được trình chọn quán. Header chủ dùng nút thông báo chung với số chưa đọc; database đã có notification lời mời accepted/declined và SQL regression xác nhận chủ thấy sự kiện nhân viên từ chối.
- Quán mới không có ca, món, tồn kho hay bill hiện checklist đi tới thực đơn, kho và mời nhân viên.
- Khi thiết bị nhớ quán cũ nhưng server xác nhận đã mất membership và không có lời mời mới, session chuyển sang `SessionMembershipRevoked` với màn giải thích, kiểm tra lại và đăng xuất.
- SQL regression `database/tests/86_session_context.sql` và migration 018 đã chạy trên cả đường migration/install/rebuild. 9 bài SQL `10,20,30,40,50,60,70,85,86` PASS trên cả ba; so sánh hash định nghĩa hàm giữa ba đường cài PASS.
- `flutter analyze`: PASS, không issue. `flutter test`: PASS, 237 tests, gồm session state, contract RPC, checklist onboarding, route bị thu hồi và lịch sử lời mời. Contract test kiểm tra tên RPC, tên tham số và payload.
- Đã xóa toàn bộ chuỗi `ownerIntent` trong `lib/` và `test/`; `rg` không còn kết quả. Màn Welcome hiện tại đã có hai chế độ chủ/nhân viên; chưa hoàn tất polish và test thao tác end-to-end cho toàn bộ đăng ký/đăng nhập mỗi vai trò.
- P2 chưa nghiệm thu hoàn toàn: cơ sở dữ liệu hiện chưa có trạng thái hết hạn cho lời mời; chưa định nghĩa quy tắc hết hạn nên chưa tự đặt thời hạn. Kiểm thử thao tác accept/decline trên app Supabase chạy thật và kiểm thử widget màn thu hồi quyền còn thiếu. Chưa sang P3.


### P2 tiếp tục — hết hạn lời mời và cổng regression (2026-10-31)

- Chọn thời hạn lời mời chờ là **14 ngày**. `database/019_invite_expiry.sql` thêm trạng thái `expired`, cập nhật hộp thư để tự hết hạn khi tải lại, và trả lỗi `INVITE_EXPIRED` nếu người nhận thử chấp nhận lời mời đã hết hạn. App gọi RPC hết hạn trước các thao tác/đọc lịch sử của chủ và hiển thị trạng thái “Đã hết hạn”; không xóa lịch sử lời mời.
- Thêm kiểm thử widget cho màn mất membership, test thông báo lỗi hết hạn và test lịch sử lời mời có trạng thái expired.
- `database/tests/86_session_context.sql` kiểm tra lời mời cũ 15 ngày chuyển expired, biến mất khỏi hộp thư, và không thể chấp nhận.
- PostgreSQL local tạm: 9 bộ SQL (`10,20,30,40,50,60,70,85,86`) **PASS** trên cả migration, install và rebuild; hash định nghĩa hàm giữa ba đường **PASS**. Container kiểm thử đã dừng, không kết nối Supabase.
- `flutter analyze --no-pub`: **PASS**, 0 issue. `flutter test --no-pub`: **PASS**, 239 test. `git diff --check`: **PASS** (chỉ cảnh báo quy tắc LF/CRLF của Git trên Windows). `ownerIntent` và `SessionNoShop` không còn trong `lib/` hoặc `test/`.
- Đã sửa README bỏ liên kết tới `SPEC.md` đã bị xóa trước đó.
- **Còn chặn nghiệm thu tích hợp P2:** chưa chạy thao tác đăng nhập/nhận lời mời/accept/decline trên app trỏ tới Supabase thật; không dùng dữ liệu Supabase thật trong lượt này. Code và kiểm thử cô lập đã đạt, nhưng chưa xác nhận cấu hình/deployment Supabase hiện tại có migration 019. P3 chưa được đánh dấu hoàn tất hay bắt đầu trong audit này.


### P2/P3 tiếp tục — deep link trang chủ và tách màn chủ (2026-10-31)

- Kiểm tra app bằng MCP Playwright ở `http://localhost:59897/#/home`: bản đang được server phục vụ chỉ hiện vòng tải; console không có lỗi JS. Mở `/` qua Splash thì vào Welcome bình thường. Kết luận từ mã: deep link bỏ qua Splash nên `RoleHomeScreen` ở `SessionChecking` vô hạn; khi đã logout cũng không có redirect, và offline không có nút thử lại.
- Sửa `RoleHomeScreen`: tự gọi khôi phục phiên cho direct route, phiên signed-out được chuyển về Welcome, offline có câu báo và nút “Thử lại”. Thêm test cho signed-out, đăng nhập staff trực tiếp, offline và retry. `test/role_home_screen_test.dart` PASS cả 4 test.
- Không xác nhận bằng ảnh sau sửa: server cũ không nhận bản code mới; khởi động web server mới ở cổng khác bị Windows chặn bind (`errno 10013`). Ảnh chụp MCP trong bước chẩn đoán là từ server cũ, không dùng làm bằng chứng nghiệm thu sau sửa.
- P3: tách `owner_home_screen.dart` (767 → 151 dòng) thành các extension theo tổng quan, đối soát, danh mục và hành động. Tách `owner_dashboard_widgets.dart` (586 → 258 dòng) và hai nhóm widget mới. Đây là refactor giữ hành vi; test Owner dashboard vẫn chạy.
- Cổng hiện tại: `flutter analyze --no-pub` **PASS**; `flutter test --no-pub` **PASS, 241 test**; `dart run tool/check_design_tokens.dart` **PASS**; `git diff --check` **PASS**. P2/P0 SQL evidence giữ nguyên: 9 bộ SQL PASS trên migration/install/rebuild và function drift PASS.
- P2 local gates đã xanh: test trạng thái phiên, quyền theo membership, chuyển quán, hết hạn lời mời và màn bị thu hồi. Tài khoản Supabase thật chưa được dùng, không ghi dữ liệu nào lên Supabase; deployment chưa được xác nhận có áp dụng migration 019. P3 mới hoàn tất bước tách file; các yêu cầu UI, trạng thái và ảnh MCP của chủ quán còn cần kiểm tra.

### Cập nhật P2/P3/P4 tiếp theo (2026-10-31)

- Deep link được thử lại trên Flutter web server của working tree tại cổng 8690. Mở trực tiếp `/#/home` khi không có phiên đã chuyển về Welcome sau khi khôi phục session; Playwright console không có lỗi. Ảnh Welcome sau khi chuyển: `artifacts/qa/deep-link-after-fix.png`. Đây là ảnh trạng thái signed-out, không phải ảnh dashboard chủ quán. Không đăng nhập vào Supabase trong lượt này.
- Dashboard P3: hai thao tác nhanh riêng; ca đã đóng được ưu tiên vào hero chỉ khi báo cáo còn cảnh báo và chưa được chủ đánh dấu xử lý; nếu đã xử lý/không có cảnh báo, hiện trạng thái bình ổn. Hero làm nổi bật chênh lệch nguyên liệu, ghi tiền mặt ở dòng riêng; nút chi tiết mở đúng báo cáo, nút kho chuyển đúng tab kho. Cảnh báo tồn âm và dưới ngưỡng được gom theo nhóm, không lặp thẻ cho từng nguyên liệu.
- Đã thêm widget test chọn món → thêm bill → chuyển tab Bill; BillScreen đạt không tràn ở 360×800 với cỡ chữ 1.0/1.3. Tách `bill_screen.dart` 916 dòng thành screen/state và ba phần gọi món, dòng bill, form thanh toán/giảm giá (267/283/196/179 dòng); `BillController` tiếp tục nằm riêng trong application/domain.
- `Motion.of` nay được dùng ở nút chạm, thanh điều hướng, segmented, QtyStepper và chuyển tab bill; có test xác nhận thời lượng về 0 khi hệ điều hành bật giảm chuyển động.
- Kiểm thử SQL cục bộ sau migration 020: các file regression `10,20,30,40,50,60,70,85,86,87` đều PASS trên database rebuild cục bộ; migration, bundle install và rebuild được nạp vào ba database PostgreSQL tạm và hash mọi hàm public khớp. PostgreSQL container đã dừng; không ghi lên Supabase.
- Kết quả mới nhất: `flutter analyze --no-pub` PASS, 0 issue; `flutter test --no-pub` PASS, **253 test**; BillScreen riêng PASS 6 test (skeleton, lỗi/thử lại, thêm món/xem bill, viewport 360×800 ở cỡ chữ 1.0/1.3, giảm chuyển động); `test/fore_bottom_nav_test.dart` PASS 3 test; `dart run tool/check_design_tokens.dart` PASS; `tool/build_install.sh` PASS; `git diff --check` PASS (chỉ cảnh báo LF/CRLF của Git trên Windows).
- P3 chưa nghiệm thu ảnh dashboard chủ quán sau thay đổi: MCP chỉ xác minh trạng thái signed-out; chưa đăng nhập để xem dashboard thật, chưa có nguồn Figma kết nối. SQL 020 đã kiểm tra trên PostgreSQL tạm nhưng migration chưa được xác minh đã triển khai lên Supabase.
- PostgreSQL tạm: SQL suites `10,20,30,40,50,60,70,85,86,87` PASS trên rebuild; bài mới `87_owner_sales_trend.sql` PASS riêng trên cả migration/install/rebuild; hash hàm public giữa ba đường cài PASS. Container đã dừng.
- P4 đang tiếp tục: bill đã tách và có flow widget test; các màn nhân viên khác chưa được duyệt đầy đủ bằng thao tác MCP. P5 còn cần kiểm tra viewport/cỡ chữ và trạng thái cho các màn chính còn lại. App đang dùng đăng nhập nhân viên thử nghiệm không có mật khẩu/OTP; chưa được coi là cấu hình xác thực an toàn để phát hành thật.

### P3/P4 final gate tiếp theo (2026-10-31)

- Bổ sung thao tác vào widget test Owner dashboard: bấm “Kiểm tra kho & hao hụt” mở đúng thao tác kho; quay lại Tổng quan, bấm “Xem chi tiết đối soát” mở màn “Chi tiết đối soát”. Owner dashboard suite: **16 test PASS**.
- `flutter test --no-pub --reporter expanded`: **253 test PASS**, mã thoát 0.
- `flutter analyze --no-pub`: **PASS**, không issue, mã thoát 0.
- `dart --suppress-analytics run tool/check_design_tokens.dart`: **PASS**.
- `git diff --check`: **PASS**; Git chỉ phát cảnh báo chuẩn hóa LF/CRLF trên Windows.
- Flutter ban đầu không chạy trong sandbox vì SDK cần lockfile tạm tại `C:\flutter\bin\cache`; test được chạy sau khi cấp quyền đúng phạm vi chạy lệnh. Không sửa Flutter SDK, không stage/commit và không ghi lên Supabase.
- Các giới hạn nghiệm thu trước vẫn còn: chưa có ảnh dashboard từ phiên chủ đang đăng nhập/MCP, chưa xác nhận migration 020 đã triển khai trên Supabase, chưa hoàn tất MCP toàn bộ màn nhân viên và P5.

### P4 tiếp tục — hộp thư lời mời và lỗi tải danh sách (2026-10-31)

- Rà luồng nhân viên cho thấy `/empty-space` có tự dò lời mời mỗi 15 giây nhưng `/inbox` trong tab “Thêm” chỉ tải một lần khi mở. Nếu nhân viên đã ở một quán rồi được mời sang quán khác, lời mời không tự xuất hiện khi giữ màn Hộp thư mở. Bật polling 15 giây cho route `/inbox`; timer tự dừng khi route/provider bị hủy.
- Khi tải Hộp thư hoặc danh sách Nhân viên lỗi, giao diện trước đây chỉ hiện câu báo lỗi; nay có nút “Thử lại” trực tiếp.
- Thêm test controller xác nhận poll nhận lời mời mới và tăng `newArrivals`; widget test xác nhận lỗi tải có thể thử lại và hiển thị dữ liệu sau khi phục hồi.
- Mở rộng QA luồng chủ/nhân viên: test form chủ gửi lời mời thành công bằng fake auth/repository; hộp thư và danh sách thành viên không tràn ở 360×800 với cỡ chữ 1.0/1.3. `shop_flow_test.dart`: **17 test PASS**, gồm widget test qua đúng route `/inbox` và xác nhận lời mời mới hiện sau chu kỳ 15 giây. `flutter test --no-pub --reporter expanded`: **262 test PASS**, mã thoát 0. `flutter analyze --no-pub`: **PASS**, không issue. `dart --suppress-analytics run tool/check_design_tokens.dart`: **PASS**. `git diff --check`: **PASS** (cảnh báo line ending LF/CRLF như trước).
- Chưa thao tác được trên app live trong lượt này: tab MCP đang ở `http://127.0.0.1:8690/#/welcome` nhưng server đã dừng, accessibility snapshot rỗng và console báo WebSocket refused. Không đăng nhập, không gửi lời mời và không ghi Supabase. Cần bật lại app server và dùng tài khoản TEST để xác nhận end-to-end.

### P4/P5 tiếp tục (2026-11-01)

- Đổi danh sách đơn Mang đi sang `ListView.builder` và danh sách kiểm kê sang `SliverList`, tránh dựng sẵn toàn bộ dòng dữ liệu.
- Widget test ở 360×800 với cỡ chữ 1.0/1.3 đã bắt được tràn ngang ở hai hàng thông tin của thẻ Mang đi; đổi sang `Wrap` và bố trí nút hoàn tất riêng. Cả hai cỡ chữ hiện không còn lỗi layout.
- Thêm semantics cho thao tác mở bill mang đi. Test xác nhận thao tác “Xong” gọi repository và đưa đơn khỏi danh sách.
- Bản đồ bàn giữ `SliverGrid.builder`, điều chỉnh chiều cao thẻ theo scale chữ, và nút tăng/giảm số khách có tooltip rõ. Widget test 360×800 ở scale 1.3 xác nhận không tràn và thao tác mở bàn gửi đúng số khách rồi mở bill.
- Màn Đóng ca được kiểm ở 360×800, scale 1.3: số tiền kỳ vọng/doanh thu không xuất hiện; xác nhận yêu cầu duyệt lần hai, chọn “Kiểm tra lại” không ghi đóng ca.
- Tab Kho/Thêm được kiểm ở 360×800, scale 1.3: thao tác kiểm kê gửi đúng loại, nhân viên không thấy mục quản lý nhân viên, và ghi hao hụt/thu chi có trạng thái semantics disabled khi chưa mở ca. `ActionTile` nay cung cấp role, enabled, label và hint cho trình đọc màn hình.
- Thêm `design_contrast_test.dart` để kiểm tra các cặp chữ thường: chữ chính/phụ trên nền/thẻ, ba màu trạng thái trên tint tương ứng và chữ trắng trên nút tối đều đạt tương phản tối thiểu 4.5:1.
- Test kiểm kê 40 nguyên liệu xác nhận danh sách dựng lười; test lưu xác nhận số vừa nhập không còn hiện trên màn (giữ nguyên quy tắc đếm mù).
- Vì các SQL nguồn đã được gộp thành bốn nhóm, cập nhật `tool/build_install.sh` và `tool/check_install_drift.sh` để dùng `01_foundation.sql`–`04_membership_sessions.sql`. Chạy generator thành công; `database/install/` hiện có bốn bản sinh tương ứng. Cập nhật test mã lỗi và test hợp đồng để trỏ đúng các nhóm SQL hiện hành; sửa liên kết hướng dẫn database trong README.
- `flutter test --no-pub --reporter expanded`: **PASS, 273 test**. Hai test hợp đồng trước đó hỏng vì còn đọc migration 018/020 và regex migration ba chữ số sau khi repo đã gộp schema; sau cập nhật đường dẫn, toàn bộ test xanh.
- `flutter analyze --no-pub`: **PASS**, không issue. `dart run tool/check_design_tokens.dart`: **PASS**. `git diff --check`: không có lỗi nội dung; Git chỉ cảnh báo chuẩn hóa LF/CRLF.
- Chưa chạy được bộ database drift/test trên PostgreSQL: Docker daemon không hoạt động, `psql/createdb/dropdb` không có trong PATH. Không kết nối hay thay đổi Supabase.
- Không có server Flutter local đang lắng nghe ở các cổng đã dùng trước đây, nên không có screenshot MCP/live sau sửa. Kiểm chứng giao diện trong lượt này dựa trên widget tests, chưa phải test thao tác trên app đang chạy.
- P4/P5 vẫn chưa nghiệm thu toàn bộ: còn phải kiểm tra các màn chính nhân viên khác ở cỡ chữ lớn, tương phản màu và semantics tổng thể; chưa có ảnh live từng màn, chưa xác nhận deployment Supabase. Không đánh dấu dự án hoàn tất.
