import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/inventory/data/rpc_inventory_repository.dart';
import 'package:fore/features/sales/data/rpc_sales_repository.dart';
import 'package:fore/features/sales/domain/sales_models.dart';
import 'package:fore/features/shift/operations/data/rpc_ops_shift_repository.dart';
import 'package:fore/features/stocktake/data/rpc_stocktake_repository.dart';
import 'package:fore/features/stocktake/domain/stocktake_models.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/owner/domain/owner_dashboard_models.dart';

import '../support/fakes.dart';

/// Test "hợp đồng" giữa app và database:
///  1. Các file trong test/fixtures/ là KẾT QUẢ THẬT do database trả về (xuất bằng
///     database/tests/90_dump_app_fixtures.sql). App phải đọc được chúng.
///  2. Tên hàm và tên tham số app gửi lên phải đúng danh sách [expectedCalls]; cùng danh sách này được
///     database kiểm bằng database/tests/80_app_contract_exercises.sql. Hai bên cùng khớp danh sách thì khớp nhau.
dynamic fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

/// hàm database -> danh sách tên tham số (đã sắp xếp). Hàm không tham số thì để rỗng.
const expectedCalls = <String, List<String>>{
  'add_bill_line': ['p_bill', 'p_qty', 'p_size'],
  'add_cash_movement': ['p_amount', 'p_direction', 'p_note'],
  'add_waste': ['p_ingredient', 'p_note', 'p_qty', 'p_type'],
  'bill_detail': ['p_bill'],
  'cancel_open_bill': ['p_bill', 'p_reason'],
  'close_shift': ['p_closing_cash'],
  'count_sheet': ['p_kind'],
  'current_shift': [],
  'ingredient_list': [],
  'mark_prep_done': ['p_bill'],
  'menu_for_sale': [],
  'open_bill': ['p_guests', 'p_table', 'p_type'],
  'open_shift': ['p_opening_cash'],
  'pay_bill': ['p_bill', 'p_method'],
  'set_bill_discount': ['p_bill', 'p_discount', 'p_reason'],
  'shift_close_status': [],
  'shop_info': [],
  'submit_stock_count': ['p_ingredient', 'p_kind', 'p_qty'],
  'table_map': [],
  'takeaway_orders': [],
  'void_bill_line': ['p_line', 'p_reason'],
  'waste_type_list': [],
};

void main() {
  late FakeRpcClient rpc;

  setUp(() {
    rpc = FakeRpcClient({
      'shop_info': fixture('shop_info'),
      'current_shift': fixture('current_shift'),
      'shift_close_status': fixture('shift_close_status'),
      'table_map': fixture('table_map'),
      'takeaway_orders': fixture('takeaway_orders'),
      'menu_for_sale': fixture('menu_for_sale'),
      'bill_detail': fixture('bill_detail'),
      'ingredient_list': fixture('ingredient_list'),
      'waste_type_list': fixture('waste_type_list'),
      'count_sheet': fixture('count_sheet_close'),
      // hàm ghi: trả giá trị đúng kiểu như PostgREST
      'open_shift': 'f3763ac2-9232-4742-bf0a-6990274e3993',
      'close_shift': null,
      'open_bill': 'af73c213-9d5e-4174-a36d-fd2d7b4fbc4a',
      'add_bill_line': 'x',
      'void_bill_line': null,
      'set_bill_discount': null,
      'cancel_open_bill': null,
      'pay_bill': 65000,
      'mark_prep_done': null,
      'submit_stock_count': 'x',
      'add_waste': 'x',
      'add_cash_movement': 'x',
    });
  });

  test('RPC session context khớp tên hàm, tham số và payload SQL', () {
    const expectedSessionRpc = <String, List<String>>{
      'my_session_context': ['p_preferred_shop'],
    };
    final dartSource = File(
      'lib/features/auth/data/supabase_auth_repository.dart',
    ).readAsStringSync();
    final migration =
        File('database/04_membership_sessions.sql').readAsStringSync();
    final contractSql =
        File('database/tests/86_session_context.sql').readAsStringSync();

    expect(dartSource, contains("'my_session_context',"));
    expect(dartSource, contains("'p_preferred_shop': preferredShopId"));
    expect(
      migration,
      contains('my_session_context(p_preferred_shop uuid default null)'),
    );
    expect(contractSql, contains('my_session_context(v_shop)'));
    expect(expectedSessionRpc.keys.single, 'my_session_context');
    expect(expectedSessionRpc.values.single, ['p_preferred_shop']);

    final decoded = SessionContext.fromMap({
      'account_kind': 'staff',
      'active_shop_id': 'shop-a',
      'pending_invite_count': 1,
      'shops': [
        {
          'shop_id': 'shop-a',
          'shop_name': 'Quán A',
          'staff_id': 'staff-a',
          'full_name': 'An',
          'role': 'owner',
          'active': true,
          'has_pin': true,
          'is_current': true,
        },
      ],
    });
    expect(decoded.currentShop?.role, StaffRole.owner);
    expect(decoded.pendingInviteCount, 1);
  });

  test('RPC biểu đồ doanh thu khớp migration và model', () {
    final source =
        File('lib/features/owner/data/owner_dashboard_repository.dart')
            .readAsStringSync();
    final migration =
        File('database/04_membership_sessions.sql').readAsStringSync();
    final sqlTest =
        File('database/tests/87_owner_sales_trend.sql').readAsStringSync();

    expect(source, contains("'owner_sales_trend'"));
    expect(source, contains("'p_business_start':"));
    expect(source, contains("'p_days': 7"));
    expect(
      migration,
      contains(
          'owner_sales_trend(\n  p_business_start timestamptz,\n  p_days integer default 7'),
    );
    expect(sqlTest, contains('owner_sales_trend(v_start, 7)'));

    final point = DailySalesPoint.fromMap({
      'business_start': '2026-10-30T23:00:00Z',
      'sales': 23000,
    });
    expect(point.sales, 23000);
    expect(point.businessStart.toUtc(), DateTime.utc(2026, 10, 30, 23));
  });

  group('đọc dữ liệu THẬT của database', () {
    test('hồ sơ quán và ca đang mở', () async {
      final shift = RpcOpsShiftRepository(rpc);
      final shop = await shift.shopInfo();
      expect(shop!.name, equals('Fore Nguyễn Du'));
      expect(shop.type, equals('drink'));
      expect(shop.servingLabel, equals('phần'));
      final s = await shift.currentShift();
      expect(s!.openedByName, equals('An'));
      expect(s.openedByMe, isTrue);
      final close = await shift.closeStatus();
      expect(close.openBills, equals(2)); // bill Bàn 2 và đơn mang đi chưa thu
      expect(
          close.missingCounts,
          equals(
              2)); // Cà phê và Ly chưa đếm cuối ca (Sữa đã đếm, Đường kiểm theo tuần)
      expect(close.ready, isFalse);
    });

    test('chưa mở ca: current_shift trả mảng rỗng thì là null', () async {
      final shift =
          RpcOpsShiftRepository(FakeRpcClient({'current_shift': <dynamic>[]}));
      expect(await shift.currentShift(), isNull);
    });

    test('bản đồ bàn: thứ tự tự nhiên, bàn đang dùng có bill và số phần',
        () async {
      final slots = await RpcSalesRepository(rpc).tableMap();
      expect(slots.map((s) => s.tableName).toList(),
          equals(['Bàn 1', 'Bàn 2', 'Bàn 10', 'Sân 1']));
      expect(slots.map((s) => s.areaName).toList(),
          equals(['Tầng 1', 'Tầng 1', 'Tầng 1', 'Sân']));
      final t2 = slots[1];
      expect(t2.isBusy, isTrue);
      expect(t2.portions,
          equals(3)); // 2 cà phê + 1 bánh mì; dòng đã bỏ không tính
      expect(t2.guests, equals(2));
      expect(t2.billNo, equals(1));
      expect(t2.billOpenedAt, isNotNull);
      expect(slots[0].isBusy, isFalse);
      expect(slots[0].portions, equals(0));
    });

    test('đơn mang đi: cũ nhất trước, đã thu vẫn hiện, tên món theo thứ tự gọi',
        () async {
      final orders = await RpcSalesRepository(rpc).takeawayOrders();
      expect(orders, hasLength(2));
      expect(orders[0].items, equals('Bánh mì trứng, Cà phê sữa'));
      expect(orders[0].portions, equals(2));
      expect(orders[0].status, equals(BillStatus.open));
      expect(orders[1].items, equals('Cà phê sữa'));
      expect(orders[1].isPaid, isTrue);
      expect(orders[1].billNo, greaterThan(orders[0].billNo));
    });

    test('thực đơn: nhóm "Ăn nhẹ" trước, món không nhóm sau, size gộp theo món',
        () async {
      final menu = await RpcSalesRepository(rpc).menu();
      expect(menu.map((m) => m.name).toList(),
          equals(['Bánh mì trứng', 'Cà phê sữa']));
      expect(menu[0].group, equals('Ăn nhẹ'));
      expect(menu[1].group, isNull);
      expect(menu[1].sizes.map((s) => '${s.name}:${s.price}').toList(),
          equals(['M:25000', 'L:30000']));
    });

    test('chi tiết bill: tiền do database tính, dòng đã bỏ được đánh dấu',
        () async {
      final bill = await RpcSalesRepository(rpc)
          .bill('af73c213-9d5e-4174-a36d-fd2d7b4fbc4a');
      expect(bill.title, equals('Bàn 2'));
      expect(bill.areaName, equals('Tầng 1'));
      expect(bill.isOpen, isTrue);
      expect(bill.lines, hasLength(3));
      expect(bill.activeLines, hasLength(2));
      expect(bill.portions, equals(3));
      expect(bill.subtotal, equals(70000));
      expect(bill.discount, equals(5000));
      expect(bill.discountReason, equals('khách quen'));
      expect(bill.payable, equals(65000));
      expect(bill.lines.last.voided, isTrue);
      expect(bill.lines.first.total, equals(50000));
    });

    test(
        'phiếu kiểm kê: quan trọng trước, theo tuần sau cùng, chỉ có cờ "đã đếm"',
        () async {
      final items = await RpcStocktakeRepository(rpc).sheet(CountKind.close);
      expect(items.map((i) => i.name).toList(),
          equals(['Cà phê', 'Sữa', 'Ly', 'Đường']));
      expect(items.map((i) => i.counted).toList(),
          equals([false, true, false, false]));
      expect(items.last.weekly, isTrue);
      expect(items.first.important, isTrue);
    });

    test('danh mục nhập hàng và loại hao hụt', () async {
      final inv = RpcInventoryRepository(rpc);
      final ings = await inv.ingredients();
      expect(ings.map((i) => i.name).toSet(),
          equals({'Sữa', 'Cà phê', 'Đường', 'Ly'}));
      expect(ings.firstWhere((i) => i.name == 'Ly').unitLabel, equals('cái'));
      final types = await inv.wasteTypes();
      expect(types.map((t) => t.code).toSet(), containsAll(['other']));
      expect(types.where((t) => t.requiresNote), hasLength(1));
    });
  });

  group('app gọi đúng tên hàm và tên tham số của database', () {
    test('mọi lệnh gọi khớp danh sách hợp đồng, không thừa, không thiếu',
        () async {
      final shift = RpcOpsShiftRepository(rpc);
      final sales = RpcSalesRepository(rpc);
      final stock = RpcStocktakeRepository(rpc);
      final inv = RpcInventoryRepository(rpc);

      await shift.shopInfo();
      await shift.currentShift();
      await shift.openShift(500000);
      await shift.closeStatus();
      await shift.closeShift(1250000);
      await sales.tableMap();
      await sales.takeawayOrders();
      await sales.menu();
      await sales.bill('b');
      await sales.openBill(tableId: 't', type: BillType.dineIn, guests: 2);
      await sales.addLine('b', 's', 2);
      await sales.voidLine('l', 'x');
      await sales.setDiscount('b', 1000, 'x');
      await sales.cancelOpenBill('b', 'x');
      await sales.pay('b', PaymentMethod.cash);
      await sales.markPrepDone('b');
      await stock.sheet(CountKind.close);
      await stock.submit('i', CountKind.close, 5);
      await inv.ingredients();
      await inv.wasteTypes();
      await inv.addWaste(ingredientId: 'i', qty: 5, typeCode: 'expired');
      await inv.addMovement(incoming: false, amount: 1000, note: 'đá');

      final used = <String, List<String>>{};
      for (final c in rpc.calls) {
        used[c.fn] = [...?c.params?.keys]..sort();
      }
      expect(used.keys.toList()..sort(),
          equals(expectedCalls.keys.toList()..sort()));
      for (final fn in expectedCalls.keys) {
        expect(used[fn], equals(expectedCalls[fn]), reason: 'tham số của $fn');
      }
    });

    test('giá trị gửi đi đúng kiểu và đúng chuỗi mà database chấp nhận',
        () async {
      final sales = RpcSalesRepository(rpc);
      await sales.openBill(type: BillType.takeAway);
      await sales.pay('b', PaymentMethod.transfer);
      await RpcStocktakeRepository(rpc).sheet(CountKind.open);
      await RpcInventoryRepository(rpc)
          .addMovement(incoming: true, amount: 5, note: '   ');
      final byFn = {for (final c in rpc.calls) c.fn: c.params};
      expect(byFn['open_bill'],
          equals({'p_table': null, 'p_type': 'take_away', 'p_guests': null}));
      expect(byFn['pay_bill'], equals({'p_bill': 'b', 'p_method': 'transfer'}));
      expect(byFn['count_sheet'], equals({'p_kind': 'open'}));
      expect(byFn['add_cash_movement'],
          equals({'p_direction': 'in', 'p_amount': 5, 'p_note': null}));
    });
  });
}
