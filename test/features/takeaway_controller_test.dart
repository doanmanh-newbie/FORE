import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/application/load_phase.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/sales/application/takeaway_controller.dart';
import 'package:fore/features/sales/domain/sales_models.dart';

import '../support/fakes.dart';

void main() {
  late FakeSalesRepository repo;
  late TakeawayController c;

  setUp(() {
    repo = FakeSalesRepository()
      ..takeaways = [
        order('o1', 83),
        order('o2', 84, status: BillStatus.paid, portions: 2, items: 'Bánh mì trứng, Cà phê sữa'),
        order('o3', 85),
      ];
    c = TakeawayController(repo);
  });

  test('tải danh sách giữ thứ tự cũ nhất ở trên', () async {
    await c.load();
    expect(c.phase, equals(LoadPhase.ready));
    expect(c.orders.map((o) => o.billNo).toList(), equals([83, 84, 85]));
    expect(c.orders[1].isPaid, isTrue);
  });

  test('"Chờ lâu nhất" chỉ gắn cho đơn đầu tiên và chỉ khi có từ 2 đơn', () async {
    await c.load();
    expect(c.isLongestWaiting(c.orders[0]), isTrue);
    expect(c.isLongestWaiting(c.orders[1]), isFalse);
    repo.takeaways = [order('o1', 83)];
    await c.load();
    expect(c.isLongestWaiting(c.orders[0]), isFalse);
  });

  test('danh sách rỗng không lỗi', () async {
    repo.takeaways = [];
    await c.load();
    expect(c.phase, equals(LoadPhase.ready));
    expect(c.orders, isEmpty);
  });

  group('đánh dấu xong', () {
    test('đơn biến mất khỏi danh sách', () async {
      await c.load();
      final ok = await c.markDone(c.orders[1]);
      expect(ok, isTrue);
      expect(c.orders.map((o) => o.billNo).toList(), equals([83, 85]));
      expect(repo.calls, contains('markPrepDone:o2'));
    });

    test('lỗi thì khôi phục danh sách và báo lỗi', () async {
      await c.load();
      repo.failNext('markPrepDone', const NoNetworkFailure());
      await expectLater(c.markDone(c.orders[0]), throwsA(isA<NoNetworkFailure>()));
      expect(c.orders, hasLength(3));
    });

    test('đơn đã bị máy khác xử lý (bill không còn mở): báo lỗi rồi tải lại', () async {
      await c.load();
      repo.takeaways = [order('o3', 85)]; // máy khác đã xong o1, o2
      repo.failNext('markPrepDone', const DatabaseFailure('NOT_FOUND'));
      await expectLater(c.markDone(c.orders[0]), throwsA(isA<DatabaseFailure>()));
      expect(c.orders.map((o) => o.billNo).toList(), equals([85]));
    });

    test('bấm đúp chỉ gửi một lệnh', () async {
      await c.load();
      final target = c.orders[0];
      final a = c.markDone(target);
      final b = await c.markDone(target);
      expect(b, isFalse);
      expect(await a, isTrue);
      expect(repo.count('markPrepDone'), equals(1));
    });
  });

  test('tạo đơn mới: mở bill mang đi không có bàn, rồi tải lại', () async {
    await c.load();
    final id = await c.createOrder();
    expect(id, isNotNull);
    expect(repo.calls, contains('openBill:-:take_away:-'));
    expect(repo.count('takeawayOrders'), equals(2));
  });
}
