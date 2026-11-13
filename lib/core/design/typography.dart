import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class AppFonts {
  static const body = 'ForeInter';
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
  static const serifFamily = AppFonts.display;
  static const sansFamily = AppFonts.body;

  static TextStyle get display => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    color: AppColors.brand,
    height: 32 / 26,
  );
  static TextStyle get headline => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    color: AppColors.brand,
    height: 1.2,
  );
  static TextStyle get pageTitle => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 26,
    fontWeight: FontWeight.w500,
    color: AppColors.brand,
    height: 32 / 26,
  );
  static TextStyle get kpi => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 32,
    fontWeight: FontWeight.w500,
    color: AppColors.brand,
    height: 36 / 32,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle get sectionTitle => TextStyle(
    fontFamily: AppFonts.display,
    fontSize: 18,
    fontWeight: FontWeight.w600,
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
    fontFamily: AppFonts.display,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.brand,
    height: 1.1,
  );

  // Existing call sites retained while the rest of the app migrates by screen.
  static TextStyle get screenTitle => pageTitle;
  static TextStyle get heading => headline;
  static TextStyle get title => sectionTitle;
  static TextStyle get numberXL => kpi;
  static TextStyle get metricXL => kpi;
  static TextStyle get number => TextStyle(
    fontFamily: AppFonts.body,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    fontFeatures: const [FontFeature.tabularFigures()],
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
