import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class AppFonts {
  static const body = 'ForeInter';

  /// Font chữ có chân, vẫn khai báo trong pubspec nhưng không còn kiểu chữ nào dùng.
  static const display = 'ForeNewsreader';
}

abstract final class AppFontSizes {
  static const s10 = 10.0;
  static const s11 = 11.0;
  static const s12 = 12.0;
  static const s13 = 13.0;
  static const s14 = 14.0;
  static const s15 = 15.0;
  static const s16 = 16.0;
  static const s18 = 18.0;
  static const s20 = 20.0;
  static const s22 = 22.0;
  static const s24 = 24.0;
  static const s26 = 26.0;
  static const s28 = 28.0;
  static const s32 = 32.0;
  static const s34 = 34.0;
  static const s36 = 36.0;
  static const s38 = 38.0;
  static const s40 = 40.0;
}

/// Vai trò chữ và kích thước trung tâm. Màn hình dùng các kiểu này thay vì
/// tự đặt cỡ chữ và fontFamily.
abstract final class AppTextStyles {
  /// Bộ "Rêu & Mù tạt" dùng Inter cho mọi chữ, kể cả tiêu đề (trước là Newsreader).
  /// Giữ tên cũ để nơi gọi không phải đổi.
  static const serifFamily = AppFonts.body;
  static const sansFamily = AppFonts.body;

  static TextStyle get display => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 32 / 26,
    letterSpacing: -0.3,
  );
  static TextStyle get headline => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.2,
  );
  static TextStyle get pageTitle => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 32 / 26,
    letterSpacing: -0.3,
  );
  static TextStyle get kpi => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 36 / 32,
    fontFeatures: const [FontFeature.tabularFigures()],
    letterSpacing: -0.3,
  );
  static TextStyle get sectionTitle => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 24 / 18,
  );
  static TextStyle get cardTitle => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 20 / 15,
  );
  static TextStyle get bodyLarge => TextStyle(
    fontSize: 16,
    color: AppColors.brand,
    height: 1.4,
  );
  static TextStyle get body => TextStyle(
    fontSize: 14,
    color: AppColors.textSecondary,
    height: 20 / 14,
  );
  static TextStyle get bodyStrong => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 20 / 14,
  );
  static TextStyle get label => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static TextStyle get caption => TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
    height: 16 / 12,
  );
  static TextStyle get captionStrong => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
    height: 16 / 12,
  );
  static TextStyle get micro => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    height: 16 / 12,
  );
  static const button = TextStyle(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle get wordmark => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.1,
    letterSpacing: -0.3,
  );

  // Existing call sites retained while the rest of the app migrates by screen.
  static TextStyle get screenTitle => pageTitle;
  static TextStyle get heading => headline;
  /// Tiêu đề một mục trong danh sách/thẻ (16/600). Trước là `sectionTitle` (18 serif).
  static TextStyle get title => cardTitle.copyWith(fontSize: 16);
  static TextStyle get numberXL => kpi;
  static TextStyle get metricXL => kpi;
  static TextStyle get number => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  // --- Bộ "Rêu & Mù tạt": toàn bộ Inter, tiêu đề đậm, nhãn 13 đậm vừa. ---

  /// Chữ thương hiệu "FORE" (32/700).
  static TextStyle get brandName => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.13,
  );

  /// Tiêu đề lớn màn hình (vd "Đăng nhập", 34/700, chữ khít -1).
  /// Lưu ý: mù tạt trên nền kem chỉ 1,7:1, chỉ dùng cho chữ rất lớn có ngữ cảnh rõ.
  static TextStyle get heroTitle => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 34,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
    letterSpacing: -1,
    height: 1.15,
  );

  /// Tiêu đề trên nền tối của panel chào mừng (26/700, trắng).
  static const panelTitle = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.white,
    height: 1.3,
  );

  /// Tiêu đề thanh trên của màn con (vd "Tạo tài khoản mới", 18/700).
  static TextStyle get appBarTitle => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.accent,
    height: 1.3,
  );

  /// Nhãn phía trên ô nhập (13/600).
  static TextStyle get fieldLabel => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    height: 1.38,
  );

  /// Chữ người dùng gõ trong ô nhập (15/500).
  static TextStyle get input => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    height: 1.47,
  );

  /// Chữ gợi ý trong ô nhập (15/400).
  static TextStyle get inputHint => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
    height: 1.47,
  );

  /// Chữ trên nút viên thuốc (16/600).
  static const pillButton = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    height: 1.5,
  );

  /// Chữ trong công tắc viên thuốc (14/600).
  static const segment = TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  /// Liên kết gạch chân (13/700).
  static TextStyle get link => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.brand,
    height: 1.54,
  );

  /// Tiêu đề màn con trên nền kem (vd tên ca, tên phiếu): Inter 24/700, mực rêu.
  static TextStyle get screenHeading => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.2,
    letterSpacing: -0.3,
  );

  /// Tiêu đề phần / thẻ lớn: Inter 18/700, mực rêu (thay cho Newsreader `sectionTitle`).
  static TextStyle get sectionHeading => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.3,
  );

  /// Nhãn dưới vòng bước (12/600).
  static TextStyle get stepLabel => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.brand,
  );

  static TextStyle get metric => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.brand,
    height: 1.15,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
