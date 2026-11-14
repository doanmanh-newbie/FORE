import 'package:flutter/material.dart';

import '../../../../core/format.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/fore_card.dart';
import '../../../../core/widgets/ops_icon.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/notify.dart';
import '../application/ops_shift_controller.dart';
import '../../../../core/widgets/lazy_list_view.dart';

/// Tab "Đóng ca" (thiết kế "Đóng ca"): nhập tiền đếm được trong két, xem các việc còn thiếu, xác nhận.
///
/// ĐẾM MÙ TIỀN MẶT: màn này KHÔNG hiện số tiền đáng ra có trong két, kết quả đối soát hay doanh thu.
/// Sau khi đóng chỉ hiện "Đã đóng ca".
class CloseShiftView extends StatefulWidget {
  const CloseShiftView({
    super.key,
    required this.shift,
    required this.onViewBills,
    required this.onCountStock,
  });

  final OpsShiftController shift;

  /// Đi tới nơi xử lý bill đang mở (tab Mang đi / Trang chủ).
  final VoidCallback onViewBills;

  /// Mở phiếu kiểm kê cuối ca.
  final VoidCallback onCountStock;

  @override
  State<CloseShiftView> createState() => _CloseShiftViewState();
}

class _CloseShiftViewState extends State<CloseShiftView> {
  final _cash = TextEditingController();
  int? _value;

  @override
  void initState() {
    super.initState();
    widget.shift.loadCloseStatus();
  }

  @override
  void dispose() {
    _cash.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final amount = _value;
    if (amount == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đóng ca?'),
        content: Text(
          'Bạn đã đếm ${formatVnd(amount)} trong két. Sau khi đóng ca, số liệu của ca này '
          'không sửa được. Chủ quán sẽ xem kết quả đối soát.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Kiểm tra lại')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Đóng ca')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final closed =
        await guarded(context, () => widget.shift.closeShift(amount));
    if (closed == true && mounted) showNotice(context, 'Đã đóng ca.');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.shift,
        builder: (context, _) {
          final status = widget.shift.closeStatus;
          final ready = status?.ready ?? false;
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: widget.shift.loadCloseStatus,
                  child: LazyListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                    children: [
                      Text('KẾT THÚC CA LÀM VIỆC',
                          style: AppTextStyles.captionStrong),
                      const SizedBox(height: 6),
                      Text('Đóng ca', style: AppTextStyles.display),
                      const SizedBox(height: 8),
                      Text(
                        'Đếm tiền mặt thực tế trong két trước khi xác nhận.',
                        style: TextStyle(
                            fontSize: AppFontSizes.s15,
                            color: AppColors.textPrimary,
                            height: 1.4),
                      ),
                      const SizedBox(height: 22),
                      ForeCard(
                        radius: 24,
                        padding: const EdgeInsets.all(18),
                        child: MoneyField(
                          controller: _cash,
                          label: 'Tiền đếm được',
                          large: true,
                          helper: 'Nhập số tiền thực tế bạn vừa đếm trong két.',
                          onChanged: (v) => setState(() => _value = v),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text('Trước khi đóng ca', style: AppTextStyles.headline),
                      const SizedBox(height: 12),
                      _CheckCard(
                        loading: status == null,
                        ok: status?.openBills == 0,
                        okTitle: 'Không còn bill đang mở',
                        okText: 'Tất cả bill đã được thanh toán hoặc hủy.',
                        pendingTitle:
                            'Còn ${status?.openBills ?? 0} bill đang mở',
                        pendingText:
                            'Thanh toán hoặc hủy hết rồi mới đóng ca được.',
                        actionLabel: 'Xem bill',
                        onAction: widget.onViewBills,
                      ),
                      const SizedBox(height: 12),
                      _CheckCard(
                        loading: status == null,
                        ok: status?.missingCounts == 0,
                        okTitle: 'Đã đếm đủ nguyên liệu cuối ca',
                        okText: 'Kiểm kê cuối ca đã hoàn tất.',
                        pendingTitle:
                            'Còn ${status?.missingCounts ?? 0} nguyên liệu chưa đếm',
                        pendingText:
                            'Đo và nhập số thực tế của từng nguyên liệu.',
                        actionLabel: 'Đếm ngay',
                        onAction: widget.onCountStock,
                      ),
                    ],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.cardBorder)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: FilledButton(
                    onPressed: ready && _value != null && !widget.shift.busy
                        ? _confirm
                        : null,
                    child: Text(
                      !ready
                          ? 'Hoàn tất các việc ở trên để đóng ca'
                          : _value == null
                              ? 'Nhập tiền đếm được'
                              : 'Xác nhận đóng ca',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
}

class _CheckCard extends StatelessWidget {
  const _CheckCard({
    required this.loading,
    required this.ok,
    required this.okTitle,
    required this.okText,
    required this.pendingTitle,
    required this.pendingText,
    required this.actionLabel,
    required this.onAction,
  });

  final bool loading;
  final bool ok;
  final String okTitle;
  final String okText;
  final String pendingTitle;
  final String pendingText;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final String title =
        loading ? 'Đang kiểm tra...' : (ok ? okTitle : pendingTitle);
    final String text = loading ? 'Chờ một chút.' : (ok ? okText : pendingText);
    return ForeCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: loading
                  ? AppColors.surfaceTint
                  : ok
                      ? AppColors.statusOkTint
                      : AppColors.statusWatchTint,
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : ForeIcon(
                        ok ? ForeIcons.check : ForeIcons.warning,
                        size: 20,
                        color: ok ? AppColors.statusOk : AppColors.statusWatch,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.bodyStrong),
                const SizedBox(height: 2),
                Text(text, style: AppTextStyles.caption),
              ],
            ),
          ),
          if (!loading && !ok)
            TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
