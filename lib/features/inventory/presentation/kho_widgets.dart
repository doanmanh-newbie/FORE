import 'package:flutter/material.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/error_state.dart';
import '../../../core/design/skeleton_box.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/fore_card.dart' show ForeCard;
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../domain/kho_models.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// Khung màn hình con của Kho: tiêu đề có nút quay lại, nội dung, thanh hành động dưới đáy.
class KhoPage extends StatelessWidget {
  const KhoPage({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.bottom,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final Widget? bottom;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            ScreenHeader(title: title, subtitle: subtitle, onBack: onBack),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: bottom == null
            ? null
            : DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.shadowSoft,
                        blurRadius: 18,
                        offset: const Offset(0, -4)),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSizes.pagePadding,
                      12,
                      AppSizes.pagePadding,
                      12 + MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: bottom,
                  ),
                ),
              ),
      );
}

/// Hiển thị một [AsyncData]: khung chờ, lỗi có "Thử lại", hoặc nội dung có kéo để làm mới.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.source, required this.builder});

  final AsyncData<T> source;
  final List<Widget> Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: source,
        builder: (context, _) {
          final data = source.data;
          if (source.phase == LoadPhase.error && data == null) {
            return ErrorState(
              message: source.failure?.userMessage ?? 'Không tải được dữ liệu.',
              onRetry: source.load,
            );
          }
          if (data == null) return const KhoSkeleton();
          // Dựng từng dòng khi cuộn tới: danh sách kho/phiếu có thể dài.
          final children = builder(context, data);
          return RefreshIndicator(
            onRefresh: () => source.load(silent: true),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                AppSizes.pageTopPadding,
                AppSizes.pagePadding,
                AppSizes.pageBottomPadding,
              ),
              itemCount: children.length,
              itemBuilder: (_, i) => children[i],
            ),
          );
        },
      );
}

class KhoSkeleton extends StatelessWidget {
  const KhoSkeleton({super.key});

  @override
  Widget build(BuildContext context) => const LazyListView(
        padding: EdgeInsets.all(AppSizes.pagePadding),
        children: [
          SkeletonBox(height: 120, radius: AppSizes.radiusCard),
          SizedBox(height: 12),
          SkeletonBox(height: 72, radius: AppSizes.radiusCard),
          SizedBox(height: 12),
          SkeletonBox(height: 72, radius: AppSizes.radiusCard),
          SizedBox(height: 12),
          SkeletonBox(height: 72, radius: AppSizes.radiusCard),
        ],
      );
}

/// Thẻ trắng bo góc chuẩn của Kho.
class KhoCard extends StatelessWidget {
  const KhoCard({super.key, required this.child, this.onTap, this.padding});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => ForeCard(
        onTap: onTap,
        padding: padding ?? const EdgeInsets.all(AppSizes.cardPadding),
        child: SizedBox(width: double.infinity, child: child),
      );
}

/// Dòng chữ nhỏ viết hoa (nhãn nhóm) đúng tinh thần thiết kế: "TIỀN ĐANG Ở TRONG KHO".
class KhoEyebrow extends StatelessWidget {
  const KhoEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: AppTextStyles.micro.copyWith(letterSpacing: 0.6),
      );
}

class KhoSectionTitle extends StatelessWidget {
  const KhoSectionTitle(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Row(
          children: [
            Expanded(child: Text(title, style: AppTextStyles.sectionTitle)),
            if (action != null)
              TextButton(
                  onPressed: onAction,
                  child: Text(action!, style: AppTextStyles.captionStrong)),
          ],
        ),
      );
}

class LabelValueRow extends StatelessWidget {
  const LabelValueRow(this.label, this.value, {super.key, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Text(label, style: AppTextStyles.body)),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: strong ? AppTextStyles.bodyStrong : AppTextStyles.body,
              ),
            ),
          ],
        ),
      );
}

/// Con số lớn kèm nhãn và dòng chú thích.
class BigFigure extends StatelessWidget {
  const BigFigure({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.dark = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.white : AppColors.brand;
    final soft = dark ? AppColors.onDarkMuted : AppColors.textSecondary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style:
                AppTextStyles.micro.copyWith(color: soft, letterSpacing: 0.6)),
        const SizedBox(height: 6),
        Text(value, style: AppTextStyles.kpi.copyWith(color: fg)),
        if (caption != null) ...[
          const SizedBox(height: 4),
          Text(caption!, style: AppTextStyles.caption.copyWith(color: soft)),
        ],
      ],
    );
  }
}

/// Huy hiệu trạng thái tồn: Đủ dùng / Sắp hết / Hết hàng.
class StockBadge extends StatelessWidget {
  const StockBadge(this.status, {super.key});

  final StockStatus status;

  @override
  Widget build(BuildContext context) => switch (status) {
        StockStatus.ok => const StatusChip(
            label: 'Đủ dùng', severity: StatusSeverity.healthy, compact: true),
        StockStatus.low => const StatusChip(
            label: 'Sắp hết',
            severity: StatusSeverity.attention,
            compact: true),
        StockStatus.out => const StatusChip(
            label: 'Hết hàng',
            severity: StatusSeverity.critical,
            compact: true),
      };
}

/// Khối nhắn nhủ nhẹ nhàng ("Bạn tự quyết định", "Chưa gồm phiếu mới").
class KhoNote extends StatelessWidget {
  const KhoNote(this.text, {super.key, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.tint,
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: AppTextStyles.caption)),
            ],
          ),
        ),
      );
}

/// Ô tìm kiếm gọn.
class KhoSearchField extends StatelessWidget {
  const KhoSearchField(
      {super.key,
      required this.controller,
      required this.hint,
      this.onChanged});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: const Icon(Icons.search_rounded),
        ),
      );
}

/// Thanh lọc ngang bằng chip.
class KhoChipBar extends StatelessWidget {
  const KhoChipBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: labels.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ChoiceChip(
            label: Text(labels[i]),
            selected: i == selected,
            onSelected: (_) => onSelected(i),
          ),
        ),
      );
}

String stockLine(CatalogItem i) {
  final base = formatKhoQty(i.stock < 0 ? 0 : i.stock, i.unit);
  return i.minStock > 0
      ? '$base · nhắc nhập ở ${formatKhoQty(i.minStock, i.unit)}'
      : base;
}
