import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_chip.dart';
import 'reconcile_format.dart';
import 'reconcile_ledgers.dart';
import 'reconcile_models.dart';
import 'reconcile_tabs.dart';
import 'reconcile_tickets.dart';
import 'reconcile_widgets.dart';

enum _Section { overview, ingredients, cash, waste }

/// Chi tiết đối soát một ca: tổng quan, rồi ba tab Nguyên liệu, Tiền mặt, Hao hụt.
class ReconcileDetailView extends StatefulWidget {
  const ReconcileDetailView({
    super.key,
    required this.report,
    required this.header,
    required this.onBack,
    required this.onSaveReview,
    this.onOpenMenu,
    this.onCorrect,
  });

  final ReconcileReport report;
  final Widget header;
  final VoidCallback onBack;

  /// Lưu trạng thái xử lý và ghi chú; trả về `true` khi lưu thành công.
  final Future<bool> Function(bool handled, String note) onSaveReview;

  /// Mở màn Thực đơn khi chủ bấm "Xem món" ở dải món chưa có công thức.
  final VoidCallback? onOpenMenu;

  /// Sửa số lượng một phiếu nhập hoặc một lần ghi hao hụt; trả về `true` khi lưu được.
  /// Khi lưu xong, nơi gọi tải lại báo cáo và truyền `report` mới vào đây.
  final Future<bool> Function(
    CorrectionKind kind,
    String id,
    int newQty,
    String reason,
  )? onCorrect;

  @override
  State<ReconcileDetailView> createState() => _ReconcileDetailViewState();
}

class _ReconcileDetailViewState extends State<ReconcileDetailView> {
  _Section _section = _Section.overview;
  late bool _handled = widget.report.handled;
  late String _note = widget.report.note;
  String? _ingredientTicket;
  bool _cashTicket = false;

  bool get _inTicket => _ticketItem != null || _cashTicket;

  ReconcileReport get _report => widget.report;

  void _go(_Section section) => setState(() => _section = section);

  void _back() {
    if (_inTicket) {
      setState(() {
        _ingredientTicket = null;
        _cashTicket = false;
      });
    } else if (_section == _Section.overview) {
      widget.onBack();
    } else {
      _go(_Section.overview);
    }
  }

  Future<bool> _save(bool handled, String note) async {
    final saved = await widget.onSaveReview(handled, note);
    if (saved && mounted) {
      setState(() {
        _handled = handled;
        _note = note;
      });
    }
    return saved;
  }

  Future<void> _openReview() => showReviewSheet(
        context,
        title: 'Xử lý ca này',
        subtitle:
            '${_report.title} · ${reconcileShiftTime(_report.openedAt, _report.closedAt)}',
        initialNote: _note,
        initialHandled: _handled,
        onSave: _save,
      );

  void _openIngredientLedger(IngredientRecon item) =>
      setState(() => _ingredientTicket = item.name);

  IngredientRecon? get _ticketItem {
    final name = _ingredientTicket;
    if (name == null) return null;
    for (final item in _report.ingredients) {
      if (item.name == name) return item;
    }
    return null;
  }

  Future<void> _editWaste(WasteEntry entry) {
    final onCorrect = widget.onCorrect;
    if (onCorrect == null) return Future.value();
    return showCorrectionSheet(
      context,
      title: 'Sửa lượng hao hụt',
      subtitle:
          '${entry.name} · ${entry.reasonLabel} · hiện ${reconcileQty(entry.qty, entry.unit)}',
      unit: entry.unit,
      currentQty: entry.qty,
      onSave: (qty, reason) =>
          onCorrect(CorrectionKind.waste, entry.id, qty, reason),
    );
  }

  Future<void> _editPurchase(PurchaseEntry entry) {
    final onCorrect = widget.onCorrect;
    if (onCorrect == null) return Future.value();
    return showCorrectionSheet(
      context,
      title: 'Sửa lượng nhập kho',
      subtitle: '${entry.name} · hiện ${reconcileQty(entry.qty, entry.unit)}',
      unit: entry.unit,
      currentQty: entry.qty,
      onSave: (qty, reason) =>
          onCorrect(CorrectionKind.purchase, entry.id, qty, reason),
    );
  }

  void _openCashLedger() => setState(() => _cashTicket = true);

  void _openCancelledBills() =>
      showCancelledBillsSheet(context, _report.cancelledBills);

  String get _backLabel {
    if (_cashTicket) return 'Tiền mặt';
    if (_ticketItem != null) return 'Nguyên liệu';
    return 'Chi tiết đối soát';
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final inTab = _section != _Section.overview;
    return Column(
      children: [
        Expanded(
          child: PageScaffold(
            header: widget.header,
            children: _inTicket
                ? [
                    _TopBar(label: _backLabel, onBack: _back),
                    ..._ticketContent(report),
                  ]
                : [
                    _TopBar(label: _backLabel, onBack: _back),
                    Text(report.title, style: AppTextStyles.display),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reconcileShiftTime(report.openedAt, report.closedAt),
                            style: AppTextStyles.caption,
                          ),
                        ),
                        _HandledLabel(handled: _handled),
                      ],
                    ),
                    if (report.closedByName.isNotEmpty)
                      Text('Đóng ca bởi ${report.closedByName}',
                          style: AppTextStyles.caption)
                    else if (report.openedByName.isNotEmpty)
                      Text('Mở ca bởi ${report.openedByName}',
                          style: AppTextStyles.caption),
                    const SizedBox(height: 12),
                    if (report.itemsWithoutRecipe > 0) ...[
                      ReconcileBanner(
                        icon: Icons.warning_amber_rounded,
                        text:
                            '${report.itemsWithoutRecipe} món chưa có công thức, đối soát chưa đầy đủ',
                        actionLabel:
                            widget.onOpenMenu == null ? null : 'Xem món',
                        onAction: widget.onOpenMenu,
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (inTab) ...[
                      _CompactVerdict(report: report),
                      const SizedBox(height: 12),
                      _TabBar(selected: _section, onSelect: _go),
                      const SizedBox(height: 14),
                    ],
                    ..._content(report),
                  ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilledButton.icon(
              onPressed: _openReview,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Ghi chú & xử lý'),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _ticketContent(ReconcileReport report) {
    final item = _ticketItem;
    final meta = _TicketMeta(report: report, handled: _handled);
    if (item != null) {
      return ingredientTicket(
        report,
        item,
        meta: meta,
        onEditPurchase: widget.onCorrect == null ? null : _editPurchase,
      );
    }
    return cashTicket(report, onShowBills: _openCancelledBills, meta: meta);
  }

  List<Widget> _content(ReconcileReport report) => switch (_section) {
        _Section.overview => _overview(report),
        _Section.ingredients => [
            IngredientsTab(report: report, onLedger: _openIngredientLedger),
          ],
        _Section.cash => [
            CashTab(
              report: report,
              onLedger: _openCashLedger,
              onShowBills: _openCancelledBills,
            ),
          ],
        _Section.waste => [
            WasteTab(
              report: report,
              onLedger: _openIngredientLedger,
              onEditEntry: widget.onCorrect == null ? null : _editWaste,
            ),
          ],
      };

  List<Widget> _overview(ReconcileReport report) {
    final shortItems = report.ingredients
        .where((item) => item.needsAttention && item.isShort)
        .take(3)
        .toList(growable: false);
    final streaks = report.streakIngredients;
    return [
      _VerdictCard(report: report),
      const SizedBox(height: 12),
      for (final item in streaks)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ReconcileBanner(
            icon: Icons.trending_up_rounded,
            text: '${item.name} lệch ${item.streakCount} ca liên tiếp',
          ),
        ),
      if (report.cash.openingDiffFlag && (report.cash.openingDiff ?? 0) != 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ReconcileBanner(
            icon: Icons.info_outline,
            text:
                'Tiền đầu ca lệch ${formatVnd((report.cash.openingDiff ?? 0).abs())} so với cuối ca trước.',
          ),
        ),
      if (report.noDataIngredientCount > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: ReconcileBanner(
            icon: Icons.info_outline,
            severity: StatusSeverity.neutral,
            text:
                '${report.noDataIngredientCount} nguyên liệu chưa đối soát vì thiếu kiểm kê đầu ca hoặc cuối ca.',
          ),
        ),
      const SizedBox(height: 4),
      ForeCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            for (final item in shortItems) ...[
              _SummaryRow(
                icon: Icons.inventory_2_outlined,
                title: item.name,
                tag: item.important ? 'Quan trọng' : null,
                trailing: reconcileMoneyOrDash(item.revenueLoss),
                detail:
                    'Thực dùng ${reconcileQty(item.actualUsed, item.unit)} · Theo món bán ${reconcileQty(item.theoretical, item.unit)}',
                headline:
                    '${reconcileVarianceText(item.adjusted, item.unit)} · ${reconcilePercent(item.adjustedPct)} sau điều chỉnh',
                onTap: () => _go(_Section.ingredients),
              ),
              Divider(height: 1, color: AppColors.border),
            ],
            if (shortItems.isEmpty) ...[
              _SummaryRow(
                icon: Icons.inventory_2_outlined,
                title: 'Nguyên liệu',
                trailing: report.ingredients.isEmpty
                    ? 'Chưa có'
                    : report.attentionIngredients.isNotEmpty
                        ? '${report.attentionIngredients.length} cần xem'
                        : report.noDataIngredientCount ==
                                report.ingredients.length
                            ? 'Chưa đối soát'
                            : 'Khớp',
                detail: report.ingredients.isEmpty
                    ? 'Chưa có nguyên liệu để đối soát'
                    : '${report.ingredients.length} nguyên liệu trong ca',
                onTap: () => _go(_Section.ingredients),
              ),
              Divider(height: 1, color: AppColors.border),
            ],
            _SummaryRow(
              icon: Icons.payments_outlined,
              title: 'Tiền mặt',
              trailing: reconcileCashText(report.cash.variance),
              trailingColor: report.cash.hasData
                  ? reconcileStatusColor(report.cash.status)
                  : null,
              detail: report.cash.hasData
                  ? 'Đáng ra ${formatVnd(report.cash.expected ?? 0)} · Đếm ${formatVnd(report.cash.closing ?? 0)}'
                  : 'Chưa có tiền đếm cuối ca',
              onTap: () => _go(_Section.cash),
            ),
            Divider(height: 1, color: AppColors.border),
            _SummaryRow(
              icon: Icons.delete_outline_rounded,
              title: 'Hao hụt',
              trailing: report.waste.isEmpty
                  ? 'Không có'
                  : '${report.waste.length} dòng',
              detail: report.waste.isEmpty
                  ? 'Ca này không ghi hao hụt'
                  : 'Hao hụt có lý do đã được trừ khỏi chênh lệch',
              onTap: () => _go(_Section.waste),
            ),
          ],
        ),
      ),
    ];
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.label, required this.onBack});

  final String label;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            onPressed: onBack,
            tooltip: 'Quay lại',
            icon: const Icon(Icons.arrow_back),
          ),
          Text(label, style: AppTextStyles.bodyStrong),
        ],
      );
}

/// Dòng người đóng ca và trạng thái xử lý dưới tiêu đề của một phiếu.
class _TicketMeta extends StatelessWidget {
  const _TicketMeta({required this.report, required this.handled});

  final ReconcileReport report;
  final bool handled;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
                report.closedByName.isNotEmpty
                    ? 'Đóng ca bởi ${report.closedByName}'
                    : report.openedByName.isNotEmpty
                        ? 'Mở ca bởi ${report.openedByName}'
                        : '',
                style: AppTextStyles.caption,
              ),
            ),
            _HandledLabel(handled: handled),
          ],
        ),
      );
}

class _HandledLabel extends StatelessWidget {
  const _HandledLabel({required this.handled});

  final bool handled;

  @override
  Widget build(BuildContext context) {
    final color = handled ? AppColors.statusHealthy : AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(handled ? Icons.done_all_rounded : Icons.schedule_rounded,
            size: 14, color: color),
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

class _VerdictCard extends StatelessWidget {
  const _VerdictCard({required this.report});

  final ReconcileReport report;

  @override
  Widget build(BuildContext context) {
    final cashLoss = report.cashShortfall;
    return ForeCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: StatusChip(
              label: reconcileStatusLabel(report.overall),
              severity: reconcileSeverity(report.overall),
              compact: true,
            ),
          ),
          const SizedBox(height: 12),
          Text('Ảnh hưởng ước tính', style: AppTextStyles.caption),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                reconcileImpactText(report),
                style: reconcileNumberStyle(size: 34),
              ),
            ),
          ),
          Divider(height: 24, color: AppColors.border),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Figure(
                  label: 'Doanh thu ước tính bị hụt',
                  value: reconcileMoneyOrDash(report.ingredientLoss),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Figure(
                  label: 'Tiền mặt thiếu',
                  value: cashLoss > 0 ? formatVnd(cashLoss) : '—',
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.overall == ReconcileStatus.ok
                ? 'Số liệu ca này khớp với lượng đã bán và tiền trong két.'
                : 'Chưa kết luận mất mát. Cần kiểm tra lại số đếm và chứng từ.',
            style: AppTextStyles.caption,
          ),
          if (report.ingredientLoss > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Doanh thu hụt tính theo nguyên liệu hụt nhiều nhất, không cộng các nguyên liệu với nhau vì chúng có thể nằm trong cùng một ly.',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: alignEnd ? TextAlign.end : TextAlign.start,
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 2),
          Text(value, style: reconcileNumberStyle(size: 20)),
        ],
      );
}

/// Thẻ kết luận thu gọn đặt trên đầu các tab.
class _CompactVerdict extends StatelessWidget {
  const _CompactVerdict({required this.report});

  final ReconcileReport report;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StatusChip(
                    label: reconcileStatusLabel(report.overall),
                    severity: reconcileSeverity(report.overall),
                    compact: true,
                  ),
                  const SizedBox(height: 4),
                  Text('Tổng ảnh hưởng ước tính',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Text(reconcileImpactText(report),
                style: reconcileNumberStyle(size: 20)),
          ],
        ),
      );
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.selected, required this.onSelect});

  final _Section selected;
  final ValueChanged<_Section> onSelect;

  static const _tabs = <(_Section, String)>[
    (_Section.ingredients, 'Nguyên liệu'),
    (_Section.cash, 'Tiền mặt'),
    (_Section.waste, 'Hao hụt'),
  ];

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (final (section, label) in _tabs)
            Expanded(
              child: InkWell(
                onTap: () => onSelect(section),
                child: Container(
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: section == selected
                            ? AppColors.brand
                            : AppColors.border,
                        width: section == selected ? 2.5 : 1,
                      ),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: AppFontSizes.s14,
                      fontWeight: section == selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: section == selected
                          ? AppColors.brand
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.detail,
    required this.onTap,
    this.tag,
    this.headline,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final String detail;
  final VoidCallback onTap;
  final String? tag;
  final String? headline;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: AppColors.brand),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title, style: AppTextStyles.bodyStrong),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 6),
                          ReconcileTag(label: tag!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: AppTextStyles.caption),
                    if (headline != null) ...[
                      const SizedBox(height: 2),
                      Text(headline!, style: AppTextStyles.bodyStrong),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                trailing,
                style: reconcileNumberStyle(
                  size: 14,
                  color: trailingColor ?? AppColors.brand,
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textSecondary),
            ],
          ),
        ),
      );
}
