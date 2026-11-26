import 'package:flutter/material.dart';

/// Một bộ màu đầy đủ cho một chế độ sáng/tối. [AppColors] đọc từ bộ đang dùng.
@immutable
class AppPalette {
  const AppPalette({
    required this.brightness,
    required this.brand,
    required this.onInk,
    required this.brandAccent,
    required this.background,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.disabledFill,
    required this.statusHealthy,
    required this.statusAttention,
    required this.statusCritical,
    required this.statusHealthyTint,
    required this.statusAttentionTint,
    required this.statusCriticalTint,
    required this.warning,
    required this.warningText,
    required this.warningSoft,
    required this.inkMuted,
    required this.tint,
    required this.onInkMuted,
    required this.onInkStrong,
    required this.scrim,
    required this.navIndicator,
    required this.cardBorder,
    required this.backgroundTint,
    required this.healthyBackground,
    required this.warningOverlay,
    required this.shadowMedium,
    required this.shadowStrong,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.leaf,
    required this.textHint,
  });

  final Brightness brightness;

  /// Mực: chữ chính màu thương hiệu VÀ nền của nút/đoạn đang chọn.
  final Color brand;

  /// Chữ/icon đặt trên nền [brand].
  final Color onInk;
  final Color brandAccent;
  final Color background;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color disabledFill;
  final Color statusHealthy;
  final Color statusAttention;
  final Color statusCritical;
  final Color statusHealthyTint;
  final Color statusAttentionTint;
  final Color statusCriticalTint;
  final Color warning;
  final Color warningText;
  final Color warningSoft;
  final Color inkMuted;
  final Color tint;
  final Color onInkMuted;
  final Color onInkStrong;
  final Color scrim;
  final Color navIndicator;
  final Color cardBorder;
  final Color backgroundTint;
  final Color healthyBackground;
  final Color warningOverlay;
  final Color shadowMedium;
  final Color shadowStrong;

  /// Vàng mù tạt: nền nút hành động chính (viên thuốc), bước đang làm, đoạn đang chọn.
  final Color accent;

  /// Chữ/icon trên nền [accent]: luôn rêu đậm (7,0:1).
  final Color onAccent;

  /// Nền nhạt của vàng mù tạt (huy hiệu, vùng nhấn nhẹ).
  final Color accentTint;

  /// Xanh lá: lớp thứ hai của thương hiệu (thẻ vai trò chưa chọn, rãnh công tắc, bước chưa tới).
  final Color leaf;

  /// Chữ gợi ý trong ô nhập và icon đầu ô (4,8:1 trên nền trắng).
  final Color textHint;

  // Bộ màu "Navy" (big update 11/2026): xanh navy làm mực và nút chính, nền xám lạnh rất nhạt,
  // thẻ trắng. Tỷ lệ tương phản ghi theo nền #F4F6F9 (chữ) hoặc trắng (nút).
  static const light = AppPalette(
    brightness: Brightness.light,
    brand: Color(0xFF1E4A72), // navy, 8,6:1 trên nền
    onInk: Color(0xFFFFFFFF),
    brandAccent: Color(0xFF2F6699), // xanh phụ, 5,6:1 trên trắng
    background: Color(0xFFF4F6F9),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFDDE3EA),
    textPrimary: Color(0xFF14233A),
    textSecondary: Color(0xFF566273), // 5,7:1 trên nền
    disabledFill: Color(0xFFE6EAF0),
    statusHealthy: Color(0xFF18794E),
    statusAttention: Color(0xFF8A5A00),
    statusCritical: Color(0xFFB42318),
    statusHealthyTint: Color(0xFFE2F4EA),
    statusAttentionTint: Color(0xFFFFF1CC),
    statusCriticalTint: Color(0xFFFBE4E2),
    warning: Color(0xFFED6C02),
    warningText: Color(0xFFB54708),
    warningSoft: Color(0xFFFFF4E5),
    inkMuted: Color(0xFF566273),
    tint: Color(0xFFEDF1F6),
    onInkMuted: Color(0xB3FFFFFF),
    onInkStrong: Color(0xCCFFFFFF),
    scrim: Color(0x7314233A),
    navIndicator: Color(0xFFDCE7F3),
    cardBorder: Color(0xFFE6EBF1),
    backgroundTint: Color(0xFFE3ECF6),
    healthyBackground: Color(0xFFE6F4EC),
    warningOverlay: Color(0x66ED6C02),
    shadowMedium: Color(0x1F14233A),
    shadowStrong: Color(0xDB14233A),
    accent: Color(0xFF1E4A72), // nút chính tô navy như bản tham chiếu
    onAccent: Color(0xFFFFFFFF), // 9,4:1
    accentTint: Color(0xFFE3ECF6),
    leaf: Color(0xFF2F6699),
    textHint: Color(0xFF66717F), // 4,9:1 trên trắng
  );

  /// Ca đêm, quầy thiếu sáng: nền than xanh, mực đảo thành xanh nhạt.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    brand: Color(0xFFCFE0F5),
    onInk: Color(0xFF14233A),
    brandAccent: Color(0xFF8DB8E8),
    background: Color(0xFF0B1220),
    surface: Color(0xFF131C2B),
    border: Color(0xFF2B3A50),
    textPrimary: Color(0xFFE6ECF5),
    textSecondary: Color(0xFFA8B6C9),
    disabledFill: Color(0xFF1E2A3B),
    statusHealthy: Color(0xFF5DD39B),
    statusAttention: Color(0xFFF2BE55),
    statusCritical: Color(0xFFFF8E82),
    statusHealthyTint: Color(0xFF12301F),
    statusAttentionTint: Color(0xFF33280C),
    statusCriticalTint: Color(0xFF3B1915),
    warning: Color(0xFFFF9A3D),
    warningText: Color(0xFFFFB070),
    warningSoft: Color(0xFF33240F),
    inkMuted: Color(0xFF8E9DB3),
    tint: Color(0xFF1A2536),
    onInkMuted: Color(0xB314233A),
    onInkStrong: Color(0xCC14233A),
    scrim: Color(0x99000000),
    navIndicator: Color(0xFF24395A),
    cardBorder: Color(0xFF1F2C40),
    backgroundTint: Color(0xFF18263A),
    healthyBackground: Color(0xFF133325),
    warningOverlay: Color(0x66FF9A3D),
    shadowMedium: Color(0x59000000),
    shadowStrong: Color(0xE6000000),
    accent: Color(0xFF9CC2EE),
    onAccent: Color(0xFF0E2540),
    accentTint: Color(0xFF1F3350),
    leaf: Color(0xFF2F6699),
    textHint: Color(0xFF9AA9BE),
  );

  static AppPalette of(Brightness b) => b == Brightness.dark ? dark : light;
}

/// Palette và bộ màu ngữ nghĩa duy nhất của Fore.
///
/// Màu đổi theo chế độ sáng/tối được đọc qua getter từ [current], do `AppPaletteSync`
/// ở gốc app đặt theo theme. Màu không đổi (logo, thẻ nền tối, lime) vẫn là `const`.
// shortcut: bộ màu toàn cục thay vì ThemeExtension theo context, để không phải sửa ~500
// chỗ gọi; chuyển sang `Theme.of(context).extension<...>()` khi cần theme khác nhau trong cùng cây.
abstract final class AppColors {
  static AppPalette current = AppPalette.light;

  static Color get brand => current.brand;
  static Color get onInk => current.onInk;
  static Color get brandAccent => current.brandAccent;
  static Color get background => current.background;
  static Color get surface => current.surface;
  static Color get border => current.border;
  static Color get textPrimary => current.textPrimary;
  static Color get textSecondary => current.textSecondary;
  static Color get disabledFill => current.disabledFill;

  static Color get statusHealthy => current.statusHealthy;
  static Color get statusAttention => current.statusAttention;
  static Color get statusCritical => current.statusCritical;
  static Color get statusHealthyTint => current.statusHealthyTint;
  static Color get statusAttentionTint => current.statusAttentionTint;
  static Color get statusCriticalTint => current.statusCriticalTint;

  static Color get warning => current.warning;
  static Color get warningText => current.warningText;
  static Color get warningSoft => current.warningSoft;
  static Color get inkMuted => current.inkMuted;
  static Color get tint => current.tint;
  static Color get onInkMuted => current.onInkMuted;
  static Color get onSurfaceStrong => current.onInkStrong;
  static Color get navIndicator => current.navIndicator;
  static Color get cardBorder => current.cardBorder;
  static Color get backgroundTint => current.backgroundTint;
  static Color get healthyBackground => current.healthyBackground;
  static Color get warningOverlay => current.warningOverlay;
  static Color get shadowMedium => current.shadowMedium;
  static Color get shadowStrong => current.shadowStrong;

  static Color get accent => current.accent;
  static Color get onAccent => current.onAccent;
  static Color get accentTint => current.accentTint;
  static Color get leaf => current.leaf;
  static Color get textHint => current.textHint;

  // Không đổi theo chế độ: thẻ nổi bật luôn nền tối, chữ trên nó luôn sáng.
  static const surfaceDark = Color(0xFF1E4A72);

  // Bộ Navy: tên cũ `moss`/`leafFixed`/`cream`/`actionLime` giữ để khỏi sửa hàng chục chỗ gọi,
  // giá trị giờ là navy / xanh phụ / nền xám lạnh / trắng.
  // Màu thương hiệu cố định (không đảo theo chế độ) cho các mảng đồ họa: thẻ vai trò,
  // panel chào mừng, vòng bước đăng ký. Chữ đặt trên chúng luôn là [white] hoặc [moss].
  static const moss = Color(0xFF1E4A72);
  static const leafFixed = Color(0xFF2F6699);
  static const mustard = Color(0xFFE4BD5A);
  static const cream = Color(0xFFF4F6F9);
  static const actionLime = Color(0xFFFFFFFF);
  static const onDarkMuted = Color(0xB3FFFFFF);
  /// Chữ trên nền lime: luôn mực đậm (11,8:1), không đảo theo chế độ tối.
  static const onLime = Color(0xFF1E4A72);
  static const onDarkBorder = Color(0x66FFFFFF);
  /// Chữ cảnh báo trên thẻ nền tối (vd "Lãi thấp"): 9,6:1 trên Night Shift.
  static const onDarkWarning = Color(0xFFFFD28A);
  static const white = Color(0xFFFFFFFF);
  /// Nền nút hành động nguy hiểm (xóa, hủy) với chữ trắng: 6,6:1 ở cả hai chế độ.
  static const danger = Color(0xFFB42318);

  // Tên tương thích với các màn đang được chuyển dần sang bộ component mới.
  static Color get statusOk => statusHealthy;
  static Color get statusWatch => statusAttention;
  static Color get statusOff => statusCritical;
  static Color get ink => brand;
  static Color get surfaceTint => tint;
  static Color get hairline => border;
  static Color get textMuted => textSecondary;
  static Color get statusWatchBright => statusAttention;
  static Color get statusOkTint => statusHealthyTint;
  static Color get statusWatchTint => statusAttentionTint;
}
