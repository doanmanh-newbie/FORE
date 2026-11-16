import '../../../core/data/json_row.dart';
import '../../../core/data/rpc_client.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';

class RpcSalesRepository implements SalesRepository {
  RpcSalesRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<List<TableSlot>> tableMap() => _parse(() async => [
        for (final r in asRows(await _rpc.call('table_map')))
          TableSlot.fromRow(r),
      ]);

  @override
  Future<List<TakeawayOrder>> takeawayOrders() => _parse(() async => [
        for (final r in asRows(await _rpc.call('takeaway_orders')))
          TakeawayOrder.fromRow(r),
      ]);

  @override
  Future<List<MenuItemEntry>> menu() => _parse(
      () async => groupMenuRows(asRows(await _rpc.call('menu_for_sale'))));

  @override
  Future<BillView> bill(String billId) => _parse(() async => BillView.fromJson(
      asObject(await _rpc.call('bill_detail', {'p_bill': billId}))));

  @override
  Future<String> openBill(
          {String? tableId, required BillType type, int? guests}) =>
      _parse(() async {
        final id = await _rpc.call('open_bill', {
          'p_table': tableId,
          'p_type': type.wire,
          'p_guests': guests,
        });
        if (id is! String) {
          throw FormatException('open_bill cần trả mã bill, nhận: $id');
        }
        return id;
      });

  @override
  Future<void> addLine(String billId, String sizeId, int qty) async {
    await _rpc.call(
        'add_bill_line', {'p_bill': billId, 'p_size': sizeId, 'p_qty': qty});
  }

  @override
  Future<void> voidLine(String lineId, String reason) async {
    await _rpc.call('void_bill_line', {'p_line': lineId, 'p_reason': reason});
  }

  @override
  Future<void> setDiscount(String billId, int discount, String reason) async {
    await _rpc.call('set_bill_discount', {
      'p_bill': billId,
      'p_discount': discount,
      'p_reason': reason,
    });
  }

  @override
  Future<void> cancelOpenBill(String billId, String reason) async {
    await _rpc.call('cancel_open_bill', {'p_bill': billId, 'p_reason': reason});
  }

  @override
  Future<int> pay(String billId, PaymentMethod method) => _parse(() async {
        final total = await _rpc
            .call('pay_bill', {'p_bill': billId, 'p_method': method.wire});
        if (total is! int) {
          throw FormatException('pay_bill cần trả số tiền, nhận: $total');
        }
        return total;
      });

  @override
  Future<void> markPrepDone(String billId) async {
    await _rpc.call('mark_prep_done', {'p_bill': billId});
  }

  @override
  Future<List<PaidBill>> paidBills() => _parse(() async => [
        for (final r in asRows(await _rpc.call('paid_bills')))
          PaidBill.fromRow(r),
      ]);

  @override
  Future<String> cancelPaidBill(
          String billId, String ownerPin, String reason) =>
      _parse(() async {
        final result = await _rpc.call('cancel_paid_bill',
            {'p_bill': billId, 'p_owner_pin': ownerPin, 'p_reason': reason});
        if (result is! String) {
          throw FormatException(
              'cancel_paid_bill cần trả mã kết quả, nhận: $result');
        }
        return result;
      });

  Future<T> _parse<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }
}
