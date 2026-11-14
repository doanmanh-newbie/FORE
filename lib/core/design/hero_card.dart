import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

/// Thẻ nổi bật nền rêu đậm: tiêu đề trắng, nút chính viên thuốc mù tạt, nút phụ viền trắng.
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.title,
    required this.child,
    this.status,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final String title;
  final Widget child;
  final Widget? status;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.cardPadding + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style:
                          AppTextStyles.cardTitle.copyWith(color: AppColors.white),
                    ),
                  ),
                  if (status != null) status!,
                ],
              ),
              const SizedBox(height: 12),
              DefaultTextStyle(
                style: AppTextStyles.body.copyWith(color: AppColors.white),
                child: child,
              ),
              if (primaryLabel != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.controlHeight),
                      // Nền thẻ luôn tối: dùng mù tạt cố định, không đảo theo chế độ.
                      backgroundColor: AppColors.mustard,
                      foregroundColor: AppColors.moss,
                    ),
                    onPressed: onPrimary,
                    child: Text(primaryLabel!),
                  ),
                ),
              ],
              if (secondaryLabel != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppSizes.controlHeight),
                      foregroundColor: AppColors.white,
                      side: const BorderSide(color: AppColors.onDarkBorder),
                    ),
                    onPressed: onSecondary,
                    child: Text(secondaryLabel!),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}
