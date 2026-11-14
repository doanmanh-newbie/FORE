import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/greeting.dart';

void main() {
  test('buổi trong ngày', () {
    expect(partOfDay(DateTime(2026, 10, 25, 6)), 'buổi sáng');
    expect(partOfDay(DateTime(2026, 10, 25, 12)), 'buổi trưa');
    expect(partOfDay(DateTime(2026, 10, 25, 15)), 'buổi chiều');
    expect(partOfDay(DateTime(2026, 10, 25, 20)), 'buổi tối');
    expect(partOfDay(DateTime(2026, 10, 25, 2)), 'buổi tối');
  });

  test('tên gọi ngắn lấy từ cuối họ tên', () {
    expect(shortName('Nguyễn Văn An'), 'An');
    expect(shortName('  An  '), 'An');
    expect(shortName(''), '');
  });
}
