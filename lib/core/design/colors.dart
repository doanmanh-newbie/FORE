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

  // Bộ màu "Rêu & Mù tạt" (thiết kế lại 11/2026): rêu đậm làm mực, kem làm nền,
  // vàng mù tạt cho hành động chính. Tỷ lệ tương phản ghi theo nền kem #F8F7F2.
  static const light = AppPalette(
    brightness: Brightness.light,
    brand: Color(0xFF0D3B2E), // rêu đậm, 11,6:1
    onInk: Color(0xFFFFFFFF),
    brandAccent: Color(0xFF2D7A5E),
    background: Color(0xFFF8F7F2), // kem / trắng ngà
    surface: Color(0xFFFFFFFF),
    border: Color(0xFFE2E5E1),
    textPrimary: Color(0xFF0D3B2E),
    // Đậm hơn #69756E của bản Figma một chút để đạt 5,3:1 trên nền kem (bản gốc 4,48).
    textSecondary: Color(0xFF5E6A63),
    disabledFill: Color(0xFFE9EAE4),
    statusHealthy: Color(0xFF18794E),
    statusAttention: Color(0xFF8A5A00),
    statusCritical: Color(0xFFB42318),
    statusHealthyTint: Color(0xFFE2F4EA),
    statusAttentionTint: Color(0xFFFFF1CC),
    statusCriticalTint: Color(0xFFFBE4E2),
    warning: Color(0xFFED6C02),
    warningText: Color(0xFFB54708),
    warningSoft: Color(0xFFFFF4E5),
    inkMuted: Color(0xFF5E6A63),
    tint: Color(0xFFEFEEE6),
    onInkMuted: Color(0xB3FFFFFF),
    onInkStrong: Color(0xCCFFFFFF),
    scrim: Color(0x730D3B2E),
    navIndicator: Color(0xFFDCEBE3),
    cardBorder: Color(0xFFE9EBE6),
    backgroundTint: Color(0xFFE3EEE7),
    healthyBackground: Color(0xFFE6F4EC),
    warningOverlay: Color(0x66ED6C02),
    shadowMedium: Color(0x330D3B2E),
    shadowStrong: Color(0xDB0D3B2E),
    accent: Color(0xFFE4BD5A),
    onAccent: Color(0xFF0D3B2E),
    accentTint: Color(0xFFF7EDD2),
    leaf: Color(0xFF2D7A5E),
    textHint: Color(0xFF69756E),
  );

  /// Ca đêm, quầy thiếu sáng: nền rêu than, mực đảo thành xanh lá sáng, mù tạt giữ nguyên.
  static const dark = AppPalette(
    brightness: Brightness.dark,
    brand: Color(0xFFD4E7DC),
    onInk: Color(0xFF0D3B2E),
    brandAccent: Color(0xFF6FC29C),
    background: Color(0xFF0B1A15),
    surface: Color(0xFF12241D),
    border: Color(0xFF2F4A3F),
    textPrimary: Color(0xFFE6EFEA),
    textSecondary: Color(0xFFA9BDB2),
    disabledFill: Color(0xFF1F3329),
    statusHealthy: Color(0xFF5DD39B),
    statusAttention: Color(0xFFF2BE55),
    statusCritical: Color(0xFFFF8E82),
    statusHealthyTint: Color(0xFF12301F),
    statusAttentionTint: Color(0xFF33280C),
    statusCriticalTint: Color(0xFF3B1915),
    warning: Color(0xFFFF9A3D),
    warningText: Color(0xFFFFB070),
    warningSoft: Color(0xFF33240F),
    inkMuted: Color(0xFF8FA89B),
    tint: Color(0xFF1A2E25),
    onInkMuted: Color(0xB30D3B2E),
    onInkStrong: Color(0xCC0D3B2E),
    scrim: Color(0x99000000),
    navIndicator: Color(0xFF23423A),
    cardBorder: Color(0xFF1F362C),
    backgroundTint: Color(0xFF16302A),
    healthyBackground: Color(0xFF133325),
    warningOverlay: Color(0x66FF9A3D),
    shadowMedium: Color(0x59000000),
    shadowStrong: Color(0xE6000000),
    accent: Color(0xFFE4BD5A),
    onAccent: Color(0xFF0D3B2E),
    // Mù tạt 22% trên nền thẻ tối #12241D: ô liu ngả xanh, hợp nền rêu (bản cũ #3A3018 lên màu nâu đục).
    accentTint: Color(0xFF41452A),
    leaf: Color(0xFF2D7A5E),
    textHint: Color(0xFF9DB3A8),
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
  static const surfaceDark = Color(0xFF0D3B2E);

  // Màu thương hiệu cố định (không đảo theo chế độ) cho các mảng đồ họa: thẻ vai trò,
  // panel chào mừng, vòng bước đăng ký. Chữ đặt trên chúng luôn là [white] hoặc [moss].
  static const moss = Color(0xFF0D3B2E);
  static const leafFixed = Color(0xFF2D7A5E);
  static const mustard = Color(0xFFE4BD5A);
  static const cream = Color(0xFFF8F7F2);
  static const actionLime = Color(0xFFD8F27A);
  static const onDarkMuted = Color(0xB3FFFFFF);
  /// Chữ trên nền lime: luôn mực đậm (11,8:1), không đảo theo chế độ tối.
  static const onLime = Color(0xFF0C2D32);
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
