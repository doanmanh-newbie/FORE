import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/status_chip.dart';
import 'reconcile_models.dart';

StatusSeverity reconcileSeverity(ReconcileStatus status) => switch (status) {
      ReconcileStatus.ok => StatusSeverity.healthy,
      ReconcileStatus.warn => StatusSeverity.attention,
      ReconcileStatus.alert => StatusSeverity.critical,
      ReconcileStatus.noData => StatusSeverity.neutral,
    };

String reconcileStatusLabel(ReconcileStatus status) => switch (status) {
      ReconcileStatus.ok => 'Khớp',
      ReconcileStatus.warn => 'Cần xem',
      ReconcileStatus.alert => 'Chênh lệch lớn',
      ReconcileStatus.noData => 'Chưa đủ dữ liệu',
    };

Color severityForeground(StatusSeverity severity) => switch (severity) {
      StatusSeverity.healthy => AppColors.statusHealthy,
      StatusSeverity.attention => AppColors.statusAttention,
      StatusSeverity.critical => AppColors.statusCritical,
      StatusSeverity.neutral => AppColors.textSecondary,
    };

Color severityBackground(StatusSeverity severity) => switch (severity) {
      StatusSeverity.healthy => AppColors.statusHealthyTint,
      StatusSeverity.attention => AppColors.statusAttentionTint,
      StatusSeverity.critical => AppColors.statusCriticalTint,
      StatusSeverity.neutral => AppColors.tint,
    };

/// Đơn vị gốc trong database (ml, g, piece) đổi sang chữ hiển thị.
String reconcileUnit(String unit) => unit == 'piece' ? 'cái' : unit;

String reconcileQty(int? qty, String unit) =>
    qty == null ? '—' : formatQuantity(qty, unit: reconcileUnit(unit));

/// 10,9% (dấu phẩy thập phân, không dấu +/-: chiều lệch đã có chữ Hụt/Dư).
String reconcilePercent(double? value) => value == null
    ? '—'
    : '${value.abs().toStringAsFixed(1).replaceAll('.', ',')}%';

/// Nguyên liệu: dương = dùng nhiều hơn lý thuyết = hụt hàng.
String reconcileVarianceText(int? adjusted, String unit) {
  if (adjusted == null) return 'Chưa đối soát';
  if (adjusted > 0) return 'Hụt ${reconcileQty(adjusted, unit)}';
  if (adjusted < 0) return 'Dư ${reconcileQty(-adjusted, unit)}';
  return 'Khớp';
}

/// Tiền mặt: âm = đếm ít hơn đáng ra có = thiếu tiền (ngược dấu với nguyên liệu).
String reconcileCashText(int? variance) {
  if (variance == null) return 'Chưa có số liệu';
  if (variance < 0) return 'Thiếu ${formatVnd(-variance)}';
  if (variance > 0) return 'Dư ${formatVnd(variance)}';
  return 'Khớp';
}

String reconcileApprox(int amount) => '≈${formatVnd(amount)}';

String reconcileMoneyOrDash(int amount) =>
    amount > 0 ? reconcileApprox(amount) : '—';

/// 08:02–16:10 · 28/10
String reconcileShiftTime(DateTime? opened, DateTime? closed) {
  if (opened == null) return 'Ca đã đóng';
  final range = closed == null
      ? formatHm(opened)
      : '${formatHm(opened)}–${formatHm(closed)}';
  return '$range · ${opened.day}/${opened.month}';
}

/// Dòng tóm tắt dưới thẻ ca: chỉ nêu phần có vấn đề.
String reconcileProblemSummary(ReconcileReport report) {
  final parts = <String>[];
  final attention = report.attentionIngredients.length;
  if (attention > 0) parts.add('$attention nguyên liệu lệch');
  final cashVariance = report.cash.variance;
  if (report.cash.hasData && cashVariance != null && cashVariance < 0) {
    if (report.cash.needsAttention) {
      parts.add('Tiền mặt thiếu ${formatVnd(-cashVariance)}');
    }
  } else if (report.cash.hasData &&
      cashVariance != null &&
      cashVariance > 0 &&
      report.cash.needsAttention) {
    parts.add('Tiền mặt dư ${formatVnd(cashVariance)}');
  }
  final streaks = report.streakIngredients;
  if (streaks.isNotEmpty) parts.add('${streaks.first.name} lệch nhiều ca liên tiếp');
  if (report.waste.any((waste) => waste.warn)) parts.add('Hao hụt cao');
  if (report.cash.openingDiffFlag) parts.add('Tiền đầu ca lệch');
  if (parts.isEmpty) {
    return report.overall == ReconcileStatus.noData
        ? 'Chưa đủ dữ liệu để đối soát'
        : 'Mọi thứ khớp';
  }
  return parts.join(' · ');
}

/// Số lớn trên thẻ kết luận.
String reconcileImpactText(ReconcileReport report) {
  if (report.totalImpact > 0) return reconcileApprox(report.totalImpact);
  return switch (report.overall) {
    ReconcileStatus.ok => 'Khớp số',
    ReconcileStatus.noData => 'Chưa thể tính',
    _ => 'Chưa ước tính',
  };
}
