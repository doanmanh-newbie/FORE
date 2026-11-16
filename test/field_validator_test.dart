import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/validation/field_validator.dart';

void main() {
  test('RequiredValidator: chuỗi trống hoặc toàn khoảng trắng là lỗi', () {
    const v = RequiredValidator('Nhập họ tên.');
    expect(v.validate(''), 'Nhập họ tên.');
    expect(v.validate('   '), 'Nhập họ tên.');
    expect(v.validate('An'), isNull);
  });

  test('EmailFormatValidator', () {
    const v = EmailFormatValidator('sai');
    expect(v.validate('an@quan.vn'), isNull);
    expect(v.validate(' an@quan.vn '), isNull);
    expect(v.validate('an@quan'), 'sai');
    expect(v.validate('an quan@x.vn'), 'sai');
    expect(v.validate(''), 'sai');
  });

  test('MinLengthValidator: đúng ngưỡng thì hợp lệ', () {
    const v = MinLengthValidator(8, 'ngắn');
    expect(v.validate('1234567'), 'ngắn');
    expect(v.validate('12345678'), isNull);
  });

  test('MatchesValidator đọc giá trị mới nhất của ô kia', () {
    var other = 'abc';
    final v = MatchesValidator(() => other, 'khác');
    expect(v.validate('abc'), isNull);
    other = 'xyz';
    expect(v.validate('abc'), 'khác');
  });

  test('CompositeValidator dừng ở lỗi đầu tiên', () {
    const v = CompositeValidator([
      RequiredValidator('trống'),
      EmailFormatValidator('sai'),
    ]);
    expect(v.validate(''), 'trống');
    expect(v.validate('x'), 'sai');
    expect(v.validate('a@b.co'), isNull);
  });
}
