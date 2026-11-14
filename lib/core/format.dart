import 'package:flutter/services.dart';

/// Tiền luôn là số nguyên (đồng). Không dùng số thập phân.
String formatVnd(int amount) =>
    '${amount < 0 ? '-' : ''}${formatThousands(amount.abs())}đ';

/// Định dạng số lượng nguyên theo quy ước của app, có dấu chấm ngăn nghìn.
/// Ví dụ: `formatQuantity(4400, unit: 'g')` → `4.400 g`.
String formatQuantity(int amount, {String? unit}) {
  final value = formatThousands(amount);
  final suffix = unit?.trim();
  if (suffix == null || suffix.isEmpty) return value;
  // Database lưu đơn vị đếm là 'piece'; người dùng đọc là "cái".
  return '$value ${suffix == 'piece' ? 'cái' : suffix}';
}

/// Số có dấu chấm ngăn nghìn, không có chữ "đ" (ví dụ 500.000).
String formatThousands(int amount) {
  final s = amount.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return '${amount < 0 ? '-' : ''}$b';
}

/// Đọc số tiền người dùng gõ ("500.000", "500 000", "500000đ") thành số đồng.
/// Trả về `null` nếu không có chữ số nào hoặc quá lớn (hơn 9 chữ số).
int? parseVnd(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty || digits.length > 9) return null;
  return int.parse(digits);
}

/// Parser dùng ở các màn bán hàng: cho phép tối đa 12 chữ số.
int? parseMoney(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty || digits.length > 12) return null;
  return int.parse(digits);
}

/// Giờ ngắn gọn cho thẻ bàn và bill (8:02).
String formatClock(DateTime time) {
  final local = time.toLocal();
  return '${local.hour}:${local.minute.toString().padLeft(2, '0')}';
}

String formatWait(Duration duration) {
  if (duration.inMinutes < 1) return 'vừa xong';
  if (duration.inMinutes < 60) return '${duration.inMinutes} phút';
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  return minutes == 0 ? '$hours giờ' : '$hours giờ $minutes phút';
}

String formatServings(int count, String label) =>
    formatQuantity(count, unit: label);

/// Giờ phút dạng 08:02 (theo giờ địa phương của máy).
String formatHm(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.hour)}:${two(t.minute)}';
}

/// Ngày dạng 05/03/2001 (theo giờ địa phương của máy).
String formatDmy(DateTime time) {
  final t = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)}/${t.year}';
}

/// "25 tháng 10".
String formatDayMonth(DateTime time) {
  final t = time.toLocal();
  return '${t.day} tháng ${t.month}';
}

/// Khoảng thời gian ngắn gọn: "Vừa mở", "45 phút", "3 giờ", "3 giờ 20 phút".
String formatElapsed(Duration d) {
  final minutes = d.inMinutes < 0 ? 0 : d.inMinutes;
  if (minutes < 1) return 'Vừa mở';
  if (minutes < 60) return '$minutes phút';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

/// Ô nhập tiền: chỉ giữ chữ số, tự thêm dấu chấm ngăn nghìn khi gõ,
/// tối đa 9 chữ số, bỏ số 0 thừa ở đầu.
class VndInputFormatter extends TextInputFormatter {
  const VndInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > 9) digits = digits.substring(0, 9);
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    final text = digits.isEmpty ? '' : formatThousands(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
