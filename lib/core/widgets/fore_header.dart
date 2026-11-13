import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'brand_logo.dart';
import 'status_chip.dart';

/// Đầu trang chung của mọi màn trong ca: tên quán, "Nhân viên · tên", logo và (tùy chọn) nhãn trạng thái ca.
class ForeHeader extends StatelessWidget {
  const ForeHeader({
    super.key,
    required this.shopName,
    required this.subtitle,
    this.pill,
    this.onBack,
    this.onChooseShop,
  });

  final String shopName;
  final String subtitle;
  final Widget? pill;
  final VoidCallback? onBack;
  final VoidCallback? onChooseShop;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: onChooseShop,
                            borderRadius: BorderRadius.circular(8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    shopName,
                                    style: AppTextStyles.wordmark.copyWith(
                                      fontSize: AppFontSizes.s26,
                                      height: 1.08,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (onChooseShop != null)
                                  const Icon(Icons.expand_more, size: 20),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: AppFontSizes.s13,
                              color: AppColors.textSecondary,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (onBack != null) ...[
                      IconButton(
                        tooltip: 'Về màn quản lý',
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 4),
                    ],
                    const _LogoBadge(),
                  ],
                ),
                if (pill != null) ...[
                  const SizedBox(height: 12),
                  pill!,
                ],
              ],
            ),
          ),
        ),
      );
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: BrandMark(size: 34),
        ),
      );
}

/// Nhãn nhỏ có chấm màu: "Chưa mở ca" / "Ca của An, mở lúc 8:02".
class ShiftPill extends StatelessWidget {
  const ShiftPill({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: label,
        severity: active ? StatusSeverity.healthy : StatusSeverity.neutral,
      );
}
