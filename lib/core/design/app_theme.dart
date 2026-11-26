import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Theme toàn app theo bộ "Navy" (xem DESIGN.md):
/// - Nền xám lạnh rất nhạt, thẻ trắng, mực navy, nút chính viên thuốc navy chữ trắng.
/// - Ô nhập nền trắng, viền mảnh, bo 12, cao 52.
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
        // Nút hành động chính: viên thuốc navy, chữ trắng (9,4:1).
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
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          foregroundColor: p.brand,
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Thanh điều hướng nền trắng (bộ Navy): tab đang chọn icon navy trên viên nhạt,
      // nhãn navy đậm; tab khác icon và nhãn chữ phụ (5,7:1), không mờ thêm.
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: p.shadowMedium,
        elevation: 3,
        indicatorColor: p.navIndicator,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.disabled)
                ? p.textSecondary.withValues(alpha: 0.4)
                : states.contains(WidgetState.selected)
                    ? p.brand
                    : p.textSecondary,
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
                ? p.textSecondary.withValues(alpha: 0.4)
                : states.contains(WidgetState.selected)
                    ? p.brand
                    : p.textSecondary,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.navIndicator,
        indicatorShape: const StadiumBorder(),
        selectedIconTheme: IconThemeData(color: p.brand),
        unselectedIconTheme: IconThemeData(color: p.textSecondary),
        selectedLabelTextStyle: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: p.brand),
        unselectedLabelTextStyle: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: p.textSecondary),
      ),
      // AppBar của các màn con: nền sáng liền với thân trang, chữ và icon mực.
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: p.textPrimary),
        actionsIconTheme: IconThemeData(color: p.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
        ),
      ),
      // Bảng trượt từ dưới: nền sáng, bo 28 hai góc trên, có tay nắm.
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
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: p.textPrimary,
          height: 1.3,
        ),
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          color: p.textSecondary,
          height: 1.45,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      ),
      // Công tắc bật: rãnh navy, núm trắng; tắt: rãnh nhạt viền xám.
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
      // Viên chọn (ChoiceChip): viên thuốc trắng viền mảnh; đang chọn = navy chữ trắng.
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
        // Gọn hơn mặc định Material (dòng 56→~52), khoảng cách icon–chữ 12.
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 6,
        minLeadingWidth: 24,
        horizontalTitleGap: 12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
        ),
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 15,
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
      // ---- Widget Material mặc định: định kiểu tại đây để không màn nào hiện "widget thô". ----
      // Thanh thông báo nổi, bo tròn, gọn, nằm trên thanh điều hướng.
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.textPrimary,
        contentTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: p.brightness == Brightness.dark ? p.background : p.surface,
          height: 1.35,
        ),
        actionTextColor: p.brightness == Brightness.dark
            ? p.brand
            : const Color(0xFFBFD6F0),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field + 2),
        ),
        elevation: 0,
        showCloseIcon: false,
      ),
      // Vòng/thanh tải màu mực, rãnh nhạt, nét mảnh.
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.brand,
        linearTrackColor: p.tint,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 6,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        strokeWidth: 3,
        strokeCap: StrokeCap.round,
      ),
      // Đường chia mảnh, không chiếm khoảng thừa.
      dividerTheme: DividerThemeData(
        color: p.cardBorder,
        thickness: 1,
        space: 1,
      ),
      // Menu bật lên (PopupMenuButton, DropdownMenu): thẻ trắng bo 14, chữ 14.
      popupMenuTheme: PopupMenuThemeData(
        color: p.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 6,
        shadowColor: p.shadowMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
          side: BorderSide(color: p.cardBorder),
        ),
        textStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: p.textPrimary,
        ),
        menuPadding: const EdgeInsets.symmetric(vertical: 6),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 15,
          color: p.textPrimary,
        ),
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(p.surface),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.radiusTile),
            side: BorderSide(color: p.cardBorder),
          )),
        ),
      ),
      // Gợi ý khi nhấn giữ: viên tối gọn.
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: p.textPrimary.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 12,
          color: p.brightness == Brightness.dark ? p.background : p.surface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: const Duration(milliseconds: 400),
      ),
      // Lịch chọn ngày: cùng bảng màu, bo 28, tiêu đề gọn.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: p.brand,
        headerForegroundColor: p.onInk,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
        dayShape: const WidgetStatePropertyAll(CircleBorder()),
        todayBorder: BorderSide(color: p.brand),
        dividerColor: p.cardBorder,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
        dialBackgroundColor: p.tint,
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
        ),
      ),
      // Ô tích / nút chọn tròn cùng tông.
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? p.brand
              : p.textHint,
        ),
      ),
      // Danh sách mặc định gọn hơn (vùng chạm vẫn >= 48).
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // Nút chữ (TextButton) gọn, đậm vừa.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: p.textPrimary,
          minimumSize: const Size(44, 44),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.brand,
        foregroundColor: p.onInk,
        elevation: 2,
        shape: const StadiumBorder(),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.danger,
        textColor: AppColors.white,
        textStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
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
