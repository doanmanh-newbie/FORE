/// Khoảng cách và kích thước dùng chung. Lưới 4px.
abstract final class AppSizes {
  static const unit = 4.0;
  /// Lề trái/phải của trang (bằng [screenGutter] của bộ "Rêu & Mù tạt").
  static const pagePadding = 20.0;
  static const pageTopPadding = 16.0;
  static const pageBottomPadding = 32.0;
  static const sectionGap = 24.0;
  static const cardGap = 12.0;
  static const radius = 12.0;
  static const controlHeight = 48.0;
  static const radiusCard = 20.0;
  static const radiusTile = 14.0;
  static const radiusChip = 999.0;
  static const cardPadding = 16.0;
  static const touchTarget = 48.0;

  // --- Bộ "Rêu & Mù tạt" (màn Chào mừng / Đăng nhập / Đăng ký) ---

  /// Lề trái/phải của màn hình form (Figma: 20).
  static const screenGutter = 20.0;

  /// Chiều cao ô nhập (Figma: 52 ở Đăng nhập, 56 ở Đăng ký; thống nhất 52).
  static const fieldHeight = 52.0;

  /// Nút chính hình viên thuốc.
  static const pillButtonHeight = 54.0;

  /// Công tắc viên thuốc (rãnh 52, viên chọn 44, đệm 4).
  static const segmentedHeight = 52.0;

  /// Vòng tròn bước đăng ký và nút quay lại.
  static const stepCircle = 44.0;

  /// Thẻ chọn vai trò ở màn Đăng nhập.
  static const roleCardHeight = 169.0;
}

/// Bo góc theo vai trò của thành phần.
abstract final class AppRadius {
  /// Ô checkbox.
  static const checkbox = 5.0;

  /// Ô nhập liệu.
  static const field = 12.0;

  /// Thẻ chọn vai trò.
  static const roleCard = 16.0;

  /// Mảng lớn: panel chào mừng, đáy header đăng ký, bottom sheet.
  static const panel = 28.0;

  /// Nút viên thuốc, công tắc, vòng tròn.
  static const pill = 999.0;
}

/// Khoảng cách dọc giữa các khối (Figma).
abstract final class AppGaps {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 22.0;
  static const xxl = 28.0;
}
