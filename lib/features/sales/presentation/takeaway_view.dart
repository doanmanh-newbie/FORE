import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fore_button.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/ops_icon.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/takeaway_controller.dart';
import '../domain/sales_models.dart';

/// Tab "Mang đi" (thiết kế "Home / Take-away"): đơn chưa xong, cũ nhất ở trên.
/// Nút "Xong" trên từng đơn; bấm xong thì đơn biến mất khỏi danh sách.
class TakeawayView extends StatelessWidget {
  const TakeawayView({
    super.key,
    required this.takeaway,
    required this.servingLabel,
    required this.onOpenBill,
  });

  final TakeawayController takeaway;
  final String servingLabel;
  final Future<void> Function(String billId) onOpenBill;

  Future<void> _create(BuildContext context) async {
    final id = await guarded(context, takeaway.createOrder);
    if (id != null && context.mounted) await onOpenBill(id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: takeaway,
        builder: (context, _) {
          final c = takeaway;
          if (c.phase == LoadPhase.loading && c.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.phase == LoadPhase.error) {
            final failure = c.failure;
            final diagnostic = failure is DatabaseFailure
                ? '\n\nMã lỗi: ${failure.code}'
                : kDebugMode && failure is UnknownFailure
                    ? '\n\nChi tiết kỹ thuật: ${failure.detail}'
                    : '';
            return ErrorRetry(
              message:
                  '${failure?.userMessage ?? 'Không tải được danh sách đơn.'}$diagnostic',
              onRetry: c.load,
            );
          }
          return RefreshIndicator(
            onRefresh: c.load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              itemCount: c.orders.isEmpty ? 2 : c.orders.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Đơn chưa xong',
                                  style: AppTextStyles.sectionHeading),
                              const SizedBox(height: 2),
                              Text('Cũ nhất ở trên',
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        ForeButton(
                          label: 'Tạo đơn',
                          icon: Icons.add_rounded,
                          expand: false,
                          height: 48,
                          onPressed: c.busy ? null : () => _create(context),
                        ),
                      ],
                    ),
                  );
                }
                if (c.orders.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: EmptyState(
                      icon: ForeIcons.bag,
                      title: 'Không có đơn nào đang chờ',
                      message:
                          'Đơn mang đi mới sẽ hiện ở đây cho tới khi bấm "Xong".',
                    ),
                  );
                }
                final order = c.orders[index - 1];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _OrderCard(
                    order: order,
                    servingLabel: servingLabel,
                    longest: c.isLongestWaiting(order),
                    busy: c.busy,
                    onOpen: () => onOpenBill(order.billId),
                    onDone: () => guarded(context, () => c.markDone(order)),
                  ),
                );
              },
            ),
          );
        },
      );
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.servingLabel,
    required this.longest,
    required this.busy,
    required this.onOpen,
    required this.onDone,
  });

  final TakeawayOrder order;
  final String servingLabel;
  final bool longest;
  final bool busy;
  final VoidCallback onOpen;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final waited = DateTime.now().difference(order.openedAt);
    return Semantics(
      button: true,
      label: 'Mở đơn mang đi ${formatBillNo(order.billNo)}',
      child: ForeCard(
        onTap: onOpen,
        radius: 22,
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ForeIconBadge(
                  icon: Icons.shopping_bag_outlined,
                  size: 36,
                  background: AppColors.accentTint,
                ),
                Text(
                  formatClock(order.openedAt),
                  style: TextStyle(
                      fontSize: AppFontSizes.s22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
                Text(formatBillNo(order.billNo),
                    style: AppTextStyles.captionStrong),
                if (longest)
                  const StatusChip(
                    label: 'Chờ lâu nhất',
                    severity: StatusSeverity.attention,
                    compact: true,
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              order.items.isEmpty
                  ? 'Chưa có món'
                  : '${formatServings(order.portions, servingLabel)} · ${order.items}',
              style: TextStyle(
                  fontSize: AppFontSizes.s15,
                  color: AppColors.textPrimary,
                  height: 1.4),
            ),
            const SizedBox(height: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusChip(
                      label: order.isPaid ? 'Đã thu tiền' : 'Chưa thu tiền',
                      severity: order.isPaid
                          ? StatusSeverity.healthy
                          : StatusSeverity.neutral,
                      compact: true,
                    ),
                    Text('Chờ ${formatWait(waited)}',
                        style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 8),
                // Nút phụ (nền rêu nhạt): mỗi thẻ một nút, không tranh với "Tạo đơn".
                Align(
                  alignment: Alignment.centerRight,
                  child: ForeButton(
                    label: 'Xong',
                    icon: Icons.check_rounded,
                    variant: ForeButtonVariant.tonal,
                    expand: false,
                    height: 48,
                    onPressed: busy ? null : onDone,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
