import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

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
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppSizes.radius),
    );
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          borderSide: BorderSide(color: color),
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
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: border(p.border),
        focusedBorder: border(p.brand),
        errorBorder: border(p.statusCritical),
        focusedErrorBorder: border(p.statusCritical),
        disabledBorder: border(p.border),
        errorStyle: TextStyle(
          color: p.statusCritical,
          fontSize: 12,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: shape,
          backgroundColor: p.brand,
          foregroundColor: p.onInk,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: shape,
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
