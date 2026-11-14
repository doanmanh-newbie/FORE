import '../../../core/phone.dart';

/// Cách nhân viên xưng danh khi đăng nhập: số điện thoại HOẶC email.
enum ContactKind { phone, email }

/// Liên hệ đăng nhập của nhân viên đã được chuẩn hóa.
///
/// Chỉ tạo được qua [tryParse], nên đã có một [StaffContact] thì giá trị bên trong luôn hợp lệ.
class StaffContact {
  const StaffContact._(this.kind, this.value);

  final ContactKind kind;

  /// Số dạng quốc tế có dấu "+" (`+84901234567`) hoặc email viết thường.
  final String value;

  String? get phone => kind == ContactKind.phone ? value : null;
  String? get email => kind == ContactKind.email ? value : null;

  /// Dạng dễ đọc để hiện cho người dùng (`0901 234 567` hoặc email).
  String get pretty => kind == ContactKind.phone ? Phone.pretty(value) : value;

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// Đọc chuỗi người dùng gõ. Đúng thì trả về `contact`, sai thì trả về câu báo lỗi trong `error`.
  static ({StaffContact? contact, String? error}) tryParse(
    ContactKind kind,
    String raw,
  ) {
    final text = raw.trim();
    switch (kind) {
      case ContactKind.phone:
        if (text.isEmpty) return (contact: null, error: 'Nhập số điện thoại.');
        final e164 = Phone.toE164(text);
        if (e164 == null) {
          return (
            contact: null,
            error: 'Số điện thoại chưa đúng. Ví dụ: 0901 234 567.',
          );
        }
        return (contact: StaffContact._(kind, e164), error: null);
      case ContactKind.email:
        if (text.isEmpty) return (contact: null, error: 'Nhập email.');
        final email = text.toLowerCase();
        if (!_emailPattern.hasMatch(email)) {
          return (contact: null, error: 'Email chưa đúng định dạng.');
        }
        return (contact: StaffContact._(kind, email), error: null);
    }
  }
}
