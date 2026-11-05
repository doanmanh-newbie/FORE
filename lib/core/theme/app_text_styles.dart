import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Hai phông của app (file nằm ở `assets/fonts`, khai báo trong pubspec.yaml).
abstract final class AppFonts {
  static const body = 'Inter';
  static const display = 'Inter';
}

/// Kiểu chữ dùng chung. Tiêu đề dùng chữ có chân (Playfair Display), phần còn lại
/// dùng Be Vietnam Pro, đều hỗ trợ đủ dấu tiếng Việt.
abstract final class AppTextStyles {
  static const _serif = AppFonts.display;
  static const serifFamily = AppFonts.display;
  static const sansFamily = AppFonts.body;

  /// Tiêu đề lớn đầu màn (ví dụ "Mở ca").
  static const display = TextStyle(
    fontFamily: _serif,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.1,
  );

  /// Tiêu đề thẻ (ví dụ "Chưa có ca đang mở").
  static const headline = TextStyle(
    fontFamily: _serif,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.25,
  );

  /// Chữ nội dung cỡ lớn trong thẻ.
  static const bodyLarge = TextStyle(
    fontSize: 16,
    color: AppColors.brand,
    height: 1.45,
  );

  static const wordmark = TextStyle(
    fontFamily: _serif,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.1,
  );

  static const screenTitle = TextStyle(
    fontFamily: _serif,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.brand,
    height: 1.2,
  );

  static const body = TextStyle(
    fontSize: 15,
    color: AppColors.textSecondary,
    height: 1.4,
  );

  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const heading = headline;
  static const title = TextStyle(
      fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const bodyStrong = TextStyle(
      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink);
  static const captionStrong = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary);
  static const button = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
  static const numberXL = TextStyle(
      fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.ink);
  static const number = TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink);

  static const caption = TextStyle(
    fontSize: 13,
    color: AppColors.textSecondary,
    height: 1.35,
  );
}
