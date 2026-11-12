part of 'owner_home_screen.dart';

String _businessDayLabel(OwnerDashboardData data) =>
    'Ngày kinh doanh: ${formatHm(data.businessStart)} · ${data.businessStart.day}/${data.businessStart.month} – 05:59 hôm sau';

String _unavailableNames(Set<String> names) => names
    .map((name) => switch (name) {
          'menu' => 'thực đơn',
          'stock' => 'tồn kho',
          'trend' => 'biểu đồ 7 ngày',
          'recipe' => 'tình trạng công thức',
          _ => name,
        })
    .join(', ');

String _shortDate(DateTime date) => '${date.day}/${date.month}';

String _minimumStock(Map<String, dynamic> ingredient, OwnerDashboardData data) {
  final matching = data.lowStock
      .where((item) => item['ingredient_id'] == ingredient['ingredient_id']);
  if (matching.isEmpty) return '';
  final threshold = _number(matching.first['minimum_qty']);
  return ' · Ngưỡng ${formatQuantity(threshold, unit: '${ingredient['unit'] ?? ''}')}';
}

bool _isBelowThreshold(
  Map<String, dynamic> ingredient,
  OwnerDashboardData data,
) =>
    data.lowStock
        .any((item) => item['ingredient_id'] == ingredient['ingredient_id']);

StatusSeverity _stockSeverity(int quantity, {bool belowThreshold = false}) =>
    quantity < 0
        ? StatusSeverity.critical
        : belowThreshold
            ? StatusSeverity.attention
            : StatusSeverity.healthy;

List<Map<String, dynamic>> _stockRowsBySeverity(OwnerDashboardData data) {
  final rows = data.expectedStock.toList();
  int rank(Map<String, dynamic> row) {
    if (row['expected_qty'] == null) return 3;
    final severity = _stockSeverity(
      _number(row['expected_qty']),
      belowThreshold: _isBelowThreshold(row, data),
    );
    return switch (severity) {
      StatusSeverity.critical => 0,
      StatusSeverity.attention => 1,
      StatusSeverity.healthy => 2,
      StatusSeverity.neutral => 3,
    };
  }

  rows.sort((a, b) {
    final bySeverity = rank(a).compareTo(rank(b));
    return bySeverity != 0
        ? bySeverity
        : '${a['name'] ?? ''}'.compareTo('${b['name'] ?? ''}');
  });
  return rows;
}

String _stockStatusLabel(Map<String, dynamic> row, OwnerDashboardData data) {
  final quantity = _number(row['expected_qty']);
  if (quantity < 0) return 'Tồn âm';
  return _isBelowThreshold(row, data) ? 'Dưới ngưỡng' : 'Đủ tồn';
}

int _number(dynamic value) => value is num ? value.round() : 0;

String _errorMessage(Object? error) {
  if (error is PostgrestException) {
    if (error.code == 'PGRST202') {
      return 'Database chưa có API mới của màn chủ quán. Hãy cập nhật schema theo hướng dẫn HUONG_DAN_NHIEU_QUAN.md và tải lại app.';
    }
    if (error.code == '42703' || error.code == '42P01') {
      return 'Database chưa có đủ bảng hoặc cột cho màn chủ quán. Hãy cài lại schema mới nhất (database/01–04).';
    }
    return 'Không đọc được dữ liệu từ database (${error.code ?? 'lỗi truy vấn'}).';
  }
  if (error != null && looksLikeNetworkError(error)) {
    return 'Không có kết nối mạng. Hãy kiểm tra mạng rồi thử lại.';
  }
  return 'Không tải được dữ liệu quán. Hãy kiểm tra kết nối và thử lại.';
}
