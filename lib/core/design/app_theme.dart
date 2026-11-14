import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Theme toàn app theo bộ "Rêu & Mù tạt" (xem DESIGN.md):
/// - Nền kem, mực rêu đậm, nút chính viên thuốc vàng mù tạt chữ rêu.
/// - Ô nhập nền trắng, viền #E2E5E1, bo 12, cao 52.
/// - Font Inter cho thân chữ; tiêu đề cũ (Newsreader) chuyển dần theo từng màn.
abstract final class AppTheme {
  static ThemeData light() => build(AppPalette.light);

  static ThemeData dark() => build(AppPalette.dark);

  static ThemeData build(AppPalette p) {
    final scheme = ColorScheme.fromSeed(
      brightness: p.brightness,
      seedColor: p.brand,
      primary: p.brand,
      onPrimary: p.onInk,
      surface: p.surface,
      onSurface: p.textPrimary,
      error: p.statusCritical,
    );
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: p.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      fontFamily: AppFonts.body,
      textTheme: (p.brightness == Brightness.dark
              ? Typography.whiteMountainView
              : Typography.blackMountainView)
          .apply(
        fontFamily: AppFonts.body,
        bodyColor: p.textPrimary,
        displayColor: p.textPrimary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 15,
          color: p.textHint,
        ),
        prefixIconColor: p.textHint,
        suffixIconColor: p.textHint,
        enabledBorder: border(p.border),
        focusedBorder: border(p.brand, 1.5),
        errorBorder: border(p.statusCritical),
        focusedErrorBorder: border(p.statusCritical),
        disabledBorder: border(p.border),
        errorStyle: TextStyle(
          color: p.statusCritical,
          fontSize: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        // Nút hành động chính: viên thuốc vàng mù tạt, chữ rêu (7,0:1).
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: pill,
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          disabledBackgroundColor: p.disabledFill,
          disabledForegroundColor: p.textSecondary,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: pill,
          foregroundColor: p.brand,
          side: BorderSide(color: p.brand),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.controlHeight),
          foregroundColor: p.brand,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: p.surface,
        indicatorColor: p.navIndicator,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: p.brand,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.navIndicator,
        selectedIconTheme: IconThemeData(color: p.brand),
        unselectedIconTheme: IconThemeData(color: p.brand),
        selectedLabelTextStyle: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: p.brand),
        unselectedLabelTextStyle: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: p.brand),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.checkbox),
        ),
        side: BorderSide(color: p.textHint, width: 1.5),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.brand
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(p.onInk),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          side: BorderSide(color: p.cardBorder),
        ),
      ),
    );
  }
}
