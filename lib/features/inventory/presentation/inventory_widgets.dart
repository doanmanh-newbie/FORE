import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/text.dart';
import '../../../core/widgets/fore_sheet.dart';
import '../domain/inventory_models.dart';

/// Ô chọn nguyên liệu: chạm để mở danh sách có tìm kiếm (bỏ dấu).
class IngredientField extends StatelessWidget {
  const IngredientField(
      {super.key,
      required this.options,
      required this.value,
      required this.onChanged});

  final List<IngredientOption> options;
  final IngredientOption? value;
  final ValueChanged<IngredientOption> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showForeSheet<IngredientOption>(
      context,
      title: 'Chọn nguyên liệu',
      builder: (_) => _PickerList(options: options),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(context),
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Nguyên liệu',
            suffixIcon: Icon(Icons.expand_more_rounded),
          ),
          child: Text(
            value == null
                ? 'Chạm để chọn'
                : '${value!.name} (${value!.unitLabel})',
            style: TextStyle(
              fontSize: AppFontSizes.s16,
              color: value == null ? AppColors.textMuted : AppColors.ink,
              fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
            ),
          ),
        ),
      );
}

class _PickerList extends StatefulWidget {
  const _PickerList({required this.options});

  final List<IngredientOption> options;

  @override
  State<_PickerList> createState() => _PickerListState();
}

class _PickerListState extends State<_PickerList> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = foldVietnamese(_q.trim());
    final shown = [
      for (final o in widget.options)
        if (q.isEmpty || foldVietnamese(o.name).contains(q)) o
    ];
    return Column(
      children: [
        TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          decoration: const InputDecoration(
            hintText: 'Tìm nguyên liệu',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.45,
          child: shown.isEmpty
              ? Center(
                  child: Text('Không có nguyên liệu nào khớp.',
                      style: AppTextStyles.body))
              : ListView.separated(
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final o = shown[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        o.name,
                        style: TextStyle(
                            fontWeight: o.important
                                ? FontWeight.w700
                                : FontWeight.w500),
                      ),
                      subtitle: Text(o.unitLabel, style: AppTextStyles.caption),
                      onTap: () => Navigator.of(context).pop(o),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Ô nhập số lượng, đổi được đơn vị (ml / lít, g / kg) và hiện luôn số quy ra đơn vị gốc.
class QuantityField extends StatelessWidget {
  const QuantityField({
    super.key,
    required this.controller,
    required this.ingredient,
    required this.unit,
    required this.onUnitChanged,
    required this.onChanged,
    this.label = 'Số lượng',
  });

  final TextEditingController controller;
  final IngredientOption? ingredient;
  final UnitChoice? unit;
  final ValueChanged<UnitChoice> onUnitChanged;
  final ValueChanged<String> onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final choices = ingredient == null
        ? const <UnitChoice>[]
        : unitChoices(ingredient!.unit);
    final base = unit == null ? null : quantityInBase(controller.text, unit!);
    final bad = controller.text.trim().isNotEmpty && base == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: ingredient != null,
          onChanged: onChanged,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: AppTextStyles.number,
          decoration: InputDecoration(
            labelText: label,
            hintText: '0',
            errorText: bad
                ? 'Nhập số nguyên theo ${ingredient?.unitLabel ?? 'đơn vị gốc'}'
                : null,
            helperText: base != null && unit != null && unit!.factor != 1
                ? '= $base ${ingredient!.unitLabel}'
                : null,
          ),
        ),
        if (choices.length > 1) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              for (final c in choices)
                ChoiceChip(
                  label: Text(c.label),
                  selected: unit?.label == c.label,
                  onSelected: (_) => onUnitChanged(c),
                  selectedColor: AppColors.ink,
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color:
                        unit?.label == c.label ? AppColors.onInk : AppColors.ink,
                  ),
                  showCheckmark: false,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
