import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/design/colors.dart';
import '../../core/design/skeleton_box.dart';
import '../../core/design/spacing.dart';
import '../../core/design/typography.dart';
import '../../core/format.dart';
import '../../core/widgets/fore_card.dart';

/// Định dạng ngày giờ Việt Nam `dd/MM/yyyy HH:mm` từ `lib/core/format.dart`.
String formatAdminDateTime(DateTime? time, {String empty = 'Chưa có'}) {
  if (time == null) return empty;
  return '${formatDmy(time)} ${formatHm(time)}';
}

/// Định dạng ngày `dd/MM/yyyy` (giữ nguyên phần ngày không lệch múi giờ cho kiểu `date`).
String formatAdminDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}

/// Định dạng JSON đẹp để hiển thị trong dialog lỗi và màn hình `app_config`.
String formatPrettyJson(dynamic value) {
  if (value == null) return 'null';
  const encoder = JsonEncoder.withIndent('  ');
  try {
    return encoder.convert(value);
  } catch (_) {
    return value.toString();
  }
}

/// Định dạng rút gọn 1 dòng cho giá trị JSON trong danh sách.
String formatCompactJson(dynamic value) {
  if (value == null) return 'null';
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}

/// Tiêu đề chuẩn của mỗi màn hình trong Admin Web kèm nút làm mới/hành động.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppGaps.md,
      runSpacing: AppGaps.sm,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTextStyles.screenHeading),
            const SizedBox(height: AppGaps.xs),
            Text(subtitle, style: AppTextStyles.body),
          ],
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Thẻ chỉ số KPI gọn cho bảng điều khiển admin.
class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.accentColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return ForeCard(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      elevated: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ForeIconBadge(icon: icon, color: accentColor),
          const SizedBox(width: AppGaps.md),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppTextStyles.caption),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.number),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Khung hiển thị trạng thái đang tải (dùng [SkeletonBox] từ `lib/core/design/`).
class AdminLoadingList extends StatelessWidget {
  const AdminLoadingList({super.key, this.itemCount = 4});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < itemCount; i++) ...[
          const ForeCard(
            padding: EdgeInsets.all(AppSizes.cardPadding),
            elevated: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 220, height: 18),
                SizedBox(height: AppGaps.sm),
                SkeletonBox(width: 340, height: 14),
                SizedBox(height: AppGaps.xs),
                SkeletonBox(width: 160, height: 12),
              ],
            ),
          ),
          if (i < itemCount - 1) const SizedBox(height: AppSizes.cardGap),
        ],
      ],
    );
  }
}

/// Nhãn monospace gọn cho mã quán, IP, tên sự kiện, tên khóa cấu hình.
class AdminCodeBadge extends StatelessWidget {
  const AdminCodeBadge({
    super.key,
    required this.text,
    this.color,
    this.background,
  });

  final String text;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? AppColors.tint,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: AppTextStyles.captionStrong.copyWith(
            fontFamily: 'monospace',
            color: color ?? AppColors.brand,
          ),
        ),
      ),
    );
  }
}
