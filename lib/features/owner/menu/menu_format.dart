import '../../../core/format.dart';
import 'menu_models.dart';

const _fromChars =
    'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _toChars =
    'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Bỏ dấu và chữ hoa để tìm kiếm "latte" khớp "Latté", "tra dao" khớp "Trà đào".
String foldVietnamese(String input) {
  final lower = input.trim().toLowerCase();
  final out = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    final i = _fromChars.indexOf(ch);
    out.write(i >= 0 && i < _toChars.length ? _toChars[i] : ch);
  }
  return out.toString();
}

/// "68%" hoặc "65,1%" (dấu phẩy thập phân, bỏ ",0").
String formatPct(double value) {
  final rounded = (value * 10).round() / 10;
  if (rounded == rounded.roundToDouble()) return '${rounded.round()}%';
  return '${rounded.toStringAsFixed(1).replaceAll('.', ',')}%';
}

/// "35.000đ" hoặc "Chưa xác định".
String moneyOrUnknown(int? value) =>
    value == null ? 'Chưa xác định' : formatVnd(value);

/// Giá các size trên một dòng: "S 35.000 · M 42.000 · L 49.000đ" hoặc "Một size · 29.000đ".
String priceSummary(MenuItem item) {
  final sizes = item.activeSizes;
  if (sizes.isEmpty) return 'Chưa có size đang bán';
  if (sizes.length == 1) return 'Một size · ${formatVnd(sizes.first.price)}';
  final parts = [
    for (var i = 0; i < sizes.length; i++)
      i == sizes.length - 1
          ? '${sizes[i].name} ${formatVnd(sizes[i].price)}'
          : '${sizes[i].name} ${formatThousands(sizes[i].price)}',
  ];
  return parts.join(' · ');
}

String dateTimeLabel(DateTime t) => '${formatDmy(t)} · ${formatHm(t)}';

String dateTimeLong(DateTime t) => '${formatDmy(t)} lúc ${formatHm(t)}';

/// Cuối ngày hôm nay 06:00 hôm sau: mốc mặc định khi hẹn công thức/giá mới
/// (ngày kinh doanh bắt đầu lúc 06:00, nên ca đang bán không bị đổi giữa chừng).
DateTime nextBusinessDayStart([DateTime? now]) {
  final n = (now ?? DateTime.now()).toLocal();
  final today6 = DateTime(n.year, n.month, n.day, 6);
  return n.isBefore(today6) ? today6 : today6.add(const Duration(days: 1));
}

String weekLabel(DateTime? from, DateTime? to) {
  if (from == null || to == null) return '';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(from.day)}–${two(to.day)}/${two(to.month)}';
}
