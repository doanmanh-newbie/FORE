import 'package:flutter/material.dart';

import 'spacing.dart';
import 'typography.dart';
import '../widgets/brand_logo.dart';
import '../theme/theme_mode_toggle.dart';

/// Header cho không gian chủ quán: tên quán luôn một dòng, có chọn quán và chuông.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.shopName,
    this.onChooseShop,
    this.onNotifications,
    this.unreadCount = 0,
    this.subtitle = 'Không gian chủ quán',
  });

  final String shopName;
  final VoidCallback? onChooseShop;
  final VoidCallback? onNotifications;
  final int unreadCount;
  final String subtitle;

  @override
  Widget build(BuildContext context) => SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            8,
            AppSizes.pagePadding,
            12,
          ),
          child: Row(
            children: [
              const BrandMark(size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  button: onChooseShop != null,
                  label:
                      onChooseShop == null ? shopName : 'Chọn quán: $shopName',
                  child: InkWell(
                    onTap: onChooseShop,
                    borderRadius: BorderRadius.circular(AppSizes.radius),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  shopName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.cardTitle,
                                ),
                              ),
                              if (onChooseShop != null)
                                const Icon(Icons.expand_more, size: 18),
                            ],
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const ThemeModeToggle(),
              if (onNotifications != null)
                IconButton(
                  tooltip: unreadCount > 0
                      ? 'Thông báo, $unreadCount chưa đọc'
                      : 'Thông báo',
                  onPressed: onNotifications,
                  constraints:
                      const BoxConstraints.tightFor(width: 48, height: 48),
                  icon: Badge(
                    isLabelVisible: unreadCount > 0,
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                ),
            ],
          ),
        ),
      );
}
