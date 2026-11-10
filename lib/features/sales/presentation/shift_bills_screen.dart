import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/ops_icon.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';
import 'bill_screen.dart';

/// Màn hình lịch sử hóa đơn trong ca làm việc hiện tại
class ShiftBillsScreen extends StatefulWidget {
  const ShiftBillsScreen({
    super.key,
    required this.repository,
    required this.servingLabel,
  });

  final SalesRepository repository;
  final String servingLabel;

  @override
  State<ShiftBillsScreen> createState() => _ShiftBillsScreenState();
}

class _ShiftBillsScreenState extends State<ShiftBillsScreen> {
  List<ShiftBillSummary> _bills = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.repository.shiftBills();
      if (!mounted) return;
      setState(() {
        _bills = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Không tải được danh sách hóa đơn trong ca.';
        _loading = false;
      });
    }
  }

  void _openDetail(ShiftBillSummary bill) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BillScreen(
          repository: widget.repository,
          billId: bill.billId,
          servingLabel: widget.servingLabel,
        ),
      ),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hóa đơn trong ca', style: AppTextStyles.title),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: AppTextStyles.body),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _load,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (_bills.isEmpty) {
      return const EmptyState(
        icon: ForeIcons.bag,
        title: 'Chưa có hóa đơn nào',
        message: 'Các hóa đơn được mở trong ca hiện tại sẽ hiển thị tại đây.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _bills.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final bill = _bills[index];
          return _BillItemCard(
            bill: bill,
            servingLabel: widget.servingLabel,
            onTap: () => _openDetail(bill),
          );
        },
      ),
    );
  }
}

class _BillItemCard extends StatelessWidget {
  const _BillItemCard({
    required this.bill,
    required this.servingLabel,
    required this.onTap,
  });

  final ShiftBillSummary bill;
  final String servingLabel;
  final VoidCallback onTap;

  Color get _statusColor => switch (bill.status) {
        BillStatus.open => AppColors.warning,
        BillStatus.paid => AppColors.statusHealthy,
        BillStatus.cancelled => AppColors.statusCritical,
      };

  String get _statusLabel => switch (bill.status) {
        BillStatus.open => 'Đang mở',
        BillStatus.paid => 'Đã thu tiền',
        BillStatus.cancelled => 'Đã hủy',
      };

  @override
  Widget build(BuildContext context) {
    return ForeCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                bill.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.brand,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${formatServings(bill.portions, servingLabel)} · Mở lúc ${formatHm(bill.openedAt)}',
                style: AppTextStyles.caption,
              ),
              if (bill.totalAmount != null)
                Text(
                  formatVnd(bill.totalAmount!),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.brand,
                  ),
                ),
            ],
          ),
          if (bill.paymentMethod != null || (bill.paymentRef ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${bill.paymentMethod == 'cash' ? 'Tiền mặt' : 'Chuyển khoản'}${bill.paymentRef != null ? ' (Mã: ${bill.paymentRef})' : ''}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (bill.cancelReason != null) ...[
            const SizedBox(height: 6),
            Text(
              'Lý do hủy: ${bill.cancelReason}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.statusCritical,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
