import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fore_segmented.dart';
import '../../../core/widgets/money_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/screen_header.dart';
import '../application/cash_controller.dart';
import '../domain/inventory_repository.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// Thu / chi tiền mặt ngoài bán hàng (mua đá, chủ rút tiền...). Chi ra bắt buộc ghi chú. Không cần PIN.
class CashScreen extends StatefulWidget {
  const CashScreen({super.key, required this.repository});

  final CashRepository repository;

  @override
  State<CashScreen> createState() => _CashScreenState();
}

class _CashScreenState extends State<CashScreen> {
  late final CashController _c = CashController(widget.repository);
  final _amount = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await guarded(context, _c.submit);
    if (ok == true && mounted) {
      _amount.clear();
      _note.clear();
      showNotice(context, 'Đã ghi khoản tiền mặt.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: ListenableBuilder(
          listenable: _c,
          builder: (context, _) => Column(
            children: [
              const ScreenHeader(
                  title: 'Thu / chi tiền mặt',
                  subtitle:
                      'Khoản tiền bỏ thêm vào két hoặc lấy ra ngoài bán hàng.'),
              Expanded(
                child: LazyListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ForeSegmented(
                      labels: const ['Chi ra', 'Thu vào'],
                      selected: _c.incoming ? 1 : 0,
                      onChanged: (i) => _c.setIncoming(i == 1),
                    ),
                    const SizedBox(height: 18),
                    MoneyField(
                      controller: _amount,
                      label: 'Số tiền',
                      large: true,
                      onChanged: _c.setAmount,
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _note,
                      onChanged: _c.setNote,
                      maxLength: 200,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: _c.incoming
                            ? 'Ghi chú (không bắt buộc)'
                            : 'Ghi chú (bắt buộc, từ ${CashController.minNoteLength} ký tự)',
                        hintText: _c.incoming ? null : 'Ví dụ: mua đá',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _c.canSubmit ? _save : null,
                      child:
                          Text(_c.incoming ? 'Ghi khoản thu' : 'Ghi khoản chi'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
