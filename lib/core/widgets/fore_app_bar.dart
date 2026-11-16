import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../theme/theme_mode_toggle.dart';
import 'brand_logo.dart';

/// Header nền xanh rêu đậm, bo hai góc dưới 28, tràn hết bề ngang (bộ "Rêu & Mù tạt").
///
/// Hàng trên: huy hiệu logo, tên quán (bấm để đổi quán), dòng phụ, nút sáng/tối, chuông.
/// Tùy chọn [title] + [caption] (tiêu đề trang lớn trên nền tối) và [bottom] (nội dung thêm).
/// Màu nền cố định, không đảo theo chế độ tối, nên chữ luôn trắng.
class ForeAppBar extends StatelessWidget {
  const ForeAppBar({
    super.key,
    required this.shopName,
    this.subtitle,
    this.onChooseShop,
    this.onNotifications,
    this.unreadCount = 0,
    this.onBack,
    this.backTooltip = 'Quay lại',
    this.title,
    this.caption,
    this.titleAction,
    this.bottom,
    this.titleSize = 28,
  });

  final String shopName;
  final String? subtitle;
  final VoidCallback? onChooseShop;
  final VoidCallback? onNotifications;
  final int unreadCount;

  /// Nút quay lại ở cuối hàng trên (vd "Về màn quản lý" từ màn vận hành).
  final VoidCallback? onBack;
  final String backTooltip;

  /// Tiêu đề trang lớn (vd "Tổng quan").
  final String? title;

  /// Dòng nhỏ dưới tiêu đề (vd ngày kinh doanh, giờ cập nhật).
  final Widget? caption;

  /// Nút cạnh tiêu đề (vd làm mới).
  final Widget? titleAction;
  final Widget? bottom;

  /// Cỡ chữ tiêu đề; giảm cho tiêu đề dài để không quá hai dòng.
  final double titleSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.moss,
        borderRadius:
            BorderRadius.vertical(bottom: Radius.circular(AppRadius.panel)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.screenGutter - 4,
            AppGaps.sm,
            AppGaps.sm,
            AppGaps.xl,
          ),
          child: IconTheme(
            data: const IconThemeData(color: AppColors.white),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _LogoBadge(),
                    const SizedBox(width: AppGaps.md),
                    Expanded(child: _ShopName(this)),
                    const ThemeModeToggle(color: AppColors.white),
                    if (onBack != null)
                      IconButton(
                        tooltip: backTooltip,
                        onPressed: onBack,
                        color: AppColors.white,
                        constraints: const BoxConstraints.tightFor(
                            width: 48, height: 48),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    if (onNotifications != null)
                      IconButton(
                        tooltip: unreadCount > 0
                            ? 'Thông báo, $unreadCount chưa đọc'
                            : 'Thông báo',
                        onPressed: onNotifications,
                        color: AppColors.white,
                        constraints: const BoxConstraints.tightFor(
                            width: 48, height: 48),
                        icon: Badge(
                          isLabelVisible: unreadCount > 0,
                          backgroundColor: AppColors.mustard,
                          textColor: AppColors.moss,
                          label: Text('$unreadCount'),
                          child: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                  ],
                ),
                if (title != null) ...[
                  const SizedBox(height: AppGaps.lg),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title!,
                            style: AppTextStyles.panelTitle
                                .copyWith(fontSize: titleSize, height: 1.15),
                          ),
                        ),
                        if (titleAction != null) titleAction!,
                      ],
                    ),
                  ),
                ],
                if (caption != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 12),
                    child: DefaultTextStyle(
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 13,
                        color: AppColors.onDarkMuted,
                        height: 1.45,
                      ),
                      child: caption!,
                    ),
                  ),
                if (bottom != null) ...[
                  SizedBox(height: title == null ? AppGaps.md : AppGaps.lg),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 12),
                    child: bottom!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShopName extends StatelessWidget {
  const _ShopName(this.bar);
  final ForeAppBar bar;

  @override
  Widget build(BuildContext context) {
    final choose = bar.onChooseShop;
    return Semantics(
      button: choose != null,
      label: choose == null ? bar.shopName : 'Chọn quán: ${bar.shopName}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: choose,
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        bar.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    if (choose != null)
                      const Icon(Icons.expand_more_rounded,
                          size: 20, color: AppColors.mustard),
                  ],
                ),
                if (bar.subtitle != null)
                  Text(
                    bar.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 12,
                      color: AppColors.onDarkMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo F trên nền kem tròn, nổi trên nền rêu.
class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.cream,
          shape: BoxShape.circle,
        ),
        child: const BrandMark(size: 28),
      );
}
