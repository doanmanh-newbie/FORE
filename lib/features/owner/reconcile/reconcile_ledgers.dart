import 'package:flutter/material.dart';

import '../../../core/format.dart';
import 'reconcile_format.dart';
import 'reconcile_models.dart';
import 'reconcile_widgets.dart';

Color reconcileStatusColor(ReconcileStatus status) =>
    severityForeground(reconcileSeverity(status));

/// Phiếu nguyên liệu: tồn đầu + nhập − tồn cuối = thực dùng, so với lý thuyết.
List<LedgerLine> ingredientLedger(IngredientRecon item) {
  final unit = item.unit;
  final color = reconcileStatusColor(item.status);
  return [
    LedgerLine('Tồn đầu', reconcileQty(item.opening, unit)),
    LedgerLine('+ Nhập trong ca', reconcileQty(item.purchased, unit)),
    LedgerLine('− Tồn cuối', reconcileQty(item.closing, unit)),
    LedgerLine('Thực dùng', reconcileQty(item.actualUsed, unit),
        kind: LedgerKind.subtotal),
    LedgerLine('Lý thuyết theo món đã bán', reconcileQty(item.theoretical, unit)),
    LedgerLine('Trước điều chỉnh', reconcileVarianceText(item.variance, unit),
        kind: LedgerKind.subtotal),
    LedgerLine('− Hao hụt có lý do', reconcileQty(item.justifiedWaste, unit)),
    LedgerLine('Sau điều chỉnh', reconcileVarianceText(item.adjusted, unit),
        kind: LedgerKind.total,
        color: color,
        note: item.adjustedPct == null
            ? null
            : '${reconcilePercent(item.adjustedPct)} so với lý thuyết'),
  ];
}

/// Phiếu tiền mặt: tiền đầu ca + bán + thu − chi = đáng ra có, so với tiền đếm.
List<LedgerLine> cashLedger(CashRecon cash) {
  final color = reconcileStatusColor(cash.status);
  final diff = cash.openingDiff ?? 0;
  return [
    LedgerLine('Tiền đầu ca', formatVnd(cash.opening ?? 0),
        warning: cash.openingDiffFlag && diff != 0
            ? 'Lệch ${formatVnd(diff.abs())} so với cuối ca trước'
            : null),
    LedgerLine('+ Bán tiền mặt', formatVnd(cash.cashSales)),
    LedgerLine('+ Bỏ vào', formatVnd(cash.cashIn)),
    LedgerLine('− Lấy ra', formatVnd(cash.cashOut)),
    LedgerLine('Đáng ra có',
        cash.expected == null ? '—' : formatVnd(cash.expected!),
        kind: LedgerKind.subtotal),
    LedgerLine('Đếm thực tế',
        cash.closing == null ? '—' : formatVnd(cash.closing!)),
    LedgerLine(
        cash.needsAttention ? 'Chênh lệch cần xem lại' : 'Chênh lệch',
        reconcileCashText(cash.variance),
        kind: LedgerKind.total,
        color: color),
  ];
}

/// Đoạn giải thích "không trừ hao hụt hai lần" cho một nguyên liệu có hao hụt.
String wasteExplanation(IngredientRecon item) {
  final unit = item.unit;
  final before = item.variance;
  return '${reconcileQty(item.justifiedWaste, unit)} có lý do đã được trừ khỏi '
      'phần hụt ${reconcileQty(before, unit)}. '
      'Chênh lệch còn cần xem lại là ${reconcileVarianceText(item.adjusted, unit)}.';
}

/// Dùng để kiểm tra khoảng trắng thừa khi so khớp tên.
String reconcileKey(String name) => name.trim().toLowerCase();
