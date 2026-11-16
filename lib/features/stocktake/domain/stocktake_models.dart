import '../../../core/data/json_row.dart';

enum CountKind {
  open('open', 'Đầu ca'),
  close('close', 'Cuối ca');

  const CountKind(this.wire, this.label);

  final String wire;
  final String label;
}

/// Một dòng của phiếu kiểm kê. ĐẾM MÙ: không có số dự kiến, số tồn hay số đã nhập,
/// chỉ có cờ `counted` (đã đếm hay chưa).
class CountItem {
  const CountItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.important,
    required this.weekly,
    required this.group,
    required this.counted,
  });

  factory CountItem.fromRow(Map<String, dynamic> row) => CountItem(
        id: row.str('ingredient_id'),
        name: row.str('name'),
        unit: row.str('unit'),
        important: row.str('importance') == 'important',
        weekly: row.flag('weekly_check'),
        group: row.strOrNull('group_name'),
        counted: row.flag('counted'),
      );

  final String id;
  final String name;
  final String unit;
  final bool important;

  /// Nguyên liệu chỉ kiểm theo tuần: không bắt buộc đếm lúc cuối ca.
  final bool weekly;
  final String? group;
  final bool counted;

  /// Đơn vị hiển thị: `piece` là "cái"; `ml`, `g` giữ nguyên.
  String get unitLabel => unit == 'piece' ? 'cái' : unit;

  CountItem markCounted() => CountItem(
        id: id,
        name: name,
        unit: unit,
        important: important,
        weekly: weekly,
        group: group,
        counted: true,
      );
}
