import 'package:flutter/material.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/fore_sheet.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/ops_icon.dart';
import '../../../core/widgets/screen_header.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';

/// Bill đã thu trong ca đang mở. Thu nhầm thì hủy: cần lý do và chủ quán nhập PIN trên máy này.
class PaidBillsScreen extends StatefulWidget {
  const PaidBillsScreen({super.key, required this.repository});

  final SalesRepository repository;

  @override
  State<PaidBillsScreen> createState() => _PaidBillsScreenState();
}

class _PaidBillsScreenState extends State<PaidBillsScreen> {
  List<PaidBill>? _bills;
  AppFailure? _failure;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bills = await widget.repository.paidBills();
      if (mounted) {
        setState(() {
          _bills = bills;
          _failure = null;
        });
      }
    } on AppFailure catch (f) {
      if (mounted) setState(() => _failure = f);
    }
  }

  Future<void> _cancel(PaidBill bill) async {
    final reason = await askReason(
      context,
      title: 'Hủy bill #${bill.billNo}',
      subtitle:
          'Đã thu ${formatVnd(bill.total)}. Hủy bill cần lý do và PIN của chủ quán.',
      hint: 'Ví dụ: thu nhầm bàn',
      confirmLabel: 'Tiếp tục',
      destructive: true,
    );
    if (reason == null || !mounted) return;
    final pin = await askPin(context,
        title: 'PIN chủ quán',
        subtitle: 'Chủ quán nhập PIN để duyệt hủy bill.',
        confirmLabel: 'Hủy bill');
    if (pin == null || !mounted) return;
    final result = await guarded(context,
        () => widget.repository.cancelPaidBill(bill.billId, pin, reason));
    if (result == null || !mounted) return;
    showNotice(
        context,
        switch (result) {
          'OK' => 'Đã hủy bill #${bill.billNo}.',
          'WRONG_PIN' => 'Sai PIN chủ quán.',
          'PIN_LOCKED' => 'Nhập sai PIN quá nhiều lần. Thử lại sau ít phút.',
          _ => 'Không hủy được bill.',
        });
    if (result == 'OK') _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const ScreenHeader(
                title: 'Bill đã thu',
                subtitle: 'Trong ca đang mở, mới nhất ở trên.'),
            Expanded(child: _body()),
          ],
        ),
      );

  Widget _body() {
    final bills = _bills;
    if (_failure != null && bills == null) {
      return ErrorRetry(message: _failure!.userMessage, onRetry: _load);
    }
    if (bills == null) return const Center(child: CircularProgressIndicator());
    if (bills.isEmpty) {
      return const EmptyState(
          icon: ForeIcons.bag,
          title: 'Chưa có bill nào',
          message: 'Bill đã thu trong ca sẽ hiện ở đây.');
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final b = bills[i];
          return ForeCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#${b.billNo} · ${b.tableName ?? 'Mang đi'}',
                          style: AppTextStyles.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                          '${formatHm(b.paidAt)} · ${b.method == 'cash' ? 'Tiền mặt' : 'Chuyển khoản'} · ${formatVnd(b.total)}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                TextButton(
                    onPressed: () => _cancel(b), child: const Text('Hủy bill')),
              ],
            ),
          );
        },
      ),
    );
  }
}
