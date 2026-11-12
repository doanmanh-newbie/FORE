import 'package:flutter/material.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
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
    final qrInfo = await _c.loadQrInfo();
    if (!mounted) return;

    final payResult = await showForeSheet<_PayResult>(
      context,
      title: 'Thanh toán',
      subtitle:
          '${bill.title} · ${formatServings(bill.portions, widget.servingLabel)}',
      builder: (_) => _PayForm(
        amount: bill.payable,
        billNo: bill.billNo,
        qrInfo: qrInfo,
      ),
    );
    if (payResult == null || !mounted) return;

    final total = await guarded(
      context,
      () => _c.pay(
        payResult.method,
        tendered: payResult.tendered,
        paymentRef: payResult.ref,
      ),
    );
    if (total != null && mounted) {
      final changeText = payResult.change > 0
          ? ' · Thối lại ${formatVnd(payResult.change)}'
          : '';
      showNotice(
        context,
        'Đã thu ${formatVnd(total)} (${payResult.method.label})$changeText',
      );
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

  Future<void> _cancelPaidBill() async {
    final bill = _c.bill;
    if (bill == null) return;

    final hasPin = await _c.hasOwnerPin();
    if (!mounted) return;
    if (!hasPin) {
      showNotice(
        context,
        'Quán chưa đặt mã PIN chủ. Hãy nhờ chủ quán cài đặt PIN trước.',
      );
      return;
    }

    final reason = await askReason(
      context,
      title: 'Hủy bill đã thu',
      subtitle:
          'Hủy bill ${formatBillNo(bill.billNo)} (${formatVnd(bill.payable)}). Hành động này hoàn lại kho và cần mã PIN của chủ quán.',
      confirmLabel: 'Tiếp tục',
      destructive: true,
    );
    if (reason == null || !mounted) return;

    final pin = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final pinController = TextEditingController();
        return AlertDialog(
          title: const Text('Nhập mã PIN chủ quán'),
          content: TextField(
            controller: pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            maxLength: 6,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Mã PIN chủ quán (4-6 số)',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, pinController.text.trim()),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
    if (pin == null || pin.isEmpty || !mounted) return;

    final result = await guarded(
      context,
      () => _c.cancelPaidBill(ownerPin: pin, reason: reason),
    );
    if (!mounted) return;

    if (result == 'OK') {
      showNotice(context, 'Đã hủy bill và hoàn lại sổ kho thành công.');
      Navigator.of(context).pop();
    } else if (result == 'WRONG_PIN') {
      showNotice(context, 'Sai mã PIN chủ quán. Hãy kiểm tra lại.');
    } else if (result == 'PIN_LOCKED') {
      showNotice(
        context,
        'Nhập sai PIN quá số lần. Chức năng đã bị khóa tạm thời.',
      );
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
                  onCancel: _c.isOpen
                      ? _cancelBill
                      : (_c.bill?.status == BillStatus.paid ? _cancelPaidBill : null),
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
      return const Center(child: CircularProgressIndicator());
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
            duration: const Duration(milliseconds: 200),
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
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 20,
              offset: Offset(0, -6))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12), child: action),
      ),
    );
  }
}

class _BillHeader extends StatelessWidget {
  const _BillHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onCancel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 18,
                offset: Offset(0, 6))
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded,
                      color: AppColors.ink),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (onCancel != null)
                  PopupMenuButton<String>(
                    tooltip: 'Thêm',
                    icon: const Icon(Icons.more_horiz_rounded,
                        color: AppColors.ink),
                    onSelected: (_) => onCancel!(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'cancel', child: Text('Hủy bill')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Segmented extends StatelessWidget {
  const _Segmented(
      {required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: labels[i],
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == selected
                                ? AppColors.ink
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color:
                                  i == selected ? Colors.white : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------- tab "Gọi món"
class _MenuTab extends StatelessWidget {
  const _MenuTab({super.key, required this.controller});

  final BillController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.isOpen) {
      return const EmptyState(
        icon: ForeIcons.lock,
        title: 'Bill đã đóng',
        message: 'Không gọi thêm món được nữa. Xem các dòng ở tab Bill.',
      );
    }
    final items = c.visibleMenu;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        TextField(
          onChanged: c.setQuery,
          decoration: const InputDecoration(
            hintText: 'Tìm món',
            prefixIcon:
                Icon(Icons.search_rounded, color: AppColors.textSecondary),
          ),
        ),
        if (c.groups.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _GroupChip(
                    label: 'Tất cả',
                    selected: c.selectedGroup == null,
                    onTap: () => c.selectGroup(null)),
                for (final g in c.groups)
                  _GroupChip(
                      label: g,
                      selected: c.selectedGroup == g,
                      onTap: () => c.selectGroup(g)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (c.menu.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Thực đơn đang trống. Chủ quán cần thêm món trước.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          )
        else if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('Không có món nào khớp.',
                textAlign: TextAlign.center, style: AppTextStyles.body),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MenuItemCard(item: item, controller: c),
            ),
      ],
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PressableScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected ? AppColors.ink : AppColors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      );
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item, required this.controller});

  final MenuItemEntry item;
  final BillController controller;

  @override
  Widget build(BuildContext context) {
    final isSoldOut = item.soldOut;
    final itemMods = controller.modifiersForItem(item.id);
    final hasOptions = itemMods.isNotEmpty;

    return ForeCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isSoldOut ? AppColors.textMuted : AppColors.ink,
                              decoration: isSoldOut ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (isSoldOut) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.statusOff.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Hết món',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.statusOff,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (item.group != null)
                      Text(item.group!, style: AppTextStyles.caption),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.textMuted),
                padding: EdgeInsets.zero,
                tooltip: 'Thao tác món',
                onSelected: (action) {
                  if (action == 'toggle_sold_out') {
                    _toggleSoldOut(context);
                  } else if (action == 'customize') {
                    _openCustomize(context);
                  }
                },
                itemBuilder: (ctx) => [
                  if (!isSoldOut)
                    const PopupMenuItem(
                      value: 'customize',
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, size: 18, color: AppColors.ink),
                          SizedBox(width: 8),
                          Text('Tùy chọn & ghi chú', style: AppTextStyles.body),
                        ],
                      ),
                    ),
                  PopupMenuItem(
                    value: 'toggle_sold_out',
                    child: Row(
                      children: [
                        Icon(
                          isSoldOut ? Icons.check_circle_outline_rounded : Icons.block_rounded,
                          size: 18,
                          color: isSoldOut ? AppColors.statusOk : AppColors.statusOff,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isSoldOut ? 'Mở bán lại món này' : 'Báo hết món trong ca',
                          style: TextStyle(
                            fontSize: 14,
                            color: isSoldOut ? AppColors.statusOk : AppColors.statusOff,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (isSoldOut)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Món này đã báo hết trong ca hiện tại.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _toggleSoldOut(context),
                    child: const Text('Mở lại', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            )
          else ...[
            for (final size in item.sizes)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (item.sizes.length > 1 || size.name.isNotEmpty)
                            Text(size.name, style: AppTextStyles.bodyStrong),
                          Text(formatVnd(size.price), style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    QtyStepper(
                      value: controller.cartQty(size.id),
                      max: controller.maxLineQty,
                      onChanged: (q) => controller.setCartQty(size.id, q),
                    ),
                  ],
                ),
              ),
            if (hasOptions) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => _openCustomize(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune_rounded, size: 14, color: AppColors.brand),
                        SizedBox(width: 4),
                        Text(
                          'Tùy chọn topping & ghi chú...',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _openCustomize(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomizeSheet(item: item, controller: controller),
    );
  }

  void _toggleSoldOut(BuildContext context) async {
    final isSoldOut = item.soldOut;
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isSoldOut ? 'Mở bán lại món?' : 'Báo hết món trong ca?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isSoldOut
                  ? 'Món "${item.name}" sẽ được mở bán lại ngay trong ca.'
                  : 'Món "${item.name}" sẽ tạm thời bị khóa cho đến khi hết ca.',
              style: AppTextStyles.body,
            ),
            if (!isSoldOut) ...[
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Lý do (tùy chọn)',
                  hintText: 'Ví dụ: hết trân châu, hỏng máy xay...',
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isSoldOut ? 'Mở bán lại' : 'Xác nhận hết món',
              style: TextStyle(
                color: isSoldOut ? AppColors.brand : AppColors.statusOff,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      await controller.setItemSoldOut(
        itemId: item.id,
        soldOut: !isSoldOut,
        reason: reasonController.text.trim().isEmpty ? null : reasonController.text.trim(),
      );
      if (context.mounted) {
        showNotice(
          context,
          isSoldOut ? 'Đã mở bán lại "${item.name}"' : 'Đã báo hết "${item.name}" trong ca',
        );
      }
    }
  }
}

class _CustomizeSheet extends StatefulWidget {
  const _CustomizeSheet({required this.item, required this.controller});

  final MenuItemEntry item;
  final BillController controller;

  @override
  State<_CustomizeSheet> createState() => _CustomizeSheetState();
}

class _CustomizeSheetState extends State<_CustomizeSheet> {
  late MenuSizeOption _selectedSize;
  final Set<String> _selectedOptionIds = {};
  final TextEditingController _noteController = TextEditingController();
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    _selectedSize = widget.item.sizes.first;
    final groups = widget.controller.modifiersForItem(widget.item.id);
    for (final g in groups) {
      for (final opt in g.options) {
        if (opt.isDefault) {
          _selectedOptionIds.add(opt.id);
        }
      }
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  int get _extraPrice {
    final groups = widget.controller.modifiersForItem(widget.item.id);
    int total = 0;
    for (final g in groups) {
      for (final opt in g.options) {
        if (_selectedOptionIds.contains(opt.id)) {
          total += opt.priceDelta;
        }
      }
    }
    return total;
  }

  int get _unitPrice => _selectedSize.price + _extraPrice;
  int get _totalPrice => _unitPrice * _qty;

  void _onOptionToggled(ModifierGroup group, ModifierOption opt, bool selected) {
    setState(() {
      if (group.isSingleSelect) {
        for (final o in group.options) {
          _selectedOptionIds.remove(o.id);
        }
        if (selected || group.minSelect > 0) {
          _selectedOptionIds.add(opt.id);
        }
      } else {
        if (selected) {
          final currentInGroup = group.options.where((o) => _selectedOptionIds.contains(o.id)).length;
          if (currentInGroup < group.maxSelect) {
            _selectedOptionIds.add(opt.id);
          }
        } else {
          _selectedOptionIds.remove(opt.id);
        }
      }
    });
  }

  Future<void> _submit() async {
    final note = _noteController.text.trim();
    final ok = await widget.controller.addCustomLine(
      sizeId: _selectedSize.id,
      qty: _qty,
      options: _selectedOptionIds.toList(),
      note: note.isEmpty ? null : note,
    );
    if (mounted && ok) {
      Navigator.of(context).pop();
      showNotice(context, 'Đã thêm ${widget.item.name} (${_selectedSize.name}) vào bill');
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.controller.modifiersForItem(widget.item.id);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item.name, style: AppTextStyles.headline),
                    const Text(
                      'Tùy chỉnh topping, đường, đá và ghi chú',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(height: 24),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                if (widget.item.sizes.length > 1) ...[
                  const Text('Chọn kích cỡ', style: AppTextStyles.bodyStrong),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final s in widget.item.sizes)
                        ChoiceChip(
                          label: Text('${s.name} (${formatVnd(s.price)})'),
                          selected: _selectedSize.id == s.id,
                          onSelected: (val) {
                            if (val) setState(() => _selectedSize = s);
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                for (final g in groups) ...[
                  Row(
                    children: [
                      Text(g.name, style: AppTextStyles.bodyStrong),
                      const SizedBox(width: 6),
                      Text(
                        g.isSingleSelect
                            ? '(Chọn 1)'
                            : '(Tối đa ${g.maxSelect})',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opt in g.options)
                        FilterChip(
                          label: Text(
                            opt.priceDelta > 0
                                ? '${opt.name} +${formatVnd(opt.priceDelta)}'
                                : opt.name,
                          ),
                          selected: _selectedOptionIds.contains(opt.id),
                          onSelected: (val) => _onOptionToggled(g, opt, val),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('Ghi chú món', style: AppTextStyles.bodyStrong),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteController,
                  maxLength: 200,
                  decoration: const InputDecoration(
                    hintText: 'Ví dụ: ít ngọt, 30% đá, không lấy thìa...',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Số lượng', style: AppTextStyles.bodyStrong),
                    QtyStepper(
                      value: _qty,
                      max: widget.controller.maxLineQty,
                      onChanged: (val) {
                        if (val > 0) setState(() => _qty = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _submit,
            child: Text('Thêm vào bill · ${formatVnd(_totalPrice)}'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- tab "Bill"
class _LinesTab extends StatelessWidget {
  const _LinesTab({
    super.key,
    required this.controller,
    required this.servingLabel,
    required this.onVoid,
    required this.onDiscount,
    required this.onGoMenu,
  });

  final BillController controller;
  final String servingLabel;
  final void Function(BillLine) onVoid;
  final VoidCallback onDiscount;
  final VoidCallback onGoMenu;

  @override
  Widget build(BuildContext context) {
    final bill = controller.bill!;
    if (bill.lines.isEmpty) {
      return EmptyState(
        icon: ForeIcons.bag,
        title: 'Bill chưa có món',
        message: 'Chọn món ở tab Gọi món rồi bấm Thêm vào bill.',
        actionLabel: bill.isOpen ? 'Gọi món' : null,
        onAction: onGoMenu,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ForeCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < bill.lines.length; i++) ...[
                if (i > 0) const Divider(),
                _LineRow(
                  line: bill.lines[i],
                  canVoid: bill.isOpen && !controller.busy,
                  onVoid: () => onVoid(bill.lines[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        ForeCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _TotalRow('Tạm tính', formatVnd(bill.subtotal)),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Expanded(
                      child: Text('Giảm giá', style: AppTextStyles.body)),
                  if (bill.isOpen)
                    TextButton(
                      onPressed: controller.busy ? null : onDiscount,
                      child: Text(bill.discount > 0 ? 'Sửa' : 'Thêm'),
                    ),
                  Text(
                    bill.discount > 0 ? '-${formatVnd(bill.discount)}' : '0đ',
                    style: AppTextStyles.bodyStrong,
                  ),
                ],
              ),
              if (bill.discount > 0 && (bill.discountReason ?? '').isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Lý do: ${bill.discountReason}',
                      style: AppTextStyles.caption),
                ),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Phải thu (${formatServings(bill.portions, servingLabel)})',
                      style: AppTextStyles.title,
                    ),
                  ),
                  Text(formatVnd(bill.payable), style: AppTextStyles.number),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: AppTextStyles.bodyStrong),
        ],
      );
}

class _LineRow extends StatelessWidget {
  const _LineRow(
      {required this.line, required this.canVoid, required this.onVoid});

  final BillLine line;
  final bool canVoid;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final voided = line.voided;
    final strike = voided ? TextDecoration.lineThrough : TextDecoration.none;
    final color = voided ? AppColors.textMuted : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${line.qty}×',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                  decoration: strike),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.itemName,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color,
                      decoration: strike),
                ),
                Text(
                  '${line.sizeName} · ${formatVnd(line.unitPrice)}${voided ? ' · Đã bỏ' : ''}',
                  style: AppTextStyles.caption,
                ),
                if (line.modifiers.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      line.modifiers
                          .map((m) => m.priceDelta > 0
                              ? '+ ${m.name} (+${formatVnd(m.priceDelta)})'
                              : '+ ${m.name}')
                          .join('\n'),
                      style: TextStyle(
                        fontSize: 12,
                        color: voided ? AppColors.textMuted : AppColors.brand,
                        fontWeight: FontWeight.w500,
                        decoration: strike,
                      ),
                    ),
                  ),
                if (line.note != null && line.note!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      'Ghi chú: ${line.note}',
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: voided ? AppColors.textMuted : AppColors.ink,
                        decoration: strike,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatVnd(line.total),
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: color,
                    decoration: strike),
              ),
              if (canVoid && !voided)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onVoid,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Bỏ',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusOff),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- thanh toán
class _PayResult {
  const _PayResult({
    required this.method,
    this.tendered,
    this.ref,
    this.change = 0,
  });

  final PaymentMethod method;
  final int? tendered;
  final String? ref;
  final int change;
}

class _PayForm extends StatefulWidget {
  const _PayForm({
    required this.amount,
    required this.billNo,
    required this.qrInfo,
  });

  final int amount;
  final int billNo;
  final PaymentQrInfo qrInfo;

  @override
  State<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends State<_PayForm> {
  PaymentMethod _method = PaymentMethod.cash;
  late final TextEditingController _tenderedController;
  final TextEditingController _refController = TextEditingController();
  int? _tendered;

  @override
  void initState() {
    super.initState();
    _tendered = widget.amount;
    _tenderedController = TextEditingController(
      text: formatVnd(widget.amount).replaceAll('đ', '').trim(),
    );
  }

  @override
  void dispose() {
    _tenderedController.dispose();
    _refController.dispose();
    super.dispose();
  }

  int get _change => (_tendered != null && _tendered! >= widget.amount)
      ? _tendered! - widget.amount
      : 0;

  bool get _canSubmit {
    if (_method == PaymentMethod.cash) {
      return _tendered != null && _tendered! >= widget.amount;
    }
    return true;
  }

  void _quickTender(int val) {
    setState(() {
      _tendered = val;
      _tenderedController.text = formatVnd(val).replaceAll('đ', '').trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final qrUrl = widget.qrInfo.makeQrUrl(
      billNo: widget.billNo,
      amount: widget.amount,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Text(
            formatVnd(widget.amount),
            style: AppTextStyles.numberXL,
          ),
        ),
        const SizedBox(height: 4),
        const Center(
          child: Text('Số tiền phải thu', style: AppTextStyles.caption),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            for (final m in PaymentMethod.values)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: m == PaymentMethod.values.last ? 0 : 10,
                  ),
                  child: _MethodTile(
                    label: m.label,
                    selected: m == _method,
                    onTap: () => setState(() => _method = m),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_method == PaymentMethod.cash) ...[
          MoneyField(
            controller: _tenderedController,
            label: 'Tiền khách đưa',
            errorText: (_tendered != null && _tendered! < widget.amount)
                ? 'Tiền khách đưa chưa đủ'
                : null,
            onChanged: (val) => setState(() => _tendered = val),
          ),
          const SizedBox(height: 8),
          // Các phím chọn nhanh mệnh giá
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                label: const Text('Đúng số tiền'),
                onPressed: () => _quickTender(widget.amount),
              ),
              if (widget.amount < 50000)
                ActionChip(
                  label: const Text('50.000đ'),
                  onPressed: () => _quickTender(50000),
                ),
              if (widget.amount < 100000)
                ActionChip(
                  label: const Text('100.000đ'),
                  onPressed: () => _quickTender(100000),
                ),
              if (widget.amount < 200000)
                ActionChip(
                  label: const Text('200.000đ'),
                  onPressed: () => _quickTender(200000),
                ),
              if (widget.amount < 500000)
                ActionChip(
                  label: const Text('500.000đ'),
                  onPressed: () => _quickTender(500000),
                ),
            ],
          ),
          if (_change > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.statusHealthyTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tiền thối lại cho khách:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.statusHealthy,
                    ),
                  ),
                  Text(
                    formatVnd(_change),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.statusHealthy,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ] else ...[
          // Phương thức Chuyển khoản
          if (qrUrl != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      qrUrl,
                      height: 180,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Không tải được mã QR. Xem thông tin STK bên dưới.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.qrInfo.bankCode} · ${widget.qrInfo.accountNo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    widget.qrInfo.accountName ?? '',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    'Nội dung: ${widget.qrInfo.contentPrefix} BILL${widget.billNo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandAccent,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: _refController,
            decoration: const InputDecoration(
              labelText: 'Mã chuẩn chi / 4 số cuối (tùy chọn)',
              hintText: 'Ví dụ: 1234 hoặc mã giao dịch',
            ),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.of(context).pop(
                    _PayResult(
                      method: _method,
                      tendered: _method == PaymentMethod.cash ? _tendered : null,
                      ref: _method == PaymentMethod.transfer
                          ? _refController.text.trim()
                          : null,
                      change: _change,
                    ),
                  )
              : null,
          child: Text('Thu ${formatVnd(widget.amount)}'),
        ),
        const SizedBox(height: 4),
        const Text(
          'Thanh toán xong không sửa được. Muốn hủy phải có chủ quán xác nhận bằng PIN.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: ExcludeSemantics(
          child: PressableScale(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected ? AppColors.ink : AppColors.border,
                    width: 1.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- giảm giá
class _DiscountResult {
  const _DiscountResult(this.amount, this.reason);

  final int amount;
  final String reason;
}

class _DiscountForm extends StatefulWidget {
  const _DiscountForm({required this.current, required this.max});

  final int current;
  final int max;

  @override
  State<_DiscountForm> createState() => _DiscountFormState();
}

class _DiscountFormState extends State<_DiscountForm> {
  late final TextEditingController _amount = TextEditingController(
    text:
        widget.current > 0 ? formatVnd(widget.current).replaceAll('đ', '') : '',
  );
  final _reason = TextEditingController();
  late int? _value = widget.current > 0 ? widget.current : null;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _tooMuch => (_value ?? 0) > widget.max;
  bool get _valid =>
      _value != null &&
      _value! > 0 &&
      !_tooMuch &&
      _reason.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyField(
            controller: _amount,
            label: 'Số tiền giảm',
            autofocus: true,
            errorText: _tooMuch ? 'Không được lớn hơn tổng tiền' : null,
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Lý do (bắt buộc)',
              hintText: 'Ví dụ: khách quen',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _valid
                ? () => Navigator.of(context)
                    .pop(_DiscountResult(_value!, _reason.text.trim()))
                : null,
            child: const Text('Áp dụng giảm giá'),
          ),
          if (widget.current > 0) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(const _DiscountResult(0, '')),
              child: const Text('Bỏ giảm giá'),
            ),
          ],
        ],
      );
}
