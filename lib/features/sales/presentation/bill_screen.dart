import 'package:flutter/material.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/motion.dart';
import '../../../core/design/skeleton_box.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/ops_icon.dart';
import '../../../core/widgets/fore_sheet.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/qty_stepper.dart';
import '../application/bill_controller.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';
import '../../../core/widgets/lazy_list_view.dart';

part 'bill_menu_tab.dart';
part 'bill_lines_tab.dart';
part 'bill_payment_forms.dart';

/// Gọi món, xem bill, giảm giá, hủy và thanh toán cho MỘT bill (bàn hoặc đơn mang đi).
/// Hai tab: "Gọi món" (chọn vào giỏ, chưa gửi) và "Bill" (các dòng đã gọi, giảm giá, tổng tiền).
class BillScreen extends StatefulWidget {
  const BillScreen({
    super.key,
    required this.repository,
    required this.billId,
    required this.servingLabel,
  });

  final SalesRepository repository;
  final String billId;
  final String servingLabel;

  @override
  State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  late final BillController _c =
      BillController(widget.repository, widget.billId)..load();
  int _tab = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _submitCart() async {
    final portions = _c.cartPortions;
    final ok = await guarded(context, _c.submitCart);
    if (ok == true && mounted) {
      setState(() => _tab = 1);
      showNotice(context,
          'Đã thêm ${formatServings(portions, widget.servingLabel)} vào bill.');
    }
  }

  Future<void> _pay() async {
    final bill = _c.bill;
    if (bill == null) return;
    final method = await showForeSheet<PaymentMethod>(
      context,
      title: 'Thanh toán',
      subtitle:
          '${bill.title} · ${formatServings(bill.portions, widget.servingLabel)}',
      builder: (_) => _PayForm(amount: bill.payable),
    );
    if (method == null || !mounted) return;
    final total = await guarded(context, () => _c.pay(method));
    if (total != null && mounted) {
      showNotice(context, 'Đã thu ${formatVnd(total)} · ${method.label}');
      Navigator.of(context).pop();
    }
  }

  Future<void> _voidLine(BillLine line) async {
    final reason = await askReason(
      context,
      title: 'Bỏ món',
      subtitle:
          '${line.qty} × ${line.itemName} (${line.sizeName}). Bỏ món cần có lý do và được lưu lại.',
      confirmLabel: 'Bỏ món',
      destructive: true,
    );
    if (reason == null || !mounted) return;
    await guarded(context, () => _c.voidLine(line.id, reason));
  }

  Future<void> _discount() async {
    final bill = _c.bill;
    if (bill == null) return;
    final result = await showForeSheet<_DiscountResult>(
      context,
      title: 'Giảm giá',
      subtitle:
          'Tối đa ${formatVnd(bill.subtotal)}. Giảm giá cần có lý do và được lưu lại.',
      builder: (_) => _DiscountForm(current: bill.discount, max: bill.subtotal),
    );
    if (result == null || !mounted) return;
    await guarded(context, () => _c.setDiscount(result.amount, result.reason));
  }

  Future<void> _cancelBill() async {
    final reason = await askReason(
      context,
      title: 'Hủy bill',
      subtitle: 'Bill sẽ đóng lại, không thu tiền. Cần có lý do.',
      confirmLabel: 'Hủy bill',
      destructive: true,
    );
    if (reason == null || !mounted) return;
    final ok = await guarded(context, () => _c.cancelBill(reason));
    if (ok == true && mounted) {
      showNotice(context, 'Đã hủy bill.');
      Navigator.of(context).pop();
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bỏ món đang chọn?'),
        content: const Text('Các món chưa thêm vào bill sẽ mất.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Bỏ và thoát')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) => PopScope(
          canPop: _c.cart.isEmpty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmLeave() && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                _BillHeader(
                  title: _c.bill?.title ?? 'Bill',
                  subtitle: _subtitle(),
                  onBack: () => Navigator.of(context).maybePop(),
                  onCancel: _c.isOpen ? _cancelBill : null,
                ),
                Expanded(child: _body()),
                if (_c.bill != null) _bottomBar(),
              ],
            ),
          ),
        ),
      );

  String _subtitle() {
    final b = _c.bill;
    if (b == null) return '';
    final parts = <String>[
      if (b.areaName != null) b.areaName!,
      if (b.guests != null) '${b.guests} khách',
      'mở ${formatClock(b.openedAt)}',
      formatBillNo(b.billNo),
    ];
    return parts.join(' · ');
  }

  Widget _body() {
    if (_c.phase == LoadPhase.loading && _c.bill == null) {
      return const _BillLoadingState();
    }
    if (_c.phase == LoadPhase.error) {
      return ErrorRetry(
        message: _c.failure?.userMessage ?? 'Không tải được bill.',
        onRetry: _c.load,
      );
    }
    final bill = _c.bill!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: _Segmented(
            labels: ['Gọi món', 'Bill (${bill.portions})'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 200)),
            child: _tab == 0
                ? _MenuTab(key: const ValueKey('menu'), controller: _c)
                : _LinesTab(
                    key: const ValueKey('lines'),
                    controller: _c,
                    servingLabel: widget.servingLabel,
                    onVoid: _voidLine,
                    onDiscount: _discount,
                    onGoMenu: () => setState(() => _tab = 0),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final bill = _c.bill!;
    final Widget action;
    if (!bill.isOpen) {
      final text = bill.status == BillStatus.paid
          ? 'Đã thanh toán · ${bill.paymentMethod == 'transfer' ? 'Chuyển khoản' : 'Tiền mặt'} · ${formatVnd(bill.payable)}'
          : 'Bill đã hủy';
      action = Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(text,
            textAlign: TextAlign.center, style: AppTextStyles.bodyStrong),
      );
    } else if (_c.cartPortions > 0) {
      action = FilledButton(
        onPressed: _c.busy ? null : _submitCart,
        child: Text(
            'Thêm ${formatServings(_c.cartPortions, widget.servingLabel)} · ${formatVnd(_c.cartTotal)}'),
      );
    } else {
      action = FilledButton(
        onPressed: _c.canPay && !_c.busy ? _pay : null,
        child: Text(_c.canPay
            ? 'Thanh toán · ${formatVnd(bill.payable)}'
            : 'Chọn món để bắt đầu'),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: action),
      ),
    );
  }
}
