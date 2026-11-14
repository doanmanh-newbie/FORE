/// Quy tắc kiểm tra một ô nhập. Trả về câu lỗi, hoặc `null` nếu hợp lệ.
///
/// Mỗi quy tắc là một lớp nhỏ làm đúng một việc; ghép lại bằng
/// [CompositeValidator]. Muốn thêm quy tắc mới chỉ cần thêm một lớp con.
abstract class FieldValidator {
  const FieldValidator();

  String? validate(String value);
}

class RequiredValidator extends FieldValidator {
  const RequiredValidator(this.message);

  final String message;

  @override
  String? validate(String value) => value.trim().isEmpty ? message : null;
}

class EmailFormatValidator extends FieldValidator {
  const EmailFormatValidator(this.message);

  final String message;

  static final _pattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  String? validate(String value) =>
      _pattern.hasMatch(value.trim()) ? null : message;
}

class MinLengthValidator extends FieldValidator {
  const MinLengthValidator(this.minLength, this.message);

  final int minLength;
  final String message;

  @override
  String? validate(String value) => value.length < minLength ? message : null;
}

/// Hai ô phải giống nhau (nhập lại mật khẩu). Giá trị ô kia lấy lúc kiểm tra.
class MatchesValidator extends FieldValidator {
  const MatchesValidator(this.other, this.message);

  final String Function() other;
  final String message;

  @override
  String? validate(String value) => value == other() ? null : message;
}

/// Chạy lần lượt, dừng ở lỗi đầu tiên.
class CompositeValidator extends FieldValidator {
  const CompositeValidator(this.validators);

  final List<FieldValidator> validators;

  @override
  String? validate(String value) {
    for (final v in validators) {
      final error = v.validate(value);
      if (error != null) return error;
    }
    return null;
  }
}
