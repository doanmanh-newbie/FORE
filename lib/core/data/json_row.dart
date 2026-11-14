/// Đọc một dòng kết quả JSON từ database với kiểu rõ ràng.
/// Sai kiểu / thiếu trường thì ném [FormatException] kèm tên trường, dễ tìm lỗi hơn là
/// `type 'Null' is not a subtype...` ở một chỗ xa.
extension RowReader on Map<String, dynamic> {
  String str(String key) {
    final v = this[key];
    if (v is String) return v;
    throw FormatException('Trường "$key" cần là chuỗi, nhận được: $v');
  }

  String? strOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is String) return v;
    throw FormatException('Trường "$key" cần là chuỗi, nhận được: $v');
  }

  int integer(String key) {
    final v = this[key];
    if (v is int) return v;
    if (v is num && v == v.roundToDouble()) return v.toInt();
    throw FormatException('Trường "$key" cần là số nguyên, nhận được: $v');
  }

  int? intOrNull(String key) => this[key] == null ? null : integer(key);

  bool flag(String key) {
    final v = this[key];
    if (v is bool) return v;
    throw FormatException('Trường "$key" cần là true/false, nhận được: $v');
  }

  DateTime time(String key) {
    final v = this[key];
    if (v is String) {
      final t = DateTime.tryParse(v);
      if (t != null) return t;
    }
    throw FormatException('Trường "$key" cần là thời gian, nhận được: $v');
  }

  DateTime? timeOrNull(String key) => this[key] == null ? null : time(key);
}

/// Ép kết quả `returns table` (JSON mảng) thành danh sách các dòng.
List<Map<String, dynamic>> asRows(dynamic raw) {
  if (raw is! List) {
    throw FormatException(
        'Cần danh sách các dòng, nhận được: ${raw.runtimeType}');
  }
  return [
    for (final e in raw)
      if (e is Map<String, dynamic>)
        e
      else
        throw FormatException(
            'Dòng không phải đối tượng JSON: ${e.runtimeType}'),
  ];
}

/// Ép kết quả `returns jsonb` (một đối tượng) thành bản đồ.
Map<String, dynamic> asObject(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  throw FormatException('Cần đối tượng JSON, nhận được: ${raw.runtimeType}');
}
