/// Số điện thoại: chuẩn hóa và hiển thị. Số bắt đầu bằng 0 hiểu là số Việt Nam (+84);
/// số nước khác nhập kèm "+" và mã quốc gia.
abstract final class Phone {
  /// Dạng quốc tế có dấu "+", ví dụ `+84901234567`. `null` nếu không hợp lệ.
  static String? toE164(String input) {
    final trimmed = input.trim();
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    final String full;
    if (trimmed.startsWith('+')) {
      full = digits;
    } else if (digits.startsWith('0')) {
      full = '84${digits.substring(1)}';
    } else if (digits.startsWith('84')) {
      full = digits;
    } else {
      return null; // không rõ mã quốc gia
    }
    if (!RegExp(r'^[1-9][0-9]{7,14}$').hasMatch(full)) return null;
    // Số Việt Nam: 84 + 9 chữ số (di động) là đủ; chặn nhập thiếu/thừa rõ ràng.
    if (full.startsWith('84') && (full.length < 11 || full.length > 12)) {
      return null;
    }
    return '+$full';
  }

  /// Hiển thị dễ đọc: `+84901234567` -> `0901 234 567`; số nước khác giữ nguyên.
  static String pretty(String e164) {
    final digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('84') && digits.length >= 11) {
      final local = '0${digits.substring(2)}';
      final head = local.substring(0, 4);
      final rest = local.substring(4);
      final mid = rest.length > 3 ? rest.substring(0, 3) : rest;
      final tail = rest.length > 3 ? rest.substring(3) : '';
      return [head, mid, if (tail.isNotEmpty) tail].join(' ');
    }
    return e164.startsWith('+') ? e164 : '+$digits';
  }
}
