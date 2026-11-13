import 'package:flutter/material.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/screen_header.dart';
import '../application/purchase_controller.dart';
import '../domain/inventory_repository.dart';
import 'inventory_widgets.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// Phiếu nhập hàng. Không hiện lịch sử nhập hay số tồn (chỉ chủ xem). Nhập nhầm thì nhờ chủ sửa.
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  late final PurchaseController _c = PurchaseController(widget.repository)
    ..load();
  final _qty = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await guarded(context, _c.submit);
    if (ok == true && mounted) {
      _qty.clear();
      _note.clear();
      showNotice(context, 'Đã lưu phiếu nhập hàng.');
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
                  title: 'Nhập hàng',
                  subtitle: 'Ghi nguyên liệu vừa nhập về trong ca.'),
              Expanded(child: _body()),
            ],
          ),
        ),
      );

  Widget _body() {
    if (_c.phase == LoadPhase.loading && _c.ingredients.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_c.phase == LoadPhase.error) {
      return ErrorRetry(
          message: _c.failure?.userMessage ?? 'Không tải được danh sách.',
          onRetry: _c.load);
    }
    return LazyListView(
      padding: const EdgeInsets.all(16),
      children: [
        IngredientField(
            options: _c.ingredients, value: _c.selected, onChanged: _c.select),
        const SizedBox(height: 14),
        QuantityField(
          controller: _qty,
          ingredient: _c.selected,
          unit: _c.unitChoice,
          onUnitChanged: _c.setUnit,
          onChanged: _c.setQuantityText,
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _c.late,
          onChanged: _c.setLate,
          title: const Text('Nhập muộn',
              style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle:
              const Text('Bật nếu hàng đã về từ trước nhưng bây giờ mới ghi.'),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _note,
          onChanged: _c.setNote,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
              labelText: 'Ghi chú (không bắt buộc)', counterText: ''),
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _c.canSubmit ? _save : null,
          child: const Text('Lưu phiếu nhập'),
        ),
      ],
    );
  }
}
