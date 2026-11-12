import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/design/app_sheet.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/widgets/notify.dart';
import '../../auth/application/session_controller.dart';
import '../../shift/application/shift_controller.dart';
import '../application/async_data.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';

/// "Đổi quán đang xem": mỗi quán một thẻ với giá trị tồn và hao hụt 7 ngày để chủ so nhanh,
/// rồi chọn quán muốn chuyển sang. Việc đổi quán dùng đúng luồng của bộ chuyển quán chung.
Future<void> showShopCompareSheet(BuildContext context) =>
    AppSheet.show<void>(context, builder: (_) => const _ShopCompareSheet());

class _ShopCompareSheet extends StatefulWidget {
  const _ShopCompareSheet();

  @override
  State<_ShopCompareSheet> createState() => _ShopCompareSheetState();
}

class _ShopCompareSheetState extends State<_ShopCompareSheet> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<List<ShopSnapshot>> _data =
      AsyncData(_repo.shopSnapshots)..load();
  String? _switching;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _choose(ShopSnapshot s) async {
    if (s.isCurrent || _switching != null) return;
    final session = context.read<SessionController>();
    final shift = context.read<ShiftController>();
    final navigator = Navigator.of(context);
    setState(() => _switching = s.shopId);
    try {
      final failure = await session.chooseShop(s.shopId);
      if (failure != null) throw failure;
      shift.load();
      if (!mounted) return;
      navigator.pop();
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on AppFailure catch (f) {
      if (!mounted) return;
      setState(() => _switching = null);
      showFailure(context, f);
    }
  }

  @override
  Widget build(BuildContext context) => AppSheet(
        title: 'Đổi quán đang xem',
        child: ListenableBuilder(
          listenable: _data,
          builder: (context, _) {
            final shops = _data.data;
            if (shops == null) {
              return _data.failure != null
                  ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_data.failure!.userMessage))
                  : const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()));
            }
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                      'Số liệu kho từng quán. Mỗi quán có kho, giá và nhà cung cấp riêng.',
                      style: AppTextStyles.caption),
                ),
              ),
              for (final s in shops)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: KhoCard(
                    onTap: () => _choose(s),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.shopName, style: AppTextStyles.cardTitle),
                            const SizedBox(height: 2),
                            Text('Giá trị tồn ${formatVnd(s.stockValue)}',
                                style: AppTextStyles.caption),
                            Text('Hao hụt 7 ngày ${formatVnd(s.waste7d)}',
                                style: AppTextStyles.caption),
                          ],
                        ),
                      ),
                      if (_switching == s.shopId)
                        const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                      else if (s.isCurrent)
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.statusHealthy)
                      else
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                    ]),
                  ),
                ),
            ]);
          },
        ),
      );
}
