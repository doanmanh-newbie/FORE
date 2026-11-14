import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Theme toàn app theo bộ "Rêu & Mù tạt" (xem DESIGN.md):
/// - Nền kem, mực rêu đậm, nút chính viên thuốc vàng mù tạt chữ rêu.
/// - Ô nhập nền trắng, viền #E2E5E1, bo 12, cao 52.
/// - Font Inter cho mọi chữ, kể cả tiêu đề.
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
      // Thanh điều hướng nền rêu đậm cố định ở cả hai chế độ; tab đang chọn là
      // viên mù tạt, icon rêu (7,0:1); tab khác trắng 75% (8,9:1 trên rêu).
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: AppColors.moss,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.mustard,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.disabled)
                ? AppColors.white.withValues(alpha: 0.35)
                : states.contains(WidgetState.selected)
                    ? AppColors.moss
                    : AppColors.white.withValues(alpha: 0.75),
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.disabled)
                ? AppColors.white.withValues(alpha: 0.35)
                : states.contains(WidgetState.selected)
                    ? AppColors.mustard
                    : AppColors.white.withValues(alpha: 0.75),
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.moss,
        indicatorColor: AppColors.mustard,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: const IconThemeData(color: AppColors.moss),
        unselectedIconTheme:
            IconThemeData(color: AppColors.white.withValues(alpha: 0.75)),
        selectedLabelTextStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.mustard),
        unselectedLabelTextStyle: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.white.withValues(alpha: 0.75)),
      ),
      // AppBar của các màn con: nền rêu bo góc dưới, chữ và icon trắng.
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.moss,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.white),
        actionsIconTheme: IconThemeData(color: AppColors.white),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(AppRadius.panel)),
        ),
      ),
      // Bảng trượt từ dưới: nền kem, bo 28 hai góc trên, có tay nắm.
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: p.border,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
      ),
      // Công tắc bật: rãnh rêu, núm trắng; tắt: rãnh nhạt viền xám.
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.onInk
              : p.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.brand
              : p.disabledFill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.brand
              : p.border,
        ),
      ),
      // Viên chọn (ChoiceChip): viên thuốc trắng viền mảnh; đang chọn = mù tạt chữ rêu.
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: p.border)),
        side: BorderSide(color: p.border),
        backgroundColor: p.surface,
        selectedColor: p.accent,
        disabledColor: p.disabledFill,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.brand,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: p.onAccent,
        ),
      ),
      // Dòng danh sách (ListTile, SwitchListTile, CheckboxListTile): tiêu đề cùng kiểu
      // với tiêu đề mục (16/600), mô tả là chữ phụ 12.
      listTileTheme: ListTileThemeData(
        iconColor: p.brand,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: p.textPrimary,
          height: 1.3,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12,
          color: p.textSecondary,
          height: 1.35,
        ),
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
