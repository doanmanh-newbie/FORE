---
name: Fore
description: Quản lý ca, bán hàng và đối soát thất thoát cho quán đồ uống nhỏ
colors:
  navy-ink: "#1E4A72"
  navy-accent: "#2F6699"
  gold-highlight: "#E4BD5A"
  cool-mist: "#F4F6F9"
  clean-white: "#FFFFFF"
  pale-tint: "#EDF1F6"
  nav-indicator: "#DCE7F3"
  background-tint: "#E3ECF6"
  hairline: "#DDE3EA"
  card-edge: "#E6EBF1"
  text-primary: "#14233A"
  text-secondary: "#566273"
  text-hint: "#66717F"
  disabled-fill: "#E6EAF0"
  status-healthy: "#18794E"
  status-healthy-tint: "#E2F4EA"
  status-attention: "#8A5A00"
  status-attention-tint: "#FFF1CC"
  status-critical: "#B42318"
  status-critical-tint: "#FBE4E2"
  warning-text: "#B54708"
typography:
  display:
    fontFamily: "Newsreader, Georgia, serif"
    fontSize: "26px"
    fontWeight: 500
    lineHeight: 1.23
  headline:
    fontFamily: "Newsreader, Georgia, serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.2
  kpi:
    fontFamily: "Newsreader, Georgia, serif"
    fontSize: "32px"
    fontWeight: 500
    lineHeight: 1.125
    fontFeature: "tnum"
  title:
    fontFamily: "Newsreader, Georgia, serif"
    fontSize: "18px"
    fontWeight: 600
    lineHeight: 1.33
  card-title:
    fontFamily: "Inter, Roboto, sans-serif"
    fontSize: "15px"
    fontWeight: 600
    lineHeight: 1.33
  body:
    fontFamily: "Inter, Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.43
  body-strong:
    fontFamily: "Inter, Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 600
    lineHeight: 1.43
  label:
    fontFamily: "Inter, Roboto, sans-serif"
    fontSize: "13px"
    fontWeight: 600
  caption:
    fontFamily: "Inter, Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.33
rounded:
  checkbox: "5px"
  field: "12px"
  role-card: "16px"
  panel: "28px"
  control: "12px"
  tile: "14px"
  segmented: "16px"
  card: "20px"
  pill: "999px"
spacing:
  unit: "4px"
  gap-tight: "8px"
  card-gap: "12px"
  page: "16px"
  card-padding: "16px"
  section-gap: "24px"
  page-bottom: "32px"
components:
  button-primary:
    backgroundColor: "{colors.navy-ink}"
    textColor: "{colors.clean-white}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.pill}"
    height: "48px (54px on auth screens)"
  button-secondary:
    backgroundColor: "{colors.clean-white}"
    textColor: "{colors.navy-ink}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.control}"
    height: "48px"
  button-hero-action:
    backgroundColor: "{colors.clean-white}"
    textColor: "{colors.navy-ink}"
    typography: "{typography.body-strong}"
    rounded: "{rounded.control}"
    height: "48px"
  card:
    backgroundColor: "{colors.clean-white}"
    rounded: "{rounded.card}"
    padding: "16px"
  hero-card:
    backgroundColor: "{colors.navy-ink}"
    textColor: "{colors.clean-white}"
    rounded: "{rounded.card}"
    padding: "16px"
  input:
    backgroundColor: "{colors.clean-white}"
    textColor: "{colors.text-primary}"
    rounded: "{rounded.field}"
    padding: "16px"
    height: "52px"
  chip-status-healthy:
    backgroundColor: "{colors.status-healthy-tint}"
    textColor: "{colors.status-healthy}"
    rounded: "{rounded.pill}"
  chip-status-attention:
    backgroundColor: "{colors.status-attention-tint}"
    textColor: "{colors.status-attention}"
    rounded: "{rounded.pill}"
  chip-status-critical:
    backgroundColor: "{colors.status-critical-tint}"
    textColor: "{colors.status-critical}"
    rounded: "{rounded.pill}"
  nav-bar:
    backgroundColor: "{colors.clean-white}"
    textColor: "{colors.navy-ink}"
    height: "68px"
  segmented-selected:
    backgroundColor: "{colors.navy-ink}"
    textColor: "{colors.clean-white}"
    rounded: "{rounded.control}"
    height: "44px"
---

# Design System: Fore

## Bộ "Navy" (big update 11/2026), đang dùng

Thay bộ "Rêu & Mù tạt" bên dưới, theo bố cục tham chiếu "Real Estate Home Screen Redesign"
(chỉ học bố cục và phân cấp, không chép nội dung). Token vẫn ở `lib/core/design/`; tên cũ
`moss`, `leafFixed`, `cream`, `actionLime` giữ để khỏi sửa nơi gọi nhưng giá trị đã là navy.

- **Màu:** mực navy `#1E4A72` (8,6:1 trên nền), xanh phụ `#2F6699`, nền xám lạnh `#F4F6F9`,
  thẻ trắng, chữ chính `#14233A`, chữ phụ `#566273` (5,7:1), gợi ý `#66717F` (4,9:1 trên trắng).
  Nút chính và chip đang chọn: navy chữ trắng (9,4:1). Mù tạt `#E4BD5A` chỉ còn là điểm nhấn
  vàng **trên nền navy** (≈5:1), không bao giờ làm chữ trên nền sáng.
- **Chế độ mặc định: nền sáng.** Không theo hệ thống; người dùng tự bật nền tối bằng nút mặt trăng
  (`lib/core/theme/theme_mode_toggle.dart`). Bộ tối: nền `#0B1220`, thẻ `#131C2B`, mực `#CFE0F5`.
- **Đầu trang tab chính (`ForeAppBar`):** hàng sáng gồm avatar chữ cái đầu, "Xin chào, {tên}" +
  tên quán (bấm đổi quán), nút tròn trắng (sáng/tối, chuông có số đỏ). Tiêu đề trang, dòng phụ,
  ô tìm kiếm/thống kê nằm trong **banner navy chuyển sắc** bo 24. Màn vận hành không có banner:
  trạng thái ca là một dòng `status` dưới tên quán để bản đồ bàn lên cao.
- **Màn con (`ScreenHeader`, header bill, `MenuTopBar`, `AppBar`):** nền sáng liền thân trang,
  nút quay lại tròn trắng, tiêu đề 20–22/700 mực.
- **Thẻ:** trắng, bo 20, viền `#E6EBF1`, bóng mềm (blur 22, lệch 6). Thẻ nổi bật (`HeroCard`)
  navy chuyển sắc, nút chính trắng chữ navy.
- **Tiêu đề phần:** một kiểu duy nhất `AppTextStyles.sectionHeading` = Newsreader 20/600 mực,
  kèm "Xem tất cả" bên phải khi có trang danh sách. `sectionTitle` là bí danh của nó.
- **Thanh điều hướng:** nền trắng có bóng, tab chọn icon navy trên viên `#DCE7F3` + nhãn navy
  đậm; tab khác icon và nhãn chữ phụ, luôn có nhãn.
- **Phân cấp:** tên (món, bàn, ca) luôn là chữ nổi nhất của thẻ; giá, chip, mô tả nhỏ hơn và
  không tô màu nhấn. Mọi `TextStyle` trong `AppTextStyles` khai báo `fontFamily`, để thẻ đặt
  lại `DefaultTextStyle` không rơi về font mặc định.
- **Lựa chọn:** thẻ/chip đang chọn luôn nổi nhất (navy đặc); chưa chọn là trắng viền mảnh.

- **Không có widget Material thô:** SnackBar, Dialog, ProgressIndicator, Divider, PopupMenu,
  DropdownMenu, DatePicker/TimePicker, Tooltip, Badge, ListTile đều định kiểu trong
  `app_theme.dart` (gọn hơn mặc định: ListTile ~52, TextButton 44, nút phụ trong thẻ 38).
  Thông báo nổi qua `showNotice(context, msg, kind: NoticeKind.success|error|info)`; trạng thái
  kéo dài (mất mạng, thiếu dữ liệu) dùng `InlineNotice` ở đáy màn, không dùng `MaterialBanner`.
- **Xin quyền (`lib/core/permissions/`):** luôn qua màn giải thích `askPermission` (thẻ trắng bo 28,
  đốm minh họa + icon navy, "Cho phép" / "Để sau"; quyền bị chặn thì "Mở cài đặt"). Xin tại chỗ
  (camera/thư viện trước khi chọn ảnh món, vị trí ở Hồ sơ quán) và một chuỗi lần đầu cho chủ
  quán (thông báo → camera → vị trí, mỗi quyền bỏ qua được, chỉ một lần mỗi máy). Không app nào
  tự bật hộp thoại hệ thống khi chưa giải thích. Xem/bật lại ở Thêm > Quyền truy cập.
- **Firebase:** Thêm > Kết nối Firebase hiển thị Core, Cloud Messaging, Analytics, Crashlytics
  (bật/tắt, gửi thử). Dữ liệu nghiệp vụ vẫn ở Supabase.

Các phần "Rêu & Mù tạt", Overview, Colors… bên dưới là lịch sử; khi mâu thuẫn, mục này thắng.

## Bộ "Rêu & Mù tạt" (11/2026), đã thay bằng Navy

Thiết kế lại bắt đầu từ ba màn Chào mừng, Đăng nhập, Đăng ký (Figma). Token sống trong
`lib/core/design/` (`colors.dart`, `typography.dart`, `spacing.dart`, `app_theme.dart`);
`lib/core/theme/` chỉ re-export.

- **Màu:** mực rêu đậm `#0D3B2E`, xanh lá `#2D7A5E`, vàng mù tạt `#E4BD5A` cho hành động chính,
  nền kem `#F8F7F2`, viền `#E2E5E1`. Chữ phụ `#5E6A63` (đậm hơn `#69756E` của Figma để đạt
  5,3:1 trên nền kem); `#69756E` chỉ dùng cho gợi ý và icon trong ô trắng (4,8:1).
- **Mù tạt làm chữ** (tiêu đề "Đăng nhập", "Tạo tài khoản mới") chỉ đạt 1,7:1 trên nền kem.
  Giữ theo thiết kế cho chữ rất lớn; không dùng mù tạt cho chữ thân hay nhãn.
- **Chữ:** Inter toàn bộ. `brandName` 32/700, `heroTitle` 34/700 (-1), `appBarTitle` 18/700,
  `fieldLabel` 13/600, `input` 15/500, `inputHint` 15/400, `pillButton` 16/600, `link` 13/700
  gạch chân, `stepLabel` 12/600. Tiêu đề Newsreader cũ chuyển dần theo từng màn.
- **Bo góc (`AppRadius`):** checkbox 5, ô nhập 12, thẻ vai trò 16, panel 28, viên thuốc 999.
- **Kích thước (`AppSizes`):** lề màn 20, ô nhập 52, nút viên thuốc 54, công tắc 52, vòng bước 44,
  thẻ vai trò 169. **Khoảng (`AppGaps`):** 4 / 8 / 12 / 16 / 22 / 28.
- **Thành phần:** `BrandTextField`, `PillSegmented`, `LoadingButton` (viên thuốc theo theme),
  `RoleCard`, `AuthStepHeader`, `AuthPromptLink`.
- Màu cố định không đảo theo chế độ tối (`AppColors.moss`, `leafFixed`, `mustard`, `cream`) chỉ
  dùng cho mảng đồ họa luôn tối: thẻ vai trò, panel chào mừng, vòng bước.

## Overview

**Creative North Star: "The Clean Bar"**

Fore trông như mặt quầy pha chế vừa lau xong: bề mặt sáng, mọi dụng cụ đặt đúng chỗ, không có thứ gì thừa trên quầy. Người dùng mở app giữa lúc phục vụ khách hoặc khi đang ở xa quán, nên giao diện phải đọc được trong một cái liếc và bấm được bằng một tay. Biểu cảm thương hiệu nằm ở chi tiết chính xác (chữ có chân cho tiêu đề và con số, màu mực xanh đậm), không nằm ở trang trí.

Hệ thống tinh gọn và tiết chế. Bề mặt phẳng, phân lớp bằng sắc độ nền và viền mảnh thay vì bóng đổ. Màu trạng thái (xanh, vàng, đỏ) chỉ xuất hiện khi có điều cần chú ý, để một ca lệch nổi lên rõ ràng trên nền yên tĩnh. Mật độ vừa phải: thẻ có khoảng thở 16 px, nhưng danh sách thao tác trong ca được xếp chặt để nhân viên thấy nhiều hơn mà không cuộn.

Cả bộ `core/design/` lẫn bộ `Fore*` trong `core/widgets/` đều phẳng: không thành phần nào còn bóng đổ.

**Key Characteristics:**
- Nền xanh xám rất nhạt, thẻ trắng viền mảnh, không bóng.
- Tiêu đề, số KPI bằng chữ có chân Newsreader; nội dung, nhãn, nút bằng Inter.
- Một màu hành động chính (mực xanh đậm), màu lime chỉ dành cho thẻ nổi bật nền tối.
- Màu trạng thái là tín hiệu, không phải trang trí.
- Vùng chạm tối thiểu 48 dp; chuyển động tôn trọng "giảm chuyển động" của thiết bị.

## Colors

Bảng màu hẹp, lạnh và trầm, xoay quanh một màu mực xanh đậm, để dành độ sáng và độ bão hòa cho tín hiệu trạng thái.

### Primary
- **Mực Xanh Quầy / Ink Teal** (#0C2D32): nút chính, tiêu đề, số KPI, đoạn chọn trong thanh phân đoạn, chữ trên nền sáng. Đây là "giọng" của Fore.

### Secondary
- **Teal Quầy / Counter Teal** (#51A19B): điểm nhấn thương hiệu (logo, đường nét minh họa, biểu tượng trang trí). Chỉ đạt 3,03:1 trên trắng, nên không dùng làm chữ.

### Tertiary
- **Lime Rót / Lime Pour** (#D8F27A): duy nhất cho nút hành động trên thẻ nổi bật nền tối (`HeroCard`). Không dùng trên nền sáng.
- **Ca Đêm / Night Shift** (#123C3A): nền của thẻ nổi bật (hero) trên Tổng quan.

### Neutral
- **Sương Bạc Hà / Mint Mist** (#F3F7F5): nền màn hình (scaffold).
- **Trắng Sạch / Clean White** (#FFFFFF): bề mặt thẻ, ô nhập, thanh điều hướng.
- **Sắc Nhạt / Pale Tint** (#EAF0EE): nền thanh phân đoạn, chip trung tính, khối phụ.
- **Chỉ Báo Điều Hướng / Nav Indicator** (#DDF1EF): viên chỉ báo tab đang chọn trong `NavigationBar`.
- **Đường Kẻ / Hairline** (#CBD8D4): viền ô nhập, đường chia.
- **Mép Thẻ / Card Edge** (#E7EFEC): viền 1 px của thẻ.
- **Chữ Chính / Text Primary** (#14292A): chữ nội dung quan trọng, tiêu đề thẻ.
- **Chữ Phụ / Text Secondary** (#4F6663): chữ mô tả, chú thích (5,69:1 trên nền).
- **Nền Vô Hiệu / Disabled Fill** (#E3EAE7): nền nút và điều khiển bị vô hiệu.

### Status
- **Ổn** (#18794E trên #E2F4EA), **Cần xem** (#8A5A00 trên #FFF1CC), **Nghiêm trọng** (#B42318 trên #FBE4E2): chip trạng thái và mức đối soát của ca. Mỗi cặp chữ/nền đều đạt từ 5:1 trở lên.
- **Chữ cảnh báo / Warning Text** (#B54708): chữ cảnh báo trên nền sáng. Màu `warning` (#ED6C02) chỉ cho icon hoặc dải màu, không cho chữ.

### Dark Theme
Chế độ tối theo cài đặt hệ thống (`ThemeMode.system`), dựng cho ca đêm ở quầy thiếu sáng. Nguồn giá trị là `AppPalette.dark` trong `lib/core/design/colors.dart`; frontmatter ở trên là bộ sáng.
- **Mực đảo chiều:** `brand` thành bạc hà sáng (#CFE9E4) cho cả chữ và nền nút chính; chữ trên nền mực dùng `onInk` (#0C2D32).
- **Không dùng Dynamic Color (Android 12+):** bảng màu cố định theo thương hiệu, vì màu trạng thái Ổn/Cần xem/Nghiêm trọng phải giữ nguyên nghĩa và độ tương phản trên mọi máy.
- **Nền tối cố định** (`surfaceDark`, thẻ hero): chữ dùng `AppColors.white` và `onDarkMuted`, không dùng `Colors.white` thô.
- **Bề mặt:** nền #0C1617, thẻ #142224, khối phụ #1C2C2E, viền thẻ #22383A.
- **Chữ:** chính #E4EFEC, phụ #A7BCB8 (8,2:1 trên thẻ).
- **Trạng thái:** Ổn #5DD39B trên #12301F, Cần xem #F2BE55 trên #33280C, Nghiêm trọng #FF8E82 trên #3B1915.
- **Không đổi theo chế độ:** Night Shift, Lime Pour và chữ trên thẻ nổi bật (`onDarkMuted`, `onDarkBorder`, `onDarkWarning` #FFD28A cho cảnh báo) và chữ trên nền lime (`onLime` #0C2D32).

### Named Rules
**The On-Ink Rule.** Chữ hoặc icon đặt trên nền mực luôn dùng `AppColors.onInk`, không dùng `Colors.white`; trắng cố định chỉ dành cho thẻ nền Night Shift.

**The Signal-Only Rule.** Xanh, vàng, đỏ trạng thái chỉ xuất hiện khi dữ liệu thật sự ở trạng thái đó. Không dùng chúng để trang trí, phân nhóm hay làm màu thương hiệu.

**The One Ink Rule.** Mỗi màn chỉ có một hành động chính tô màu mực xanh đậm; các hành động khác dùng viền hoặc chữ.

## Typography

**Display Font:** Newsreader (với Georgia, serif)
**Body Font:** Inter (với Roboto, sans-serif)

**Character:** Chữ có chân trầm tĩnh cho tiêu đề và con số tạo cảm giác "sổ sách đáng tin"; Inter rõ ràng, trung tính cho mọi thứ người dùng thao tác.

### Hierarchy
- **Display** (500, 26px, 1.23): tiêu đề trang (`pageTitle`, `display`).
- **Headline** (600, 22px, 1.2): tiêu đề màn phụ, tiêu đề sheet.
- **KPI** (500, 32px, 1.125, số đều độ rộng): con số chính trên thẻ Tổng quan và đối soát.
- **Title** (600, 18px, 1.33): tiêu đề phần (`sectionTitle`).
- **Card title** (Inter 600, 15px, 1.33): tiêu đề thẻ và dòng danh sách.
- **Body** (400, 14px, 1.43): mô tả, nội dung; `body-strong` (600) cho giá trị cần nhấn.
- **Label** (600, 13px): nhãn ô nhập, nhãn nút phụ, chip.
- **Caption** (400, 12px, 1.33): chú thích, thời gian, đơn vị. `micro` (600, 12px) cho nhãn nhỏ. Không chữ nào nhỏ hơn 12 px.

### Named Rules
**The Serif-for-Numbers Rule.** Con số quyết định (tiền ca, chênh lệch, KPI) dùng Newsreader với số đều độ rộng; con số trong danh sách và bảng dùng Inter số đều độ rộng.

**The Role-not-Size Rule.** Màn hình dùng vai trò trong `AppTextStyles`, không tự đặt `fontSize`. Thang `AppFontSizes` chỉ dành cho thành phần nền.

## Layout

Bố cục một cột cho điện thoại, lề trang 16 px, khoảng cách giữa thẻ 12 px, giữa các phần 24 px, đáy trang 32 px; mọi khoảng cách là bội số của 4 px. Màn danh sách dùng dòng xếp chặt; màn tổng quan dùng thẻ có khoảng thở. Thanh điều hướng dưới cùng cho điện thoại.

Máy tính bảng ở quầy: từ 600 dp trở lên, `AdaptiveNavScaffold` (`lib/core/widgets/adaptive_nav.dart`) đổi thanh dưới thành `NavigationRail` bên trái và giới hạn nội dung ở 960 px. Các màn con (`KhoPage`, `MenuPage`) bọc nội dung trong `ContentWidth` (720 px). Màn đăng nhập, đăng ký và tạo quán giới hạn form ở 480 px, căn giữa. Ở khung từ 720 px, nhóm thẻ số trên Tổng quan xếp bốn thẻ một hàng thay vì 2 × 2. Danh sách theo dữ liệu dùng `LazyListView` hoặc `ListView.builder` để chỉ dựng dòng đang hiện.

## Elevation & Depth

Hệ thống phẳng. Chiều sâu đến từ sắc độ: nền Mint Mist, thẻ trắng nằm trên với viền Card Edge 1 px, khối phụ dùng Pale Tint. Thẻ nổi bật dùng nền tối Night Shift thay vì bóng để tách khỏi trang. `CardTheme` đặt `elevation: 0`.

### Named Rules
**The Wiped-Counter Rule.** Bề mặt phẳng khi đứng yên. Không thêm bóng đổ cho thẻ, nút hay thanh điều hướng mới; dùng viền mảnh hoặc đổi sắc độ nền.

## Shapes

Góc bo mềm theo kích thước: điều khiển và ô nhập 12 px, ô tile 14 px, khung thanh phân đoạn 16 px, thẻ 20 px, chip và viên trạng thái bo tròn hẳn. Viền 1 px là đường nét chính; không dùng viền dày hay viền nét đứt. Logo Fore vẽ bằng code, giữ nguyên tỉ lệ gốc.

## Components

### Buttons
Chắc chắn nhưng kín đáo, không có bóng.
- **Shape:** bo vừa (12px), cao tối thiểu 48 dp, rộng hết dòng ở form và sheet.
- **Primary:** nền Ink Teal, chữ trắng Inter 600 14px (`PrimaryButton`, `FilledButton`).
- **Secondary:** viền 1 px Ink Teal, nền trắng, chữ Ink Teal (`SecondaryButton`, `OutlinedButton`).
- **Tertiary:** chữ Ink Teal không nền, vùng chạm 48×48 (`TertiaryButton`, `TextButton`).
- **Hero action:** nền Lime Pour, chữ `onLime` (mực cố định, không đảo theo chế độ tối), chỉ trên `HeroCard` nền Night Shift.
- **Disabled:** nền Disabled Fill, chữ Text Secondary.
- **Destructive:** nền `AppColors.danger` (#B42318), chữ trắng, ở cả hai chế độ.

### Chips
- **Style:** viên bo tròn, nền tint trạng thái, chữ màu trạng thái 12px đậm (`StatusChip`, `StatusPill`).
- **State:** bốn mức Ổn / Cần xem / Nghiêm trọng / Trung tính (Pale Tint + Text Secondary).

### Cards / Containers
- **Corner Style:** bo lớn (20px).
- **Background:** Clean White; thẻ nổi bật dùng Night Shift với chữ trắng.
- **Shadow Strategy:** không bóng (xem Elevation & Depth).
- **Border:** 1 px Card Edge.
- **Internal Padding:** 16px (`cardPadding`).

### Inputs / Fields
- **Style:** nền trắng, viền 1 px Hairline, bo 12px, đệm 14px (`AppTextField`, `MoneyField`).
- **Focus:** viền đổi sang Ink Teal.
- **Error / Disabled:** viền và chữ lỗi Status Critical 12px dưới ô; viền vô hiệu giữ Hairline.

### Navigation
- **Chuẩn:** `AdaptiveNavScaffold` cho cả luồng chủ quán và nhân viên. Điện thoại: Material `NavigationBar` cao 68 dp, nền trắng, viên chỉ báo Nav Indicator, nhãn Inter 12px (700 khi chọn, 500 khi không). Máy tính bảng: `NavigationRail` cùng màu và nhãn.
- **Tab bị khóa** (cần mở ca): mờ, không chọn được, vẫn được trình đọc màn hình đọc.

### Icons
- **Material Symbols (`Icons.*`, kiểu outlined/rounded)** là bộ mặc định cho mọi màn.
- **`ForeIcon` (SVG trong `assets/icons/`)** chỉ cho điều hướng và thao tác nghiệp vụ của luồng nhân viên (trang chủ, mang đi, kho, đóng ca) và `ForeActionIcons` cho hao hụt, thu/chi.
- Không trộn hai bộ trong cùng một nhóm điều khiển.

### Segmented Control
Khung Pale Tint bo 16px, đệm 4px; đoạn chọn cao tối thiểu 44 dp (cao thêm khi chữ to) nền Ink Teal chữ trắng Inter 700 15px, đoạn còn lại chữ Ink Teal. Dùng cho chuyển nhanh giữa hai đến ba chế độ (ví dụ số điện thoại / email).

### Qty Stepper
Nút tròn trừ/cộng hiển thị 36–40px nhưng vùng chạm 48×48; nút cộng nền Ink Teal icon trắng, nút trừ nền Pale Tint icon Ink Teal. Dùng trong bill và phiếu nhập.

## Do's and Don'ts

### Do:
- **Do** lấy mọi màu, cỡ chữ, khoảng cách từ `lib/core/design/` (`AppColors`, `AppTextStyles`, `AppSizes`).
- **Do** giữ vùng chạm tối thiểu 48×48 dp, kể cả khi phần nhìn thấy nhỏ hơn.
- **Do** dùng `Motion.of(context, ...)` cho mọi thời lượng chuyển động.
- **Do** dùng Text Secondary (#4F6663) cho chữ phụ và Warning Text (#B54708) cho chữ cảnh báo.
- **Do** dùng thành phần trong `core/design/` cho màn mới; chuyển màn cũ khi sửa tới.

### Don't:
- **Don't** thêm bóng đổ cho thẻ, nút hoặc thanh điều hướng mới.
- **Don't** viết mã màu thô (`Color(0x...)`) hay `Colors.*` ngoài `lib/core/design/`.
- **Don't** dùng Counter Teal (#51A19B) hay `warning` (#ED6C02) cho chữ: đều dưới 4,5:1 ở chế độ sáng.
- **Don't** dùng `Colors.white` trên nền mực; dùng `AppColors.onInk` để đúng ở cả hai chế độ.
- **Don't** dùng Lime Pour trên nền sáng hoặc cho hành động phụ.
- **Don't** dùng màu trạng thái cho mục đích trang trí.
- **Don't** tạo thêm token "legacy" mới.
- **Don't** dùng `ListView(children: ...)` cho danh sách theo dữ liệu; dùng `LazyListView`.
