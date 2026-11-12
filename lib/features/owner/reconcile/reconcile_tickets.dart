import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/status_chip.dart';
import 'reconcile_format.dart';
import 'reconcile_ledgers.dart';
import 'reconcile_models.dart';
import 'reconcile_tabs.dart';
import 'reconcile_widgets.dart';

/// Phiếu nguyên liệu: một trang đầy đủ cho một nguyên liệu của ca.
List<Widget> ingredientTicket(
  ReconcileReport report,
  IngredientRecon item, {
  required Widget meta,
  ValueChanged<PurchaseEntry>? onEditPurchase,
}) {
  final strong = item.needsAttention;
  final purchases = report.purchases
      .where((entry) => reconcileKey(entry.name) == reconcileKey(item.name))
      .toList(growable: false);
  return [
    Text(item.name, style: AppTextStyles.display),
    const SizedBox(height: 4),
    Text(
      '${report.title} · ${reconcileShiftTime(report.openedAt, report.closedAt)}',
      style: AppTextStyles.caption,
    ),
    meta,
    const SizedBox(height: 10),
    Row(
      children: [
        StatusChip(
          label: item.hasData
              ? reconcileStatusLabel(item.status)
              : 'Chưa đối soát',
          severity: reconcileSeverity(item.status),
          compact: true,
        ),
        if (item.important) ...[
          const SizedBox(width: 8),
          const ReconcileTag(label: 'Quan trọng'),
        ],
      ],
    ),
    const SizedBox(height: 14),
    ForeCard(
      padding: const EdgeInsets.all(16),
      child: item.hasData
          ? LedgerCard(lines: ingredientLedger(item))
          : const Text(
              'Thiếu số kiểm kê đầu ca hoặc cuối ca nên chưa tính được nguyên liệu này.',
              style: AppTextStyles.body,
            ),
    ),
    if (item.revenueLoss > 0) ...[
      const SizedBox(height: 8),
      Text(
        'Doanh thu ước tính bị hụt ${reconcileApprox(item.revenueLoss)}. Ước tính theo giá bán trung bình.',
        textAlign: TextAlign.end,
        style: AppTextStyles.caption,
      ),
    ],
    if (item.streakFlag) ...[
      const SizedBox(height: 12),
      ReconcileBanner(
        icon: Icons.trending_up_rounded,
        text: 'Lệch ${item.streakCount} ca liên tiếp',
      ),
    ],
    if (item.hasData && strong) ...[
      const SizedBox(height: 12),
      const Text(
        'Phần hụt còn lại cần kiểm tra số kiểm kê và định lượng; chưa kết luận mất mát.',
        style: AppTextStyles.body,
      ),
    ],
    if (purchases.isNotEmpty) ...[
      const SizedBox(height: 16),
      const Text('Phiếu nhập trong ca', style: AppTextStyles.sectionTitle),
      const SizedBox(height: 8),
      ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (var i = 0; i < purchases.length; i++) ...[
              if (i > 0) const Divider(height: 18, color: AppColors.border),
              _PurchaseRow(
                entry: purchases[i],
                onEdit: onEditPurchase == null
                    ? null
                    : () => onEditPurchase(purchases[i]),
              ),
            ],
          ],
        ),
      ),
    ],
  ];
}

/// Phiếu tiền mặt: đối chiếu két, chuyển khoản, thu chi, bill hủy.
List<Widget> cashTicket(
  ReconcileReport report, {
  required VoidCallback onShowBills,
  required Widget meta,
}) {
  final cash = report.cash;
  return [
    const Text('Phiếu tiền mặt', style: AppTextStyles.display),
    const SizedBox(height: 4),
    Text(
      '${report.title} · ${reconcileShiftTime(report.openedAt, report.closedAt)}',
      style: AppTextStyles.caption,
    ),
    meta,
    const SizedBox(height: 10),
    Align(
      alignment: Alignment.centerLeft,
      child: StatusChip(
        label: reconcileStatusLabel(cash.status),
        severity: reconcileSeverity(cash.status),
        compact: true,
      ),
    ),
    const SizedBox(height: 14),
    if (!cash.hasData)
      const ForeCard(
        padding: EdgeInsets.all(16),
        child: Text(
          'Ca này chưa có số tiền đếm cuối ca để đối chiếu với két.',
          style: AppTextStyles.body,
        ),
      )
    else ...[
      ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Đối chiếu tiền trong két khi đóng ca',
                style: AppTextStyles.caption),
            const SizedBox(height: 8),
            LedgerCard(lines: cashLedger(cash)),
          ],
        ),
      ),
      const SizedBox(height: AppSizes.cardGap),
      ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('Chuyển khoản trong ca',
                      style: AppTextStyles.bodyStrong),
                ),
                Text(formatVnd(cash.transferSales),
                    style: reconcileNumberStyle()),
              ],
            ),
            const Text('Đối chiếu với app ngân hàng',
                style: AppTextStyles.caption),
          ],
        ),
      ),
    ],
    const SizedBox(height: AppSizes.cardGap),
    MovementsCard(movements: report.movements),
    if (cash.cancelledCount > 0) ...[
      const SizedBox(height: AppSizes.cardGap),
      ReconcileBanner(
        icon: Icons.info_outline,
        text:
            '${cash.cancelledCount} bill đã thu rồi hủy · ${formatVnd(cash.cancelledAmount)}',
        actionLabel: report.cancelledBills.isEmpty ? null : 'Xem bill',
        onAction: report.cancelledBills.isEmpty ? null : onShowBills,
      ),
    ],
    const SizedBox(height: AppSizes.cardGap),
    const ReconcileBanner(
      icon: Icons.info_outline,
      severity: StatusSeverity.neutral,
      text:
          'Không gồm chuyển khoản. Chỉ doanh thu bán tiền mặt làm tăng số tiền phải có trong két.',
    ),
    const SizedBox(height: 10),
    const Text(
      'Xem lại số đếm và chứng từ bỏ vào, lấy ra. Ghi chú xử lý không đổi số tiền chênh lệch.',
      style: AppTextStyles.caption,
    ),
  ];
}

/// Danh sách bill đã thu tiền rồi hủy trong ca.
Future<void> showCancelledBillsSheet(
  BuildContext context,
  List<CancelledBill> bills,
) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusCard)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Bill đã thu rồi hủy', style: AppTextStyles.headline),
              const SizedBox(height: 4),
              const Text(
                'Hủy bill đã thu tiền cần chủ quán nhập PIN duyệt.',
                style: AppTextStyles.caption,
              ),
              const SizedBox(height: 12),
              for (final bill in bills)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
                  child: ForeCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                bill.billNo == null
                                    ? 'Bill'
                                    : 'Bill #${bill.billNo}',
                                style: AppTextStyles.bodyStrong,
                              ),
                            ),
                            Text(formatVnd(bill.amount),
                                style: reconcileNumberStyle()),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            bill.cash ? 'Tiền mặt' : 'Chuyển khoản',
                            if (bill.cancelledAt != null)
                              'hủy lúc ${formatHm(bill.cancelledAt!)}',
                          ].join(' · '),
                          style: AppTextStyles.caption,
                        ),
                        if (bill.reason.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Lý do: ${bill.reason}',
                              style: AppTextStyles.body),
                        ],
                        if (bill.cancelledByName.isNotEmpty ||
                            bill.approvedByName.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (bill.cancelledByName.isNotEmpty)
                                'Hủy bởi ${bill.cancelledByName}',
                              if (bill.approvedByName.isNotEmpty)
                                'Duyệt bởi ${bill.approvedByName}',
                            ].join(' · '),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow({required this.entry, this.onEdit});

  final PurchaseEntry entry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final at = entry.at;
    final meta = [
      if (at != null) formatHm(at),
      if (entry.late) 'Nhập bù',
      if (entry.byName.isNotEmpty) 'Nhập bởi ${entry.byName}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
                child: Text('Nhập kho', style: AppTextStyles.bodyStrong)),
            Text(reconcileQty(entry.qty, entry.unit),
                style: reconcileNumberStyle()),
          ],
        ),
        if (meta.isNotEmpty) Text(meta, style: AppTextStyles.caption),
        if (entry.note.isNotEmpty) Text(entry.note, style: AppTextStyles.body),
        if (entry.corrected)
          Text('Đã sửa từ ${reconcileQty(entry.originalQty, entry.unit)}',
              style: AppTextStyles.caption),
        if (onEdit != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                minimumSize: const Size(0, 36),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Sửa số lượng nhập'),
            ),
          ),
      ],
    );
  }
}
