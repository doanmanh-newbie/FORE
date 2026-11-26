import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../greeting.dart';
import '../theme/theme_mode_toggle.dart';
import 'brand_logo.dart';

/// Đầu trang các tab chính (bộ "Navy", big update 11/2026).
///
/// Hai tầng, theo bố cục tham chiếu:
/// 1. Hàng trên nền sáng liền thân trang: avatar, "Xin chào, {tên}" + tên quán (bấm để
///    đổi quán), các nút tròn trắng (sáng/tối, quay lại, chuông có số chưa đọc).
/// 2. Nếu có [title] / [caption] / [bottom]: một thẻ navy bo góc (banner) chứa tiêu đề
///    trang, dòng phụ và nội dung thêm. Nền banner cố định tối nên nội dung bên trong
///    vẫn dùng chữ trắng như trước (nơi gọi không phải đổi).
class ForeAppBar extends StatelessWidget {
  const ForeAppBar({
    super.key,
    required this.shopName,
    this.subtitle,
    this.personName,
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
    this.status,
  });

  final String shopName;

  /// Dòng phụ (vd "Chủ quán · Nguyễn An"). Không có [personName] thì tên lấy từ phần sau dấu "·".
  final String? subtitle;

  /// Họ tên người dùng: dùng cho chữ cái trên avatar và lời chào.
  final String? personName;
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

  /// Nhãn trạng thái nhỏ ngay dưới hàng trên, nền sáng (vd trạng thái ca ở màn vận hành).
  /// Không chiếm một banner riêng để bản đồ bàn lên cao hơn.
  final Widget? status;

  /// Họ tên dùng cho avatar/lời chào: [personName], hoặc phần sau "·" của [subtitle].
  String? get _person {
    final name = personName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final sub = subtitle;
    if (sub == null || !sub.contains('·')) return null;
    final tail = sub.split('·').last.trim();
    return tail.isEmpty ? null : tail;
  }

  bool get _hasBanner => title != null || caption != null || bottom != null;

  @override
  Widget build(BuildContext context) {
    final person = _person;
    return ColoredBox(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.screenGutter - 4,
            AppGaps.sm,
            AppSizes.screenGutter - 4,
            _hasBanner ? AppGaps.xs : AppGaps.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _Avatar(name: person),
                  const SizedBox(width: AppGaps.md),
                  Expanded(child: _ShopName(bar: this, person: person)),
                  _CircleAction(child: ThemeModeToggle(color: AppColors.textPrimary)),
                  if (onBack != null) ...[
                    const SizedBox(width: AppGaps.sm),
                    _CircleAction(
                      child: IconButton(
                        tooltip: backTooltip,
                        color: AppColors.textPrimary,
                        onPressed: onBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                  ],
                  if (onNotifications != null) ...[
                    const SizedBox(width: AppGaps.sm),
                    _CircleAction(
                      child: IconButton(
                        tooltip: unreadCount > 0
                            ? 'Thông báo, $unreadCount chưa đọc'
                            : 'Thông báo',
                        onPressed: onNotifications,
                        color: AppColors.textPrimary,
                        icon: Badge(
                          isLabelVisible: unreadCount > 0,
                          backgroundColor: AppColors.danger,
                          textColor: AppColors.white,
                          label: Text(unreadCount > 99 ? '99+' : '$unreadCount'),
                          child: const Icon(Icons.notifications_none_rounded),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (status != null) ...[
                const SizedBox(height: AppGaps.sm),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Align(alignment: Alignment.centerLeft, child: status),
                ),
              ],
              if (_hasBanner) ...[
                const SizedBox(height: AppGaps.lg),
                _Banner(bar: this),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Thẻ navy bo góc: tiêu đề trang, dòng phụ, nội dung thêm. Chữ trắng cố định.
class _Banner extends StatelessWidget {
  const _Banner({required this.bar});
  final ForeAppBar bar;

  @override
  Widget build(BuildContext context) => Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.moss, AppColors.leafFixed],
          ),
        ),
        child: Stack(
          children: [
            // Họa tiết logo mờ ở góc phải: điểm nhấn thương hiệu, không mang thông tin.
            // Góc dưới phải, để không đè nút cạnh tiêu đề (làm mới, quản lý danh mục).
            Positioned(
              right: -36,
              bottom: -56,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0.10,
                  child: Container(
                    width: 150,
                    height: 150,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const BrandMark(size: 96),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 20),
              child: IconTheme(
                data: const IconThemeData(color: AppColors.white),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bar.title != null)
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              bar.title!,
                              style: TextStyle(
                                fontFamily: AppFonts.display,
                                fontSize: bar.titleSize - 2,
                                fontWeight: FontWeight.w600,
                                color: AppColors.white,
                                height: 1.15,
                              ),
                            ),
                          ),
                          // Nút cạnh tiêu đề được co khi thiếu chỗ (màn hẹp, chữ phóng to)
                          // thay vì đẩy tràn hàng.
                          if (bar.titleAction != null)
                            Flexible(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: bar.titleAction!,
                              ),
                            ),
                        ],
                      ),
                    if (bar.caption != null)
                      Padding(
                        padding: EdgeInsets.only(
                            top: bar.title == null ? 0 : 4, right: 8),
                        child: DefaultTextStyle(
                          style: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 13,
                            color: AppColors.onDarkMuted,
                            height: 1.45,
                          ),
                          child: bar.caption!,
                        ),
                      ),
                    if (bar.bottom != null) ...[
                      SizedBox(
                          height: bar.title == null && bar.caption == null
                              ? 0
                              : AppGaps.lg),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: bar.bottom!,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );
}

class _ShopName extends StatelessWidget {
  const _ShopName({required this.bar, required this.person});
  final ForeAppBar bar;
  final String? person;

  @override
  Widget build(BuildContext context) {
    final choose = bar.onChooseShop;
    final first = person == null ? null : shortName(person!);
    final greeting = first == null || first.isEmpty
        ? (bar.subtitle ?? 'Xin chào,')
        : 'Xin chào, $first';
    return Semantics(
      button: choose != null,
      label: choose == null ? bar.shopName : 'Chọn quán: ${bar.shopName}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: choose,
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        bar.shopName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppFonts.body,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    if (choose != null)
                      Icon(Icons.expand_more_rounded,
                          size: 20, color: AppColors.brand),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar tròn: chữ cái đầu của tên trên nền navy nhạt; chưa có tên thì logo Fore.
class _Avatar extends StatelessWidget {
  const _Avatar({this.name});
  final String? name;

  @override
  Widget build(BuildContext context) {
    final initial = name == null || name!.trim().isEmpty
        ? null
        : shortName(name!).characters.first.toUpperCase();
    return ExcludeSemantics(
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.backgroundTint,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: initial == null
            ? const BrandMark(size: 26)
            : Text(
                initial,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.brand,
                ),
              ),
      ),
    );
  }
}

/// Nút tròn nền trắng viền mảnh (chuông, sáng/tối, quay lại) như bản tham chiếu.
class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: IconTheme(
          data: IconThemeData(color: AppColors.textPrimary, size: 22),
          child: Center(child: child),
        ),
      );
}
