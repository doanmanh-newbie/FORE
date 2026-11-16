import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/format.dart';

void main() {
  test('định dạng tiền', () {
    expect(formatVnd(583000), '583.000đ');
    expect(formatVnd(35000), '35.000đ');
    expect(formatVnd(0), '0đ');
  });

  test('đọc số tiền người dùng gõ', () {
    expect(parseVnd('500000'), 500000);
    expect(parseVnd('500.000'), 500000);
    expect(parseVnd('500 000đ'), 500000);
    expect(parseVnd('0'), 0);
    expect(parseVnd(''), isNull);
    expect(parseVnd('abc'), isNull);
    expect(parseVnd('1234567890'), isNull);
  });

  test('giờ phút luôn đủ hai chữ số', () {
    expect(formatHm(DateTime(2026, 10, 25, 8, 2)), '08:02');
    expect(formatHm(DateTime(2026, 10, 25, 14, 30)), '14:30');
  });

  test('số có dấu chấm ngăn nghìn', () {
    expect(formatThousands(0), '0');
    expect(formatThousands(999), '999');
    expect(formatThousands(1000), '1.000');
    expect(formatThousands(1234567), '1.234.567');
  });

  test('ngày tháng và khoảng thời gian', () {
    expect(formatDayMonth(DateTime(2026, 10, 25)), '25 tháng 10');
    expect(formatElapsed(Duration.zero), 'Vừa mở');
    expect(formatElapsed(const Duration(minutes: 45)), '45 phút');
    expect(formatElapsed(const Duration(hours: 3)), '3 giờ');
    expect(formatElapsed(const Duration(hours: 3, minutes: 20)), '3 giờ 20 phút');
    expect(formatElapsed(const Duration(minutes: -5)), 'Vừa mở');
  });

  group('VndInputFormatter', () {
    const formatter = VndInputFormatter();
    String run(String input) => formatter
        .formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(text: input),
        )
        .text;

    test('thêm dấu chấm khi gõ', () {
      expect(run('5'), '5');
      expect(run('500000'), '500.000');
      expect(run('1500000'), '1.500.000');
    });

    test('bỏ ký tự lạ và số 0 thừa ở đầu', () {
      expect(run('5a0b0'), '500');
      expect(run('0500'), '500');
      expect(run('000'), '0');
      expect(run(''), '');
    });

    test('tối đa 9 chữ số', () {
      expect(run('1234567890123'), '123.456.789');
    });
  });
}
