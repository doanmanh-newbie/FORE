import 'package:flutter/material.dart';

import '../../../core/design/skeleton_box.dart';
import '../../../core/errors/network_errors.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_chip.dart';
import 'reconcile_format.dart';
import 'reconcile_list_controller.dart';
import 'reconcile_models.dart';
import 'reconcile_widgets.dart';

/// Danh sách ca đã đóng: chọn ngày, lọc, mỗi ca một thẻ trạng thái.
class ReconcileListView extends StatefulWidget {
  const ReconcileListView({
    super.key,
    required this.header,
    required this.controller,
    required this.onOpen,
    required this.onOpenOverview,
  });

  final Widget header;
  final ReconcileListController controller;
  final ValueChanged<ReconcileReport> onOpen;

  /// "Xem ca đang mở" và "Về tổng quan": ca đang mở được theo dõi ở Tổng quan.
  final VoidCallback onOpenOverview;

  @override
  State<ReconcileListView> createState() => _ReconcileListViewState();
}

class _ReconcileListViewState extends State<ReconcileListView> {
  @override
  void initState() {
    super.initState();
    widget.controller.ensureLoaded();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.controller.date ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Chọn ngày làm việc',
      cancelText: 'Hủy',
      confirmText: 'Chọn',
    );
    if (picked != null) widget.controller.setDate(picked);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          return RefreshIndicator(
            onRefresh: () => controller.reload(silent: true),
            child: PageScaffold(
              header: widget.header,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const Text('Đối soát ca', style: AppTextStyles.display),
                const SizedBox(height: 12),
                _Filters(controller: controller, onPickDate: _pickDate),
                const SizedBox(height: 14),
                ..._body(controller),
              ],
            ),
          );
        },
      );

  List<Widget> _body(ReconcileListController controller) {
    if (controller.loading) return const [_ListSkeleton()];
    if (controller.failure != null && controller.items.isEmpty) {
      return [
        _ListMessage(
          icon: looksLikeNetworkError(controller.failure!)
              ? Icons.wifi_off_rounded
              : Icons.cloud_off_outlined,
          title: looksLikeNetworkError(controller.failure!)
              ? 'Không có kết nối'
              : 'Chưa tải được danh sách ca',
          body: looksLikeNetworkError(controller.failure!)
              ? 'Đối soát cần mạng để tải các ca. Hãy kết nối rồi thử lại.'
              : 'Có lỗi khi tải danh sách ca. Hãy thử lại sau ít phút.',
          primaryLabel: 'Thử lại',
          onPrimary: controller.reload,
        ),
      ];
    }
    if (controller.items.isEmpty) {
      final filtered = controller.date != null ||
          controller.filter != ReconcileFilter.all;
      if (filtered) {
        return [
          _ListMessage(
            icon: Icons.search_off_rounded,
            title: 'Không có ca nào',
            body: 'Không có ca đã đóng khớp với ngày và bộ lọc đang chọn.',
            primaryLabel: 'Xóa bộ lọc',
            onPrimary: () async => controller.clearSelection(),
          ),
        ];
      }
      return [
        _ListMessage(
          icon: Icons.fact_check_outlined,
          badge: 'Chờ đóng ca',
          title: 'Chưa có ca đã đóng',
          body:
              'Đối soát xuất hiện sau ca đóng đầu tiên, khi có số kiểm kê và tiền đếm cuối ca.',
          primaryLabel: controller.hasOpenShift ? 'Xem ca đang mở' : null,
          onPrimary: controller.hasOpenShift
              ? () async => widget.onOpenOverview()
              : null,
          secondaryLabel: 'Về tổng quan',
          onSecondary: widget.onOpenOverview,
        ),
      ];
    }
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              '${controller.items.length} ca đã đóng${controller.hasMore ? '+' : ''}',
              style: AppTextStyles.bodyStrong,
            ),
          ),
          const Text('Ước tính ảnh hưởng', style: AppTextStyles.caption),
        ],
      ),
      const SizedBox(height: 10),
      for (final report in controller.items)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
          child: ReconcileShiftCard(
              report: report,
              onTap: () => widget.onOpen(report),
            ),
        ),
      if (controller.moreFailure != null)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Chưa tải thêm được. Hãy thử lại.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ),
      if (controller.hasMore)
        OutlinedButton(
          onPressed: controller.loadingMore ? null : controller.loadMore,
          child: controller.loadingMore
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Xem thêm ca cũ'),
        ),
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text(
          'Số "≈" là ước tính theo giá bán trung bình, không phải kết luận mất mát.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ),
    ];
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.controller, required this.onPickDate});

  final ReconcileListController controller;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final date = controller.date;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: date == null ? 'Chọn ngày' : 'Đổi ngày',
            child: ExcludeSemantics(
              child: InkWell(
                onTap: onPickDate,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                child: _Pill(
                  icon: Icons.calendar_month_outlined,
                  label: date == null ? 'Gần đây' : formatDmy(date),
                  trailing: Icons.expand_more_rounded,
                ),
              ),
            ),
          ),
        ),
        if (date != null) ...[
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Xóa ngày',
            onPressed: () => controller.setDate(null),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
        const SizedBox(width: 8),
        PopupMenuButton<ReconcileFilter>(
          tooltip: 'Lọc ca',
          initialValue: controller.filter,
          onSelected: controller.setFilter,
          itemBuilder: (context) => [
            for (final option in const [
              ReconcileFilter.all,
              ReconcileFilter.attention,
              ReconcileFilter.pending,
            ])
              PopupMenuItem(value: option, child: Text(option.label)),
          ],
          child: _Pill(
            icon: Icons.tune_rounded,
            label: controller.filter.label,
            trailing: Icons.expand_more_rounded,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.trailing});

  final IconData icon;
  final String label;
  final IconData trailing;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radius),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: AppColors.brand),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyStrong),
            ),
            const SizedBox(width: 4),
            Icon(trailing, size: 20, color: AppColors.textSecondary),
          ],
        ),
      );
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          SkeletonBox(height: 20, width: 140),
          SizedBox(height: 14),
          SkeletonBox(height: 112),
          SizedBox(height: 12),
          SkeletonBox(height: 112),
          SizedBox(height: 12),
          SkeletonBox(height: 112),
        ],
      );
}

class _ListMessage extends StatelessWidget {
  const _ListMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.badge,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? badge;
  final String? primaryLabel;
  final Future<void> Function()? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.tint,
                    child: Icon(icon, size: 32, color: AppColors.brand),
                  ),
                  if (badge != null) ...[
                    const SizedBox(height: 8),
                    Text(badge!, style: AppTextStyles.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center, style: AppTextStyles.headline),
            const SizedBox(height: 8),
            Text(body, textAlign: TextAlign.center, style: AppTextStyles.body),
            const SizedBox(height: 20),
            if (primaryLabel != null && onPrimary != null)
              FilledButton(
                onPressed: () => onPrimary!(),
                child: Text(primaryLabel!),
              ),
            if (secondaryLabel != null && onSecondary != null) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: onSecondary,
                child: Text(secondaryLabel!),
              ),
            ],
          ],
        ),
      );
}

/// Thẻ một ca: dùng chung cho danh sách Đối soát và mục "Ca gần đây" ở Tổng quan.
class ReconcileShiftCard extends StatelessWidget {
  const ReconcileShiftCard({super.key, required this.report, required this.onTap});

  final ReconcileReport report;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final severity = reconcileSeverity(report.overall);
    final streaks = report.streakIngredients;
    final impact = reconcileImpactText(report);
    final hasImpact = report.totalImpact > 0;
    return ForeCard(
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.title, style: AppTextStyles.title),
                    const SizedBox(height: 2),
                    Text(
                      reconcileShiftTime(report.openedAt, report.closedAt),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _HandledBadge(handled: report.handled),
                  const SizedBox(height: 4),
                  Text(
                    impact,
                    style: reconcileNumberStyle(
                      size: hasImpact ? 18 : 14,
                      color: hasImpact
                          ? AppColors.brand
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              StatusChip(
                label: reconcileStatusLabel(report.overall),
                severity: severity,
                compact: true,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reconcileProblemSummary(report),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 22, color: AppColors.textSecondary),
            ],
          ),
          if (streaks.isNotEmpty) ...[
            const SizedBox(height: 10),
            ReconcileBanner(
              icon: Icons.trending_up_rounded,
              text:
                  '${streaks.first.name} lệch ${streaks.first.streakCount} ca liên tiếp',
            ),
          ],
        ],
      ),
    );
  }
}

class _HandledBadge extends StatelessWidget {
  const _HandledBadge({required this.handled});

  final bool handled;

  @override
  Widget build(BuildContext context) {
    final color =
        handled ? AppColors.statusHealthy : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          handled ? Icons.done_all_rounded : Icons.schedule_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          handled ? 'Đã xử lý' : 'Chưa xử lý',
          style: TextStyle(
            fontSize: AppFontSizes.s12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
