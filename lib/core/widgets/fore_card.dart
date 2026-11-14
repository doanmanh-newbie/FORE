import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// Thẻ trắng bo góc mềm có viền mảnh và bóng rất nhẹ: khối nội dung chuẩn của app.
class ForeCard extends StatelessWidget {
  const ForeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppSizes.radiusCard,
    this.color,
    this.onTap,
    this.elevated = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  /// Bóng mờ dưới thẻ. Tắt cho thẻ lồng trong thẻ khác.
  final bool elevated;

  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color ?? AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.cardBorder),
            boxShadow: elevated
                ? [
                    BoxShadow(
                      color: AppColors.shadowMedium.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Icon nét mảnh trong ô vuông bo tròn nền nhạt: đầu thẻ, ô chỉ số, mục danh sách.
class ForeIconBadge extends StatelessWidget {
  const ForeIconBadge({
    super.key,
    required this.icon,
    this.color,
    this.background,
    this.size = 40,
  });

  final IconData icon;

  /// Màu icon; mặc định mực rêu.
  final Color? color;

  /// Màu nền; mặc định nền nhạt cùng tông với [color].
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppColors.brand;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        // Icon mặc định (mực rêu): nền rêu nhạt navIndicator, cùng tông ô icon của ActionTile
        // và nút phụ. Icon có màu riêng (trạng thái): nền nhạt cùng tông màu đó.
        color: background ??
            (color == null || color == AppColors.brand
                ? AppColors.navIndicator
                : fg.withValues(alpha: 0.12)),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: fg, size: size * 0.52),
    );
  }
}

/// Tiêu đề phần kèm dòng phụ nhỏ bên phải: "Tầng 1" ... "6 bàn · 2 đang dùng".
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: AppTextStyles.sectionHeading)),
          if (trailing != null) Text(trailing!, style: AppTextStyles.caption),
        ],
      );
}

/// Tiêu đề phần kiểu mới (Inter 18/700) có nút tùy chọn bên phải ("Xem tất cả").
class ForeSectionTitle extends StatelessWidget {
  const ForeSectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.appBarTitle.copyWith(color: AppColors.brand),
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}
