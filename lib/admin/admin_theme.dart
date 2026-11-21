import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/design/app_theme.dart';
import '../core/design/colors.dart';
import '../core/design/spacing.dart';
import '../core/design/typography.dart';

/// Bảng màu Super-Admin đồng bộ trực tiếp theo Figma `418:1031` / `418:1055` / `418:1167`:
/// Xanh rừng đậm (#0D3B2E), Xanh ngọc lục bảo (#1F6E58), Xanh ngọc logo (#51A19B),
/// Bạc hà nhạt (#D9E8E3 / #B5D8CD) trên nền kem (#F8F7F2).
abstract final class AdminPalette {
  static const forestDark = Color(0xFF0D3B2E);
  static const forestTeal = Color(0xFF1F6E58);
  static const logoTeal = Color(0xFF51A19B);
  static const logoInk = Color(0xFF0C2D32);
  static const mintSoft = Color(0xFFD9E8E3);
  static const mintMuted = Color(0xFFB5D8CD);
  static const cream = Color(0xFFF8F7F2);
  static const white = Color(0xFFFFFFFF);
}

/// Theme của Fore Admin Web: kế thừa toàn bộ nền tảng `AppTheme` trong `lib/core/`
/// và áp dụng tone màu Xanh rừng + Xanh ngọc của Super-Admin.
abstract final class AdminTheme {
  static ThemeData light() => _apply(AppTheme.light(), isDark: false);

  static ThemeData dark() => _apply(AppTheme.dark(), isDark: true);

  static ThemeData _apply(ThemeData base, {required bool isDark}) {
    final primaryButtonBg =
        isDark ? AdminPalette.logoTeal : AdminPalette.forestTeal;
    final primaryButtonFg =
        isDark ? AdminPalette.forestDark : AdminPalette.white;
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
    );

    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: isDark ? AdminPalette.logoTeal : AdminPalette.forestDark,
        secondary: AdminPalette.forestTeal,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(AppSizes.controlHeight),
          shape: pill,
          backgroundColor: primaryButtonBg,
          foregroundColor: primaryButtonFg,
          disabledBackgroundColor:
              isDark ? AppPalette.dark.disabledFill : AppPalette.light.disabledFill,
          disabledForegroundColor:
              isDark ? AppPalette.dark.textSecondary : AppPalette.light.textSecondary,
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
          foregroundColor:
              isDark ? AdminPalette.mintSoft : AdminPalette.forestDark,
          side: BorderSide(
            color: isDark ? AdminPalette.logoTeal : AdminPalette.forestTeal,
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, AppSizes.controlHeight),
          foregroundColor:
              isDark ? AdminPalette.mintSoft : AdminPalette.forestTeal,
        ),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AdminPalette.forestDark,
        indicatorColor: AdminPalette.forestTeal,
        indicatorShape: StadiumBorder(),
        selectedIconTheme: IconThemeData(color: AdminPalette.white),
        unselectedIconTheme: IconThemeData(color: AdminPalette.mintMuted),
        selectedLabelTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AdminPalette.white,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AdminPalette.mintMuted,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: primaryButtonBg,
        labelStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? AdminPalette.mintSoft : AdminPalette.forestDark,
        ),
        secondaryLabelStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: primaryButtonFg,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AdminPalette.white
              : AppColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AdminPalette.forestTeal
              : AppColors.disabledFill,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AdminPalette.forestTeal
              : AppColors.border,
        ),
      ),
    );
  }
}

/// Logo biểu trưng hình kim cương + ánh sao của Fore (vector gốc từ Figma `418:1035`).
/// Dùng `SvgPicture.string` để giữ gọn trong `lib/admin/` mà không cần sửa `pubspec.yaml`.
class AdminBrandMark extends StatelessWidget {
  const AdminBrandMark({super.key, this.size = 44});

  final double size;

  static const _svg = '''
<svg width="54" height="54" viewBox="0 0 54 54" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M0 29.7L13.5 16.2L27 25.92L40.5 16.2L54 29.7L27 54L0 29.7Z" fill="#0C2D32"/>
  <path d="M0 29.7L13.5 16.2L19.44 23.22L12.42 29.7H0ZM54 29.7L40.5 16.2L34.56 23.22L41.58 29.7H54ZM0 29.7H12.42L27 54L0 29.7ZM54 29.7H41.58L27 54L54 29.7Z" fill="#51A19B"/>
  <path d="M7.56 0H10.8C12.96 9.72 18.9 15.12 27 15.12C35.1 15.12 41.04 9.72 43.2 0H46.44C44.82 12.96 36.72 22.68 30.78 23.22H23.22C17.28 22.68 9.18 12.96 7.56 0Z" fill="#0C2D32"/>
  <circle cx="27" cy="7.02" r="5.94" fill="#51A19B"/>
  <path d="M27 29.16L29.16 35.1L35.1 37.26L29.16 39.42L27 45.36L24.84 39.42L18.9 37.26L24.84 35.1L27 29.16Z" fill="#F3F7F5"/>
</svg>
''';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Logo Fore',
      child: SvgPicture.string(
        _svg,
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }
}

/// Huy hiệu tròn nền sáng chứa [AdminBrandMark], nổi bật trên nền xanh rừng đậm.
class AdminLogoBadge extends StatelessWidget {
  const AdminLogoBadge({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AdminPalette.cream,
        shape: BoxShape.circle,
      ),
      child: AdminBrandMark(size: size * 0.68),
    );
  }
}
