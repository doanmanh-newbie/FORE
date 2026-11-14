import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/inventory/domain/kho_models.dart';

void main() {
  test('chênh lệch kiểm kê: thiếu, thừa và ròng tính đúng', () {
    final d = StocktakeDetail.fromJson({
      'id': 'k1',
      'code': 'KK-0711',
      'status': 'submitted',
      'staff_name': 'Lan',
      'stock_value_now': 3300000,
      'lines': [
        {'ingredient_id': 'a', 'name': 'Sữa', 'unit': 'ml', 'counted_qty': 11000, 'system_qty': 12000, 'variance': -1000, 'variance_value': -50000},
        {'ingredient_id': 'b', 'name': 'Đường', 'unit': 'g', 'counted_qty': 5300, 'system_qty': 5000, 'variance': 300, 'variance_value': 6000},
        {'ingredient_id': 'c', 'name': 'Cà phê', 'unit': 'g', 'counted_qty': 900, 'system_qty': 900, 'variance': 0, 'variance_value': 0},
      ],
    });
    expect(d.status, StocktakeStatus.submitted);
    expect(d.varianceLines.map((l) => l.name), ['Sữa', 'Đường']);
    expect(d.shortValue, -50000);
    expect(d.overValue, 6000);
    expect(d.netValue, -44000);
  });

  test('hao hụt: chỉ báo tăng bất thường khi có kỳ trước và tăng ≥ 1,5 lần', () {
    WasteOverview make(int v, int prev) => WasteOverview.fromJson({
          'from': '2026-11-01',
          'to': '2026-11-07',
          'total_value': v,
          'prev_value': prev,
          'by_reason': [
            {'code': 'expired', 'label': 'Hết hạn', 'value': v, 'prev_value': prev, 'count': 2},
          ],
        });
    expect(make(300000, 100000).spike?.code, 'expired');
    expect(make(120000, 100000).spike, isNull);
    expect(make(300000, 0).spike, isNull, reason: 'không có kỳ trước thì không so sánh');
  });

  test('tổng quan: % hao hụt đổi so với 7 ngày trước', () {
    InvOverview make(int w, int p) =>
        InvOverview.fromJson({'waste_7d': w, 'waste_prev_7d': p});
    expect(make(150, 100).wasteChangePct, 50);
    expect(make(50, 100).wasteChangePct, -50);
    expect(make(50, 0).wasteChangePct, isNull);
  });

  test('đọc số dạng chuỗi hoặc số thực và báo lỗi khi sai dạng', () {
    final item = CatalogItem.fromJson({
      'id': 'x',
      'name': 'Sữa',
      'unit': 'ml',
      'stock': '12000',
      'unit_cost': 52.5,
      'min_stock_qty': 5000.0,
      'status': 'low',
      'days_left': 1.5,
    });
    expect(item.stock, 12000);
    expect(item.unitCost, 52.5);
    expect(item.minStock, 5000);
    expect(item.status, StockStatus.low);
    expect(() => CatalogItem.fromJson({'stock': [1]}),
        throwsFormatException);
  });

  test('dòng phiếu: thành tiền và không gửi giá khi là nhân viên', () {
    const line = PoLine(
        ingredientId: 'i', name: 'Sữa', unit: 'ml', qty: 30000, unitPrice: 50);
    expect(line.lineTotal, 1500000);
    expect(line.toJson(withPrice: true)['unit_price'], 50);
    expect(line.toJson(withPrice: false).containsKey('unit_price'), isFalse);
    expect(line.copyWith(clearPrice: true).lineTotal, isNull);
  });

  test('phiếu của nhân viên không có giá vẫn đọc được', () {
    final d = PoDetail.fromJson({
      'id': 'p',
      'code': 'PN-0711',
      'status': 'confirmed',
      'needs_pricing': true,
      'lines': [
        {'id': 'l', 'ingredient_id': 'i', 'name': 'Đường', 'unit': 'g', 'qty': 5000}
      ],
    });
    expect(d.needsPricing, isTrue);
    expect(d.totalAmount, isNull);
    expect(d.lines.single.unitPrice, isNull);
  });
}
