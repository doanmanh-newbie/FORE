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
  Future<List<ModifierGroup>> modifiers() => _parse(
      () async => groupModifierRows(asRows(await _rpc.call('menu_modifiers'))));

  @override
  Future<void> setItemSoldOut({
    required String itemId,
    required bool soldOut,
    String? reason,
  }) async {
    final params = <String, dynamic>{
      'p_item': itemId,
      'p_sold_out': soldOut,
    };
    if (reason != null && reason.trim().isNotEmpty) {
      params['p_reason'] = reason.trim();
    }
    await _rpc.call('set_item_sold_out', params);
  }

  @override
  Future<BillView> bill(String billId) => _parse(() async => BillView.fromJson(
      asObject(await _rpc.call('bill_detail', {'p_bill': billId}))));

  @override
  Future<String> openBill(
          {String? tableId, required BillType type, int? guests, String? requestId}) =>
      _parse(() async {
        final params = <String, dynamic>{
          'p_table': tableId,
          'p_type': type.wire,
          'p_guests': guests,
        };
        if (requestId != null) params['p_request_id'] = requestId;
        final id = await _rpc.call('open_bill', params);
        if (id is! String) {
          throw FormatException('open_bill cần trả mã bill, nhận: $id');
        }
        return id;
      });

  @override
  Future<void> addLine(
    String billId,
    String sizeId,
    int qty, {
    String? requestId,
    List<String>? options,
    String? note,
  }) async {
    final params = <String, dynamic>{
      'p_bill': billId,
      'p_size': sizeId,
      'p_qty': qty,
    };
    if (requestId != null) params['p_request_id'] = requestId;
    if (options != null && options.isNotEmpty) params['p_options'] = options;
    if (note != null && note.trim().isNotEmpty) params['p_note'] = note.trim();
    await _rpc.call('add_bill_line', params);
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
  Future<int> pay(
    String billId,
    PaymentMethod method, {
    String? requestId,
    int? tendered,
    String? paymentRef,
  }) =>
      _parse(() async {
        final params = <String, dynamic>{
          'p_bill': billId,
          'p_method': method.wire,
        };
        if (requestId != null) params['p_request_id'] = requestId;
        if (tendered != null) params['p_tendered'] = tendered;
        if (paymentRef != null && paymentRef.trim().isNotEmpty) {
          params['p_ref'] = paymentRef.trim();
        }
        final total = await _rpc.call('pay_bill', params);
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
  Future<PaymentQrInfo> paymentQrInfo() => _parse(() async {
        final rows = asRows(await _rpc.call('payment_qr_info'));
        if (rows.isEmpty) return const PaymentQrInfo(configured: false);
        return PaymentQrInfo.fromRow(rows.first);
      });

  @override
  Future<List<ShiftBillSummary>> shiftBills({int limit = 50, DateTime? before}) =>
      _parse(() async {
        final params = <String, dynamic>{'p_limit': limit};
        if (before != null) params['p_before'] = before.toIso8601String();
        final rows = asRows(await _rpc.call('shift_bills', params));
        return [for (final r in rows) ShiftBillSummary.fromRow(r)];
      });

  @override
  Future<bool> hasOwnerPin() => _parse(() async {
        final res = await _rpc.call('owner_pin_status');
        return res is bool ? res : false;
      });

  @override
  Future<String> cancelPaidBill({
    required String billId,
    required String ownerPin,
    required String reason,
  }) =>
      _parse(() async {
        final res = await _rpc.call('cancel_paid_bill', {
          'p_bill': billId,
          'p_owner_pin': ownerPin,
          'p_reason': reason,
        });
        return res is String ? res : 'UNKNOWN';
      });

  Future<T> _parse<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }
}
