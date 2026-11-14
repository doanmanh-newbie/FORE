import 'package:flutter/material.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/screen_header.dart';
import '../application/waste_controller.dart';
import '../domain/inventory_repository.dart';
import 'inventory_widgets.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// Ghi hao hụt có lý do (đổ bỏ, làm sai, cho nhân viên, thử vị...) để đối soát không tính nhầm.
/// Loại hao hụt lấy từ database, không gõ tự do.
class WasteScreen extends StatefulWidget {
  const WasteScreen({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<WasteScreen> createState() => _WasteScreenState();
}

class _WasteScreenState extends State<WasteScreen> {
  late final WasteController _c = WasteController(widget.repository)..load();
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
      showNotice(context, 'Đã ghi hao hụt.');
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
                  title: 'Ghi hao hụt',
                  subtitle: 'Nguyên liệu bị mất có lý do.'),
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
            options: _c.ingredients,
            value: _c.ingredient,
            onChanged: _c.selectIngredient),
        const SizedBox(height: 14),
        QuantityField(
          controller: _qty,
          ingredient: _c.ingredient,
          unit: _c.unitChoice,
          onUnitChanged: _c.setUnit,
          onChanged: _c.setQuantityText,
        ),
        const SizedBox(height: 18),
        Text('Lý do', style: AppTextStyles.bodyStrong),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _c.types)
              ChoiceChip(
                label: Text(t.label),
                selected: _c.type?.code == t.code,
                onSelected: (_) => _c.selectType(t),
                selectedColor: AppColors.ink,
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _c.type?.code == t.code ? AppColors.onInk : AppColors.ink,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _note,
          onChanged: _c.setNote,
          maxLength: 200,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: _c.noteRequired
                ? 'Ghi chú (bắt buộc, từ ${WasteController.minNoteLength} ký tự)'
                : 'Ghi chú (không bắt buộc)',
            counterText: '',
            errorText: _c.noteRequired && _note.text.isNotEmpty && !_c.noteOk
                ? 'Ghi chú còn quá ngắn'
                : null,
          ),
        ),
        const SizedBox(height: 18),
        FilledButton(
            onPressed: _c.canSubmit ? _save : null,
            child: const Text('Lưu hao hụt')),
      ],
    );
  }
}
