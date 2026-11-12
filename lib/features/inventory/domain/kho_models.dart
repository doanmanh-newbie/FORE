/// Mô hình dữ liệu của module Kho v2 (database/07_inventory.sql).
/// Số lượng luôn là số nguyên theo ĐƠN VỊ GỐC (ml, g, piece); đơn giá là đồng / đơn vị gốc.
/// Không phụ thuộc Flutter hay Supabase.
library;

part 'kho_overview_models.dart';
part 'kho_ingredient_models.dart';
part 'kho_supplier_models.dart';
part 'kho_purchase_models.dart';
part 'kho_suggestion_models.dart';
part 'kho_stocktake_models.dart';
part 'kho_waste_models.dart';
part 'kho_home_models.dart';

// ---------- Đọc JSON an toàn ----------
num? _num(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  throw FormatException('Trường "$k" cần là số, nhận được: $v');
}

int _int(Map<String, dynamic> m, String k, [int fallback = 0]) =>
    _num(m, k)?.round() ?? fallback;

int? _intOrNull(Map<String, dynamic> m, String k) => _num(m, k)?.round();

double? _dbl(Map<String, dynamic> m, String k) => _num(m, k)?.toDouble();

String _str(Map<String, dynamic> m, String k, [String fallback = '']) {
  final v = m[k];
  return v == null ? fallback : '$v';
}

String? _strOrNull(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v == null) return null;
  final t = '$v'.trim();
  return t.isEmpty ? null : t;
}

bool _bool(Map<String, dynamic> m, String k) => m[k] == true;

DateTime? _time(Map<String, dynamic> m, String k) {
  final v = m[k];
  return v is String ? DateTime.tryParse(v) : null;
}

List<Map<String, dynamic>> _list(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v == null) return const [];
  if (v is! List) throw FormatException('Trường "$k" cần là danh sách');
  return [
    for (final e in v)
      if (e is Map<String, dynamic>) e
  ];
}

List<Map<String, dynamic>> rowsOf(dynamic raw) {
  if (raw is! List) {
    throw FormatException('Cần danh sách, nhận được: ${raw.runtimeType}');
  }
  return [
    for (final e in raw)
      if (e is Map<String, dynamic>) e
  ];
}

Map<String, dynamic> objectOf(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  throw FormatException('Cần đối tượng JSON, nhận được: ${raw.runtimeType}');
}

/// Trạng thái tồn của một nguyên liệu.
enum StockStatus {
  ok,
  low,
  out;

  static StockStatus parse(String? v) => switch (v) {
        'low' => StockStatus.low,
        'out' => StockStatus.out,
        _ => StockStatus.ok,
      };
}
