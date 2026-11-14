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
import 'reconcile_widgets.dart';

class _TabEmpty extends StatelessWidget {
  const _TabEmpty({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.tint,
              child: Icon(icon, size: 26, color: AppColors.brand),
            ),
            const SizedBox(height: 12),
            Text(title, style: AppTextStyles.title, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(body, style: AppTextStyles.body, textAlign: TextAlign.center),
          ],
        ),
      );
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value, {this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: strong ? AppTextStyles.bodyStrong : AppTextStyles.body,
              ),
            ),
            const SizedBox(width: 12),
            Text(value, style: reconcileNumberStyle()),
          ],
        ),
      );
}

// ---------------------------------------------------------------- Nguyên liệu

class IngredientsTab extends StatelessWidget {
  const IngredientsTab({
    super.key,
    required this.report,
    required this.onLedger,
  });

  final ReconcileReport report;
  final ValueChanged<IngredientRecon> onLedger;

  @override
  Widget build(BuildContext context) {
    if (report.ingredients.isEmpty) {
      return const _TabEmpty(
        icon: Icons.inventory_2_outlined,
        title: 'Chưa có nguyên liệu để đối soát',
        body: 'Hãy thêm nguyên liệu và công thức món, rồi kiểm kê trong ca.',
      );
    }
    final shortItems = report.ingredients
        .where((item) => item.needsAttention && item.isShort)
        .toList(growable: false);
    final others = report.ingredients
        .where((item) => !(item.needsAttention && item.isShort))
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Sau điều chỉnh hao hụt',
                  style: AppTextStyles.bodyStrong),
            ),
            Text('${report.ingredients.length} nguyên liệu',
                style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 10),
        for (final item in shortItems)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
            child: _ShortIngredientCard(
              item: item,
              onLedger: () => onLedger(item),
            ),
          ),
        if (others.isNotEmpty)
          ForeCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < others.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.border),
                  _CompactIngredientRow(
                    item: others[i],
                    onTap: () => onLedger(others[i]),
                  ),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        Text(
          'Đã trừ hao hụt có lý do khỏi phần hụt. Đối chiếu từng nguyên liệu; không cộng g với ml.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _ShortIngredientCard extends StatelessWidget {
  const _ShortIngredientCard({required this.item, required this.onLedger});

  final IngredientRecon item;
  final VoidCallback onLedger;

  @override
  Widget build(BuildContext context) {
    final color = reconcileStatusColor(item.status);
    return ForeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title,
                ),
              ),
              if (item.important) ...[
                const SizedBox(width: 8),
                const ReconcileTag(label: 'Quan trọng'),
              ],
              const SizedBox(width: 8),
              // Màn hẹp hoặc chữ to: chip co lại và cắt chữ thay vì tràn hàng.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: StatusChip(
                  label: reconcileStatusLabel(item.status),
                  severity: reconcileSeverity(item.status),
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    reconcileVarianceText(item.adjusted, item.unit),
                    style: reconcileNumberStyle(size: 28),
                  ),
                ),
              ),
              Text(
                reconcilePercent(item.adjustedPct),
                style: reconcileNumberStyle(size: 16, color: color),
              ),
            ],
          ),
          if (item.revenueLoss > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text('Doanh thu ước tính bị hụt',
                      style: AppTextStyles.caption),
                ),
                Text(reconcileApprox(item.revenueLoss),
                    style: reconcileNumberStyle(size: 14)),
              ],
            ),
          ],
          if (item.streakFlag) ...[
            const SizedBox(height: 10),
            ReconcileBanner(
              icon: Icons.trending_up_rounded,
              text: '${item.name} lệch ${item.streakCount} ca liên tiếp',
            ),
          ],
          const SizedBox(height: 6),
          InkWell(
            onTap: onLedger,
            borderRadius: BorderRadius.circular(AppSizes.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Xem cách tính ${item.name}',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontSize: AppFontSizes.s14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward_rounded,
                      size: 18, color: AppColors.brand),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactIngredientRow extends StatelessWidget {
  const _CompactIngredientRow({required this.item, required this.onTap});

  final IngredientRecon item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final adjusted = item.adjusted;
    final title = item.hasData && adjusted != null && adjusted != 0
        ? '${item.name} · ${reconcileVarianceText(adjusted, item.unit)}'
        : item.name;
    final detail = item.hasData
        ? 'Thực dùng ${reconcileQty(item.actualUsed, item.unit)} · Lý thuyết ${reconcileQty(item.theoretical, item.unit)}'
        : 'Thiếu số kiểm kê đầu ca hoặc cuối ca';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, style: AppTextStyles.bodyStrong),
                      ),
                      if (item.important) ...[
                        const SizedBox(width: 6),
                        const ReconcileTag(label: 'Quan trọng'),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: AppTextStyles.caption),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(
              label: item.hasData
                  ? reconcileStatusLabel(item.status)
                  : 'Chưa đối soát',
              severity: reconcileSeverity(item.status),
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Tiền mặt

class CashTab extends StatelessWidget {
  const CashTab({
    super.key,
    required this.report,
    required this.onLedger,
    this.onShowBills,
  });

  final ReconcileReport report;
  final VoidCallback onLedger;
  final VoidCallback? onShowBills;

  @override
  Widget build(BuildContext context) {
    final cash = report.cash;
    if (!cash.hasData) {
      return const _TabEmpty(
        icon: Icons.payments_outlined,
        title: 'Chưa có số liệu tiền mặt',
        body: 'Ca này chưa có số tiền đếm cuối ca để đối chiếu với két.',
      );
    }
    final variance = cash.variance ?? 0;
    final color = reconcileStatusColor(cash.status);
    final hint = variance < 0
        ? 'Đếm thực tế thấp hơn số ca'
        : variance > 0
            ? 'Đếm thực tế cao hơn số ca'
            : 'Đếm thực tế khớp số ca';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ForeCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('Đối chiếu két ca', style: AppTextStyles.title),
                  ),
                  StatusChip(
                    label: reconcileStatusLabel(cash.status),
                    severity: reconcileSeverity(cash.status),
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(hint, style: AppTextStyles.caption),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  reconcileCashText(variance),
                  style: reconcileNumberStyle(size: 32, color: color),
                ),
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: AppColors.border),
              const SizedBox(height: 6),
              _KeyValueRow('Đáng ra có', formatVnd(cash.expected ?? 0)),
              _KeyValueRow('Đếm thực tế', formatVnd(cash.closing ?? 0)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onLedger,
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Xem phiếu tiền mặt'),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.cardGap),
        ForeCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueRow('Chuyển khoản trong ca', formatVnd(cash.transferSales),
                  strong: true),
              Text('Đối chiếu với app ngân hàng',
                  style: AppTextStyles.caption),
            ],
          ),
        ),
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
        ForeCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValueRow('Tiền đầu ca', formatVnd(cash.opening ?? 0),
                  strong: true),
              Text('Theo phiếu tiền mặt', style: AppTextStyles.caption),
              if ((cash.openingDiff ?? 0) != 0) ...[
                const SizedBox(height: 8),
                ReconcileBanner(
                  icon: Icons.info_outline,
                  severity: StatusSeverity.neutral,
                  text:
                      'Lệch ${formatVnd((cash.openingDiff ?? 0).abs())} so với cuối ca trước',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSizes.cardGap),
        ReconcileBanner(
          icon: Icons.info_outline,
          severity: StatusSeverity.neutral,
          text:
              'Chỉ tính tiền mặt trong két: bán tiền mặt ${formatVnd(cash.cashSales)} được tính vào số ca. Doanh thu chuyển khoản không cộng vào tiền phải có.',
        ),
      ],
    );
  }
}

class MovementsCard extends StatelessWidget {
  const MovementsCard({super.key, required this.movements});

  final List<CashMovement> movements;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Thu chi trong ca', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 8),
            if (movements.isEmpty)
              Text('Ca này không có thu chi.', style: AppTextStyles.body)
            else
              for (var i = 0; i < movements.length; i++) ...[
                if (i > 0) Divider(height: 18, color: AppColors.border),
                _MovementRow(movement: movements[i]),
              ],
          ],
        ),
      );
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});

  final CashMovement movement;

  @override
  Widget build(BuildContext context) {
    final at = movement.at;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (at != null) ...[
              Text(formatHm(at), style: AppTextStyles.caption),
              const SizedBox(width: 8),
            ],
            ReconcileTag(
              label: movement.incoming ? 'Bỏ vào' : 'Lấy ra',
              severity: movement.incoming
                  ? StatusSeverity.healthy
                  : StatusSeverity.critical,
            ),
            if (movement.byName.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  movement.byName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
            const Spacer(),
            Text(formatVnd(movement.amount), style: reconcileNumberStyle()),
          ],
        ),
        if (movement.note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(movement.note, style: AppTextStyles.bodyStrong),
        ],
      ],
    );
  }
}

// ------------------------------------------------------------------- Hao hụt

class WasteTab extends StatelessWidget {
  const WasteTab({
    super.key,
    required this.report,
    required this.onLedger,
    this.onEditEntry,
  });

  final ReconcileReport report;
  final ValueChanged<IngredientRecon> onLedger;
  final ValueChanged<WasteEntry>? onEditEntry;

  @override
  Widget build(BuildContext context) {
    if (report.waste.isEmpty) {
      return const _TabEmpty(
        icon: Icons.delete_outline_rounded,
        title: 'Ca này không ghi hao hụt',
        body: 'Đổ bỏ, làm sai, thử vị... được ghi trong ca sẽ hiện ở đây.',
      );
    }
    final seen = <String>{};
    final explained = <IngredientRecon>[];
    for (final waste in report.waste) {
      final key = reconcileKey(waste.name);
      if (!seen.add(key)) continue;
      for (final item in report.ingredients) {
        if (reconcileKey(item.name) == key && item.justifiedWaste > 0) {
          explained.add(item);
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hao hụt đã ghi nhận', style: AppTextStyles.sectionTitle),
        const SizedBox(height: 2),
        Text(
          '${report.waste.length} dòng ghi nhận trong ca · Chủ quán xem lại',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 10),
        for (final waste in report.waste)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
            child: _WasteCard(waste: waste),
          ),
        if (report.wasteEntries.isNotEmpty) ...[
          Text('Từng lần ghi', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 8),
          ForeCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (var i = 0; i < report.wasteEntries.length; i++) ...[
                  if (i > 0) Divider(height: 18, color: AppColors.border),
                  _WasteEntryRow(
                    entry: report.wasteEntries[i],
                    onEdit: onEditEntry == null
                        ? null
                        : () => onEditEntry!(report.wasteEntries[i]),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSizes.cardGap),
        ],
        for (final item in explained)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.statusHealthyTint,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Không trừ hao hụt hai lần',
                        style: AppTextStyles.bodyStrong),
                    const SizedBox(height: 4),
                    Text(wasteExplanation(item), style: AppTextStyles.body),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => onLedger(item),
                      icon: const Icon(Icons.receipt_long_outlined, size: 18),
                      label: Text('Xem phiếu ${item.name}'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _WasteCard extends StatelessWidget {
  const _WasteCard({required this.waste});

  final WasteRecon waste;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(waste.name, style: AppTextStyles.title),
                ),
                Text(
                  reconcileQty(waste.qty, waste.unit),
                  style: reconcileNumberStyle(size: 18),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(waste.reasonLabel, style: AppTextStyles.bodyStrong),
            Text('${waste.entries} lần ghi', style: AppTextStyles.caption),
            const SizedBox(height: 10),
            StatusChip(
              label: waste.warn ? 'Hao hụt cao, nên xem lại' : 'Đã tính vào điều chỉnh',
              severity:
                  waste.warn ? StatusSeverity.attention : StatusSeverity.healthy,
              compact: true,
            ),
            if (waste.wastePct != null) ...[
              const SizedBox(height: 6),
              Text(
                'Tổng hao hụt ${reconcileQty(waste.wasteTotal, waste.unit)} = ${reconcilePercent(waste.wastePct)} so với lượng dùng lý thuyết',
                style: AppTextStyles.caption,
              ),
            ],
          ],
        ),
      );
}

class _WasteEntryRow extends StatelessWidget {
  const _WasteEntryRow({required this.entry, this.onEdit});

  final WasteEntry entry;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final at = entry.at;
    final meta = [
      if (at != null) formatHm(at),
      entry.reasonLabel,
      if (entry.byName.isNotEmpty) 'Ghi bởi ${entry.byName}',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(entry.name, style: AppTextStyles.bodyStrong),
            ),
            Text(reconcileQty(entry.qty, entry.unit),
                style: reconcileNumberStyle()),
          ],
        ),
        const SizedBox(height: 2),
        Text(meta, style: AppTextStyles.caption),
        if (entry.note.isNotEmpty && entry.note != entry.reasonLabel) ...[
          const SizedBox(height: 2),
          Text(entry.note, style: AppTextStyles.body),
        ],
        if (entry.corrected)
          Text(
            'Đã sửa từ ${reconcileQty(entry.originalQty, entry.unit)}',
            style: AppTextStyles.caption,
          ),
        if (onEdit != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onEdit,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.brand,
                minimumSize: const Size(0, 36),
                padding: EdgeInsets.zero,
              ),
              child: const Text('Sửa số lượng'),
            ),
          ),
      ],
    );
  }
}
