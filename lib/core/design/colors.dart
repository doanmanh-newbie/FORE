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

  static const light = AppPalette(
    brightness: Brightness.light,
    brand: Color(0xFF0C2D32),
    onInk: Color(0xFFFFFFFF),
    brandAccent: Color(0xFF51A19B),
    background: Color(0xFFF3F7F5),
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFCBD8D4),
    textPrimary: Color(0xFF14292A),
    textSecondary: Color(0xFF4F6663),
    disabledFill: Color(0xFFE3EAE7),
    statusHealthy: Color(0xFF18794E),
    statusAttention: Color(0xFF8A5A00),
    statusCritical: Color(0xFFB42318),
    statusHealthyTint: Color(0xFFE2F4EA),
    statusAttentionTint: Color(0xFFFFF1CC),
    statusCriticalTint: Color(0xFFFBE4E2),
    warning: Color(0xFFED6C02),
    warningText: Color(0xFFB54708),
    warningSoft: Color(0xFFFFF4E5),
    // Đặc thay vì mực 55%: 4,9:1 trên nền, dùng được cho cả chữ.
    inkMuted: Color(0xFF5B726F),
    tint: Color(0xFFEAF0EE),
    onInkMuted: Color(0xB3FFFFFF),
    onInkStrong: Color(0xCCFFFFFF),
    scrim: Color(0x730C2D32),
    navIndicator: Color(0xFFDDF1EF),
    cardBorder: Color(0xFFE7EFEC),
    backgroundTint: Color(0xFFDDEFE7),
    healthyBackground: Color(0xFFE6F4EC),
    warningOverlay: Color(0x66ED6C02),
    shadowMedium: Color(0x330C2D32),
    shadowStrong: Color(0xDB0C2D32),
  );

  /// Ca đêm, quầy thiếu sáng: nền xanh than, mực đảo thành bạc hà sáng.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    brand: Color(0xFFCFE9E4),
    onInk: Color(0xFF0C2D32),
    brandAccent: Color(0xFF6FC1B9),
    background: Color(0xFF0C1617),
    surface: Color(0xFF142224),
    border: Color(0xFF36504F),
    textPrimary: Color(0xFFE4EFEC),
    textSecondary: Color(0xFFA7BCB8),
    disabledFill: Color(0xFF233335),
    statusHealthy: Color(0xFF5DD39B),
    statusAttention: Color(0xFFF2BE55),
    statusCritical: Color(0xFFFF8E82),
    statusHealthyTint: Color(0xFF12301F),
    statusAttentionTint: Color(0xFF33280C),
    statusCriticalTint: Color(0xFF3B1915),
    warning: Color(0xFFFF9A3D),
    warningText: Color(0xFFFFB070),
    warningSoft: Color(0xFF33240F),
    inkMuted: Color(0xFF8EA6A2),
    tint: Color(0xFF1C2C2E),
    onInkMuted: Color(0xB30C2D32),
    onInkStrong: Color(0xCC0C2D32),
    scrim: Color(0x99000000),
    navIndicator: Color(0xFF24403F),
    cardBorder: Color(0xFF22383A),
    backgroundTint: Color(0xFF17302B),
    healthyBackground: Color(0xFF133325),
    warningOverlay: Color(0x66FF9A3D),
    shadowMedium: Color(0x59000000),
    shadowStrong: Color(0xE6000000),
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

  // Không đổi theo chế độ: thẻ nổi bật luôn nền tối, chữ trên nó luôn sáng.
  static const surfaceDark = Color(0xFF123C3A);
  static const actionLime = Color(0xFFD8F27A);
  static const onDarkMuted = Color(0xB3FFFFFF);
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
