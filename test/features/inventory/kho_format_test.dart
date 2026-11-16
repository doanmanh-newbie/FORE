import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/inventory/application/kho_format.dart';

void main() {
  group('số lượng', () {
    test('hiển thị lít / kg / cái cho gọn', () {
      expect(formatKhoQty(12000, 'ml'), '12 lít');
      expect(formatKhoQty(500, 'ml'), '0,5 lít');
      expect(formatKhoQty(2500, 'g'), '2,5 kg');
      expect(formatKhoQty(1200, 'piece'), '1.200 cái');
      expect(formatKhoQty(0, 'ml'), '0 lít');
    });

    test('số có dấu cho chênh lệch', () {
      expect(formatKhoQty(-1000, 'ml', signed: true), '−1 lít');
      expect(formatKhoQty(300, 'g', signed: true), '+0,3 kg');
    });

    test('đọc chữ người dùng gõ về đơn vị gốc', () {
      expect(parseKhoQty('12', 'ml'), 12000);
      expect(parseKhoQty('0,5', 'ml'), 500);
      expect(parseKhoQty('0.5', 'g'), 500);
      expect(parseKhoQty('7', 'piece'), 7);
      expect(parseKhoQty('0', 'ml'), 0);
    });

    test('từ chối chữ không hợp lệ thay vì đoán', () {
      expect(parseKhoQty('', 'ml'), isNull);
      expect(parseKhoQty('abc', 'ml'), isNull);
      expect(parseKhoQty('-1', 'ml'), isNull);
      expect(parseKhoQty('2,5', 'piece'), isNull, reason: 'cái không chia nhỏ');
      expect(parseKhoQty('0,0004', 'ml'), isNull, reason: 'nhỏ hơn 1 ml');
    });

    test('đi và về khớp nhau', () {
      for (final q in [1, 500, 1000, 2500, 12000]) {
        expect(parseKhoQty(khoQtyInput(q, 'ml'), 'ml'), q);
      }
    });
  });

  group('đơn giá', () {
    test('giá theo lít / kg từ giá theo đơn vị gốc', () {
      expect(formatKhoPrice(50, 'ml'), '50.000đ/lít');
      expect(formatKhoPrice(800, 'g'), '800.000đ/kg');
      expect(formatKhoPrice(3500, 'piece'), '3.500đ/cái');
      expect(formatKhoPrice(null, 'ml'), 'Chưa có giá');
    });

    test('đọc giá người gõ', () {
      expect(parseKhoPrice('50.000', 'ml'), 50);
      expect(parseKhoPrice('800000', 'g'), 800);
      expect(parseKhoPrice('3500', 'piece'), 3500);
      expect(parseKhoPrice('', 'ml'), isNull);
    });
  });

  test('phần trăm và ngày còn dùng', () {
    expect(formatPct(5.26), '+5,3%');
    expect(formatPct(-12), '−12%');
    expect(formatDaysLeft(null), 'Chưa đủ số liệu dùng');
    expect(formatDaysLeft(0.4), 'dưới 1 ngày');
    expect(formatDaysLeft(2.2), 'khoảng 2 ngày');
  });

  test('nhãn ca theo giờ mở', () {
    expect(shiftLabel(DateTime(2026, 11, 7, 7)), 'Ca sáng');
    expect(shiftLabel(DateTime(2026, 11, 7, 14)), 'Ca chiều');
    expect(shiftLabel(DateTime(2026, 11, 7, 20)), 'Ca tối');
  });
}
