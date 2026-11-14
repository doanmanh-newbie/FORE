import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/phone.dart';

void main() {
  test('số 0xxx -> +84xxx', () {
    expect(Phone.toE164('0901 234 567'), '+84901234567');
    expect(Phone.toE164('090.123.4567'), '+84901234567');
  });
  test('đã có +84 hoặc 84', () {
    expect(Phone.toE164('+84901234567'), '+84901234567');
    expect(Phone.toE164('84901234567'), '+84901234567');
  });
  test('số sai bị từ chối', () {
    expect(Phone.toE164(''), isNull);
    expect(Phone.toE164('123'), isNull);
    expect(Phone.toE164('0901'), isNull);
    expect(Phone.toE164('abc'), isNull);
  });
  test('hiển thị dễ đọc', () {
    expect(Phone.pretty('+84901234567'), '0901 234 567');
  });
}
