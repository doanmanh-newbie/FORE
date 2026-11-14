import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// Thẻ trắng bo góc có bóng nhẹ: khối nội dung chuẩn của app.
class ForeCard extends StatelessWidget {
  const ForeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppSizes.radiusCard,
    this.color,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => PressableScale(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color ?? AppColors.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Padding(padding: padding, child: child),
        ),
      );
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
          Expanded(child: Text(title, style: AppTextStyles.headline)),
          if (trailing != null) Text(trailing!, style: AppTextStyles.caption),
        ],
      );
}
