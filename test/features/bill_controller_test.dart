import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/application/load_phase.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/sales/application/bill_controller.dart';
import 'package:fore/features/sales/domain/sales_models.dart';

import '../support/fakes.dart';

void main() {
  late FakeSalesRepository repo;
  late BillController c;

  setUp(() async {
    repo = FakeSalesRepository()..menuItems = List.of(sampleMenu);
    c = BillController(repo, 'b1');
    await c.load();
  });

  group('tải', () {
    test('có bill và thực đơn', () {
      expect(c.phase, equals(LoadPhase.ready));
      expect(c.bill!.title, equals('Bàn 2'));
      expect(c.menu, hasLength(2));
    });

    test('lỗi ở lần tải đầu hiện màn lỗi', () async {
      final r = FakeSalesRepository()..menuItems = List.of(sampleMenu);
      r.failNext('bill', const NoNetworkFailure());
      final fresh = BillController(r, 'b1');
      await fresh.load();
      expect(fresh.phase, equals(LoadPhase.error));
    });
  });

  group('giỏ món', () {
    test('tăng giảm số lượng và tính phần, tiền', () {
      c.setCartQty('cf-m', 2);
      c.setCartQty('cf-l', 1);
      c.setCartQty('bm-1', 3);
      expect(c.cartPortions, equals(6));
      expect(c.cartTotal, equals(2 * 25000 + 30000 + 3 * 20000)); // 140.000
      c.setCartQty('cf-m', 0);
      expect(c.cart.containsKey('cf-m'), isFalse);
      expect(c.cartPortions, equals(4));
    });

    test('giới hạn 0..99, không âm, không vượt trần', () {
      c.setCartQty('cf-m', -5);
      expect(c.cartQty('cf-m'), equals(0));
      c.setCartQty('cf-m', 500);
      expect(c.cartQty('cf-m'), equals(99));
    });

    test('clearCart', () {
      c.setCartQty('cf-m', 2);
      c.clearCart();
      expect(c.cart, isEmpty);
      expect(c.cartTotal, equals(0));
    });

    test('size không còn trong thực đơn thì tính giá 0, không sập', () {
      c.setCartQty('khong-co', 2);
      expect(c.cartTotal, equals(0));
    });
  });

  group('thực đơn: lọc và tìm', () {
    test('nhóm gồm "Ăn nhẹ" và "Khác" (món không nhóm)', () {
      expect(c.groups, equals(['Ăn nhẹ', 'Khác']));
    });
    test('lọc theo nhóm', () {
      c.selectGroup('Khác');
      expect(c.visibleMenu.map((i) => i.name).toList(), equals(['Cà phê sữa']));
      c.selectGroup(null);
      expect(c.visibleMenu, hasLength(2));
    });
    test('tìm không dấu', () {
      c.setQuery('ca phe');
      expect(c.visibleMenu.map((i) => i.name).toList(), equals(['Cà phê sữa']));
      c.setQuery('banh mi');
      expect(c.visibleMenu.map((i) => i.name).toList(), equals(['Bánh mì trứng']));
      c.setQuery('xyz');
      expect(c.visibleMenu, isEmpty);
    });
  });

  group('thêm vào bill', () {
    test('mỗi size gửi MỘT lần với số lượng đã chọn, giỏ rỗng sau đó, bill cập nhật', () async {
      c.setCartQty('cf-m', 2);
      c.setCartQty('bm-1', 1);
      final ok = await c.submitCart();
      expect(ok, isTrue);
      expect(repo.calls.where((x) => x.startsWith('addLine')).toList(),
          equals(['addLine:b1:cf-m:2', 'addLine:b1:bm-1:1']));
      expect(c.cart, isEmpty);
      expect(c.bill!.portions, equals(3));
      expect(c.bill!.subtotal, equals(2 * 25000 + 20000));
      expect(c.bill!.payable, equals(70000));
    });

    test('lệnh đầu lỗi: chưa gửi gì, giỏ giữ nguyên, thử lại được', () async {
      c.setCartQty('cf-m', 2);
      c.setCartQty('bm-1', 1);
      repo.failNext('addLine', const DatabaseFailure('ITEM_UNAVAILABLE'));
      await expectLater(c.submitCart(), throwsA(isA<DatabaseFailure>()));
      expect(c.cartPortions, equals(3));
      expect(c.bill!.lines, isEmpty);
      expect(c.busy, isFalse);
      expect(await c.submitCart(), isTrue);
      expect(c.cart, isEmpty);
      expect(c.bill!.portions, equals(3));
    });

    test('lệnh THỨ HAI lỗi: món thứ nhất đã vào bill và rời giỏ, chỉ còn món thứ hai để thử lại', () async {
      c.setCartQty('cf-m', 2);
      c.setCartQty('bm-1', 1);
      repo.failOnCall('addLine', 2, const DatabaseFailure('QTY_INVALID'));
      await expectLater(c.submitCart(), throwsA(isA<DatabaseFailure>()));
      expect(c.bill!.portions, equals(2)); // cà phê đã vào bill
      expect(c.cart, equals({'bm-1': 1})); // bánh mì còn trong giỏ, không mất và không bị gửi hai lần
      expect(await c.submitCart(), isTrue);
      expect(c.bill!.portions, equals(3));
      expect(c.cart, isEmpty);
      expect(repo.count('addLine'), equals(3)); // lần đầu 2 lệnh (cà phê ok, bánh mì lỗi) + thử lại 1 lệnh (bánh mì)
    });

    test('giỏ rỗng thì không gửi lệnh nào', () async {
      final ok = await c.submitCart();
      expect(ok, isTrue);
      expect(repo.count('addLine'), equals(0));
    });

    test('bill đã thanh toán từ máy khác: báo lỗi và tải lại để thấy bill đã đóng', () async {
      c.setCartQty('cf-m', 1);
      repo.status = BillStatus.paid;
      repo.failNext('addLine', const DatabaseFailure('BILL_NOT_OPEN'));
      await expectLater(c.submitCart(), throwsA(isA<DatabaseFailure>()));
      expect(c.isOpen, isFalse);
    });
  });

  group('có được thanh toán không', () {
    test('bill trống: không', () {
      expect(c.canPay, isFalse);
    });
    test('có món nhưng còn món trong giỏ chưa gửi: không', () async {
      c.setCartQty('cf-m', 1);
      await c.submitCart();
      c.setCartQty('bm-1', 1);
      expect(c.canPay, isFalse);
      c.clearCart();
      expect(c.canPay, isTrue);
    });
    test('bill đã thanh toán hoặc hủy: không', () async {
      c.setCartQty('cf-m', 1);
      await c.submitCart();
      await c.pay(PaymentMethod.cash);
      expect(c.canPay, isFalse);
    });
  });

  group('bỏ dòng', () {
    setUp(() async {
      c.setCartQty('cf-m', 1);
      c.setCartQty('bm-1', 2);
      await c.submitCart();
    });

    test('bỏ một dòng: dòng đánh dấu đã bỏ, tiền giảm, số phần giảm', () async {
      final line = c.bill!.lines.first;
      await c.voidLine(line.id, 'khách đổi ý');
      expect(c.bill!.lines.firstWhere((l) => l.id == line.id).voided, isTrue);
      expect(c.bill!.activeLines, hasLength(1));
      expect(c.bill!.subtotal, equals(40000));
      expect(repo.calls, contains('voidLine:${line.id}:khách đổi ý'));
    });

    test('dòng đã bị máy khác bỏ rồi: báo lỗi và tải lại', () async {
      final line = c.bill!.lines.first;
      repo.failNext('voidLine', const DatabaseFailure('LINE_ALREADY_VOIDED'));
      await expectLater(c.voidLine(line.id, 'x'), throwsA(isA<DatabaseFailure>()));
      expect(c.phase, equals(LoadPhase.ready));
    });
  });

  group('giảm giá', () {
    setUp(() async {
      c.setCartQty('cf-m', 2); // 50.000
      await c.submitCart();
    });

    test('giảm hợp lệ: phải thu giảm theo, lý do được lưu', () async {
      await c.setDiscount(5000, '  khách quen ');
      expect(c.bill!.discount, equals(5000));
      expect(c.bill!.payable, equals(45000));
      expect(repo.calls, contains('setDiscount:b1:5000:khách quen')); // đã cắt khoảng trắng
    });

    test('giảm lớn hơn tổng: bị chặn ngay ở máy, không gọi database', () async {
      await expectLater(c.setDiscount(50001, 'x'), throwsA(isA<DatabaseFailure>().having((e) => e.code, 'code', 'DISCOUNT_INVALID')));
      expect(repo.count('setDiscount'), equals(0));
    });

    test('giảm âm: bị chặn', () async {
      await expectLater(c.setDiscount(-1, 'x'), throwsA(isA<DatabaseFailure>().having((e) => e.code, 'code', 'DISCOUNT_INVALID')));
    });

    test('giảm lớn hơn 0 mà không có lý do: bị chặn', () async {
      await expectLater(c.setDiscount(1000, '   '), throwsA(isA<DatabaseFailure>().having((e) => e.code, 'code', 'REASON_REQUIRED')));
      expect(repo.count('setDiscount'), equals(0));
    });

    test('giảm bằng đúng tổng (miễn phí) được phép; bỏ giảm giá (0) không cần lý do', () async {
      await c.setDiscount(50000, 'khách VIP');
      expect(c.bill!.payable, equals(0));
      await c.setDiscount(0, '');
      expect(c.bill!.payable, equals(50000));
    });
  });

  group('hủy bill', () {
    test('cần lý do; hủy xong bill không còn mở', () async {
      await expectLater(c.cancelBill('  '), throwsA(isA<DatabaseFailure>()));
      expect(repo.count('cancelOpenBill'), equals(0));
      await c.cancelBill('khách bỏ về');
      expect(c.isOpen, isFalse);
      expect(c.bill!.status, equals(BillStatus.cancelled));
    });
  });

  group('thanh toán', () {
    setUp(() async {
      c.setCartQty('cf-m', 2);
      await c.submitCart();
      await c.setDiscount(5000, 'khách quen');
    });

    test('trả đúng số tiền đã thu và bill chuyển sang đã thanh toán', () async {
      final total = await c.pay(PaymentMethod.transfer);
      expect(total, equals(45000));
      expect(c.bill!.status, equals(BillStatus.paid));
      expect(c.bill!.paymentMethod, equals('transfer'));
      expect(repo.calls, contains('pay:b1:transfer'));
    });

    test('bấm đúp chỉ thu một lần', () async {
      repo.gate = Completer<void>();
      final first = c.pay(PaymentMethod.cash);
      final second = await c.pay(PaymentMethod.cash);
      expect(second, isNull);
      repo.gate!.complete();
      expect(await first, equals(45000));
      expect(repo.count('pay'), equals(1));
    });

    test('máy khác đã thanh toán trước: báo lỗi và hiện bill đã đóng', () async {
      repo.status = BillStatus.paid;
      repo.failNext('pay', const DatabaseFailure('BILL_NOT_OPEN'));
      await expectLater(c.pay(PaymentMethod.cash), throwsA(isA<DatabaseFailure>()));
      expect(c.isOpen, isFalse);
    });

    test('giảm giá lớn hơn tổng sau khi bỏ dòng: database từ chối, bill vẫn mở để sửa', () async {
      repo.failNext('pay', const DatabaseFailure('DISCOUNT_INVALID'));
      await expectLater(c.pay(PaymentMethod.cash), throwsA(isA<DatabaseFailure>()));
      expect(c.isOpen, isTrue);
      expect(c.busy, isFalse); // nút không bị kẹt ở trạng thái bận
    });

    test('mất mạng khi thanh toán: báo lỗi, không kẹt, thử lại được', () async {
      repo.failNext('pay', const NoNetworkFailure());
      await expectLater(c.pay(PaymentMethod.cash), throwsA(isA<NoNetworkFailure>()));
      expect(c.busy, isFalse);
      expect(await c.pay(PaymentMethod.cash), equals(45000));
    });

    test('đóng màn hình khi đang thu tiền thì không lỗi', () async {
      repo.gate = Completer<void>();
      final f = c.pay(PaymentMethod.cash);
      c.dispose();
      repo.gate!.complete();
      expect(await f, equals(45000));
    });
  });
}
