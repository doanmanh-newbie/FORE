import '../../../core/format.dart';
import '../domain/kho_models.dart';

/// Định dạng số lượng, đơn giá, ngày giờ của Kho. Dữ liệu luôn là đơn vị gốc (ml, g, cái);
/// màn hình hiển thị lít / kg cho gọn, giống cách người pha chế vẫn gọi.

/// Hệ số từ đơn vị hiển thị về đơn vị gốc (1 lít = 1000 ml).
int displayFactor(String unit) => unit == 'piece' ? 1 : 1000;

/// Tên đơn vị hiển thị khi nhập/đọc số lớn.
String displayUnit(String unit) => switch (unit) {
      'ml' => 'lít',
      'g' => 'kg',
      _ => 'cái',
    };

String _trimDecimal(double v, int digits) {
  var s = v.toStringAsFixed(digits);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

/// `formatKhoQty(12000, 'ml')` → `12 lít`; `formatKhoQty(500, 'ml')` → `0,5 lít`.
/// Số dưới 1 đơn vị lớn vẫn hiện bằng đơn vị lớn để người đọc không phải tự quy đổi.
String formatKhoQty(num qty, String unit, {bool signed = false}) {
  final sign = signed && qty > 0 ? '+' : (qty < 0 ? '−' : '');
  final abs = qty.abs();
  if (unit == 'piece') return '$sign${formatThousands(abs.round())} cái';
  final big = abs / 1000;
  final text = big >= 100
      ? formatThousands(big.round())
      : _trimDecimal(big, big >= 10 ? 1 : 2);
  return '$sign$text ${displayUnit(unit)}';
}

/// Chỉ phần số, không kèm đơn vị (dùng trong ô nhập).
String khoQtyInput(int qty, String unit) {
  if (unit == 'piece') return '$qty';
  return _trimDecimal(qty / 1000, 3);
}

/// Đổi chữ người dùng gõ (ví dụ `0,5`) sang đơn vị gốc; `null` nếu chưa hợp lệ.
int? parseKhoQty(String text, String unit) {
  final cleaned = text.trim().replaceAll(',', '.');
  final v = double.tryParse(cleaned);
  if (v == null || v.isNaN || v.isInfinite || v < 0) return null;
  final base = v * displayFactor(unit);
  final r = base.round();
  if ((base - r).abs() > 1e-6 || r > 1000000000) return null;
  return r;
}

/// Giá theo đơn vị hiển thị: `50` đ/ml → `50.000đ/lít`.
String formatKhoPrice(double? perBase, String unit) {
  if (perBase == null) return 'Chưa có giá';
  final v = perBase * displayFactor(unit);
  final text = v >= 1000 || v == v.roundToDouble()
      ? formatThousands(v.round())
      : _trimDecimal(v, 1);
  return '$textđ/${displayUnit(unit)}';
}

/// Đổi giá người gõ theo đơn vị hiển thị (đ/lít) sang đồng/đơn vị gốc.
double? parseKhoPrice(String text, String unit) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty || digits.length > 10) return null;
  return int.parse(digits) / displayFactor(unit);
}

/// Giá hiển thị trong ô nhập (không đơn vị).
String khoPriceInput(double? perBase, String unit) =>
    perBase == null ? '' : formatThousands((perBase * displayFactor(unit)).round());

String formatSignedVnd(int amount) =>
    amount > 0 ? '+${formatVnd(amount)}' : (amount < 0 ? '−${formatVnd(-amount)}' : '0đ');

String formatPct(double pct) {
  final s = _trimDecimal(pct.abs(), 1);
  return '${pct > 0 ? '+' : (pct < 0 ? '−' : '')}$s%';
}

/// "Còn khoảng 2 ngày" / "Còn dưới 1 ngày".
String formatDaysLeft(double? days) {
  if (days == null) return 'Chưa đủ số liệu dùng';
  if (days < 1) return 'dưới 1 ngày';
  return 'khoảng ${days.round()} ngày';
}

String formatShortDate(DateTime d) {
  final t = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}';
}

String formatDateTimeShort(DateTime d) =>
    '${formatShortDate(d)}, ${formatHm(d)}';

String formatDateTimeFull(DateTime d) =>
    '${formatDmy(d)}, ${formatHm(d)}';

String formatRange(DateTime from, DateTime to) =>
    '${formatShortDate(from)}–${formatShortDate(to)}';

String movementLabel(String kind) => switch (kind) {
      'purchase' => 'Nhập hàng',
      'waste' => 'Hao hụt',
      'adjust' => 'Kiểm kê · Điều chỉnh',
      'sale' => 'Dùng theo công thức',
      _ => kind,
    };

String shiftLabel(DateTime? openedAt) {
  if (openedAt == null) return 'Ca đang mở';
  final h = openedAt.toLocal().hour;
  return h < 12 ? 'Ca sáng' : (h < 18 ? 'Ca chiều' : 'Ca tối');
}

/// Nhóm các dòng theo tên nhóm, giữ thứ tự xuất hiện.
Map<String, List<T>> groupBy<T>(Iterable<T> items, String? Function(T) key) {
  final out = <String, List<T>>{};
  for (final i in items) {
    out.putIfAbsent(key(i) ?? 'Khác', () => []).add(i);
  }
  return out;
}

extension PoStatusLabel on PoStatus {
  String get label => switch (this) {
        PoStatus.draft => 'Bản nháp',
        PoStatus.confirmed => 'Đã nhập',
        PoStatus.cancelled => 'Đã hủy',
      };
}
