import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/fore_card.dart';
import '../../../../core/widgets/ops_icon.dart';
import '../../../../core/widgets/money_field.dart';
import '../../../../core/widgets/fore_sheet.dart';
import '../../../../core/widgets/notify.dart';
import '../../../../core/format.dart';
import '../application/ops_shift_controller.dart';
import '../../../../core/widgets/lazy_list_view.dart';

/// Màn "Chưa mở ca" (thiết kế "Home / No-shift"): thẻ giữa màn kèm nút Mở ca.
/// Bấm Mở ca thì hỏi số tiền có trong két lúc bắt đầu.
class NoShiftView extends StatelessWidget {
  const NoShiftView({
    super.key,
    required this.shift,
    required this.onCountOpening,
  });

  final OpsShiftController shift;
  final VoidCallback onCountOpening;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
        onRefresh: shift.load,
        child: LazyListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          children: [
            ForeCard(
              padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
              child: Column(
                children: [
                  ForeIcon(ForeIcons.calendar,
                      size: 34, color: AppColors.ink),
                  const SizedBox(height: 28),
                  Text(
                    'Chưa có ca đang mở',
                    style: AppTextStyles.headline,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Mở ca để nhận order và dùng các chức năng bán hàng.',
                    style: TextStyle(
                        fontSize: AppFontSizes.s16,
                        color: AppColors.textPrimary,
                        height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 56),
                  FilledButton(
                    onPressed:
                        shift.busy ? null : () => _askOpeningCash(context),
                    child: const Text('Mở ca'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Bàn, Mang đi và Kho dùng được sau khi mở ca.',
              style: TextStyle(
                  fontSize: AppFontSizes.s14, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

  Future<void> _askOpeningCash(BuildContext context) async {
    final navigator = Navigator.of(context);
    final cash = await showForeSheet<int>(
      context,
      title: 'Mở ca',
      subtitle: 'Nhập số tiền có trong két lúc bắt đầu ca.',
      builder: (_) => const _OpeningCashForm(),
    );
    if (cash == null || !navigator.mounted) return;
    try {
      final opened = await shift.openShift(cash);
      if (opened && navigator.mounted) {
        final countNow = await showDialog<bool>(
          context: navigator.context,
          builder: (ctx) => AlertDialog(
            title: const Text('Kiểm kê đầu ca'),
            content: const Text(
                'Đếm nguyên liệu thực tế trước khi bắt đầu bán. Số dự kiến sẽ không hiển thị.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Đếm ngay'),
              ),
            ],
          ),
        );
        if (countNow == true && navigator.mounted) onCountOpening();
        if (navigator.mounted) {
          showNotice(
              navigator.context, 'Đã mở ca. Chúc ca làm việc thuận lợi!');
        }
      }
    } on AppFailure catch (f) {
      if (navigator.mounted) showFailure(navigator.context, f);
    }
  }
}

class _OpeningCashForm extends StatefulWidget {
  const _OpeningCashForm();

  @override
  State<_OpeningCashForm> createState() => _OpeningCashFormState();
}

class _OpeningCashFormState extends State<_OpeningCashForm> {
  final _controller = TextEditingController();
  int? _value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyField(
            controller: _controller,
            label: 'Tiền đầu ca',
            large: true,
            autofocus: true,
            helper:
                _value == null ? 'Nhập 0 nếu két trống.' : formatVnd(_value!),
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed:
                _value == null ? null : () => Navigator.of(context).pop(_value),
            child: const Text('Mở ca'),
          ),
        ],
      );
}
