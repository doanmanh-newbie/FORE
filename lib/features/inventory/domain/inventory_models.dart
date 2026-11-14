import '../../../core/data/json_row.dart';

class IngredientOption {
  const IngredientOption({
    required this.id,
    required this.name,
    required this.unit,
    required this.important,
    required this.group,
  });

  factory IngredientOption.fromRow(Map<String, dynamic> row) =>
      IngredientOption(
        id: row.str('ingredient_id'),
        name: row.str('name'),
        unit: row.str('unit'),
        important: row.str('importance') == 'important',
        group: row.strOrNull('group_name'),
      );

  final String id;
  final String name;

  /// Đơn vị gốc: `ml`, `g` hoặc `piece`.
  final String unit;
  final bool important;
  final String? group;

  String get unitLabel => switch (unit) {
        'piece' => 'cái',
        final u => u,
      };
}

class WasteTypeOption {
  const WasteTypeOption(
      {required this.code, required this.label, required this.requiresNote});

  factory WasteTypeOption.fromRow(Map<String, dynamic> row) => WasteTypeOption(
        code: row.str('code'),
        label: row.str('label_vi'),
        requiresNote: row.flag('requires_note'),
      );

  final String code;
  final String label;
  final bool requiresNote;
}

/// Một cách nhập số lượng: nhập theo lít / kg thì nhân hệ số để ra đơn vị gốc (ml, g).
class UnitChoice {
  const UnitChoice(this.label, this.factor);

  final String label;
  final int factor;
}

List<UnitChoice> unitChoices(String baseUnit) => switch (baseUnit) {
      'ml' => const [UnitChoice('ml', 1), UnitChoice('lít', 1000)],
      'g' => const [UnitChoice('g', 1), UnitChoice('kg', 1000)],
      _ => const [UnitChoice('cái', 1)],
    };

/// Đổi số người dùng gõ ("1,5", "2.5", "500") thành số nguyên theo đơn vị gốc.
/// Trả `null` nếu không hợp lệ, bằng 0, hoặc không ra số nguyên (vd 0,0004 lít = 0,4 ml).
int? quantityInBase(String text, UnitChoice choice) {
  final cleaned = text.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final value = double.tryParse(cleaned);
  if (value == null || value.isNaN || value.isInfinite || value <= 0) {
    return null;
  }
  final base = value * choice.factor;
  final rounded = base.round();
  if ((base - rounded).abs() > 1e-6) {
    return null; // không ra số nguyên: không đoán
  }
  if (rounded <= 0 || rounded > 1000000000) return null;
  return rounded;
}
