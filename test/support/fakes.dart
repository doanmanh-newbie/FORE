import 'dart:async';

import 'package:fore/core/data/rpc_client.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/inventory/domain/inventory_models.dart';
import 'package:fore/features/inventory/domain/inventory_repository.dart';
import 'package:fore/features/sales/domain/sales_models.dart';
import 'package:fore/features/sales/domain/sales_repository.dart';
import 'package:fore/features/shift/operations/domain/ops_shift_models.dart';
import 'package:fore/features/shift/operations/domain/ops_shift_repository.dart';
import 'package:fore/features/stocktake/domain/stocktake_models.dart';
import 'package:fore/features/stocktake/domain/stocktake_repository.dart';

/// Cơ chế chung của các bản giả: ghi lại lệnh gọi, cho phép "hẹn" lỗi ở lần gọi kế tiếp,
/// và cho phép giữ một lệnh gọi lại (gate) để thử bấm đúp / hủy màn hình giữa chừng.
mixin FakeBase {
  final List<String> calls = [];
  final Map<String, AppFailure> _failures = {};
  Completer<void>? gate;

  /// Lần gọi tiếp theo của `method` sẽ ném lỗi này (một lần).
  void failNext(String method, AppFailure failure) =>
      _failures[method] = failure;

  final Map<String, int> _callNumbers = {};
  final Map<String, (int, AppFailure)> _failOnNth = {};

  /// Lần gọi THỨ `nth` (tính từ 1, kể từ lúc hẹn) của `method` sẽ ném lỗi này. Dùng để làm hỏng đúng
  /// một lệnh ở giữa chuỗi nhiều lệnh.
  void failOnCall(String method, int nth, AppFailure failure) {
    _callNumbers[method] = 0;
    _failOnNth[method] = (nth, failure);
  }

  Future<void> enter(String method, [String detail = '']) async {
    calls.add(detail.isEmpty ? method : '$method:$detail');
    final g = gate;
    if (g != null) await g.future;
    final f = _failures.remove(method);
    if (f != null) throw f;
    final nth = _failOnNth[method];
    if (nth != null) {
      final n = (_callNumbers[method] ?? 0) + 1;
      _callNumbers[method] = n;
      if (n == nth.$1) {
        _failOnNth.remove(method);
        throw nth.$2;
      }
    }
  }

  int count(String method) =>
      calls.where((c) => c == method || c.startsWith('$method:')).length;
}

class FakeShiftRepository with FakeBase implements OpsShiftRepository {
  ShopInfo? shop = const ShopInfo(
      name: 'Fore Nguyễn Du', type: 'drink', servingLabel: 'phần');
  OpsCurrentShift? shift;
  CloseStatus status = const CloseStatus(openBills: 0, missingCounts: 0);

  @override
  Future<ShopInfo?> shopInfo() async {
    await enter('shopInfo');
    return shop;
  }

  @override
  Future<OpsCurrentShift?> currentShift() async {
    await enter('currentShift');
    return shift;
  }

  @override
  Future<void> openShift(int openingCash) async {
    await enter('openShift', '$openingCash');
    shift = OpsCurrentShift(
      id: 's1',
      openedAt: DateTime(2026, 10, 23, 8, 2),
      openedByName: 'An',
      openedByMe: true,
    );
  }

  @override
  Future<CloseStatus> closeStatus() async {
    await enter('closeStatus');
    return status;
  }

  @override
  Future<void> closeShift(int closingCash) async {
    await enter('closeShift', '$closingCash');
    shift = null;
  }
}

/// Mô phỏng các quy tắc tính tiền của database: tổng = các dòng chưa bỏ; phải thu = tổng - giảm giá (không âm).
class FakeSalesRepository with FakeBase implements SalesRepository {
  List<TableSlot> tables = [];
  List<TakeawayOrder> takeaways = [];
  List<MenuItemEntry> menuItems = [];

  String billId = 'b1';
  BillStatus status = BillStatus.open;
  BillType type = BillType.dineIn;
  int discount = 0;
  String? discountReason;
  String? paymentMethod;
  final List<BillLine> lines = [];
  int _lineSeq = 0;
  int _billSeq = 100;

  int _sizePrice(String sizeId) {
    for (final item in menuItems) {
      for (final size in item.sizes) {
        if (size.id == sizeId) return size.price;
      }
    }
    throw StateError('Không có size $sizeId trong thực đơn giả');
  }

  String _sizeName(String sizeId) {
    for (final item in menuItems) {
      for (final size in item.sizes) {
        if (size.id == sizeId) return size.name;
      }
    }
    return '?';
  }

  String _itemName(String sizeId) {
    for (final item in menuItems) {
      for (final size in item.sizes) {
        if (size.id == sizeId) return item.name;
      }
    }
    return '?';
  }

  int get subtotal =>
      lines.where((l) => !l.voided).fold(0, (s, l) => s + l.total);

  @override
  Future<List<TableSlot>> tableMap() async {
    await enter('tableMap');
    return List.of(tables);
  }

  @override
  Future<List<TakeawayOrder>> takeawayOrders() async {
    await enter('takeawayOrders');
    return List.of(takeaways);
  }

  @override
  Future<List<MenuItemEntry>> menu() async {
    await enter('menu');
    return List.of(menuItems);
  }

  @override
  Future<BillView> bill(String id) async {
    await enter('bill', id);
    final payable = status == BillStatus.open
        ? (subtotal - discount).clamp(0, 1 << 40)
        : (subtotal - discount);
    return BillView(
      id: billId,
      billNo: 84,
      status: status,
      type: type,
      tableName: type == BillType.dineIn ? 'Bàn 2' : null,
      areaName: type == BillType.dineIn ? 'Tầng 1' : null,
      guests: 2,
      openedAt: DateTime(2026, 10, 23, 8, 16),
      discount: discount,
      discountReason: discountReason,
      paymentMethod: paymentMethod,
      prepDone: false,
      lines: List.of(lines),
      subtotal: subtotal,
      payable: payable,
    );
  }

  @override
  Future<String> openBill(
      {String? tableId, required BillType type, int? guests}) async {
    await enter('openBill', '${tableId ?? '-'}:${type.wire}:${guests ?? '-'}');
    return 'b${_billSeq++}';
  }

  @override
  Future<void> addLine(String id, String sizeId, int qty) async {
    await enter('addLine', '$id:$sizeId:$qty');
    lines.add(BillLine(
      id: 'l${_lineSeq++}',
      sizeId: sizeId,
      itemName: _itemName(sizeId),
      sizeName: _sizeName(sizeId),
      qty: qty,
      unitPrice: _sizePrice(sizeId),
      voided: false,
    ));
  }

  @override
  Future<void> voidLine(String lineId, String reason) async {
    await enter('voidLine', '$lineId:$reason');
    final i = lines.indexWhere((l) => l.id == lineId);
    if (i < 0) throw const DatabaseFailure('NOT_FOUND');
    if (lines[i].voided) throw const DatabaseFailure('LINE_ALREADY_VOIDED');
    final l = lines[i];
    lines[i] = BillLine(
      id: l.id,
      sizeId: l.sizeId,
      itemName: l.itemName,
      sizeName: l.sizeName,
      qty: l.qty,
      unitPrice: l.unitPrice,
      voided: true,
    );
  }

  @override
  Future<void> setDiscount(String id, int amount, String reason) async {
    await enter('setDiscount', '$id:$amount:$reason');
    discount = amount;
    discountReason = reason;
  }

  @override
  Future<void> cancelOpenBill(String id, String reason) async {
    await enter('cancelOpenBill', '$id:$reason');
    status = BillStatus.cancelled;
  }

  @override
  Future<int> pay(String id, PaymentMethod method) async {
    await enter('pay', '$id:${method.wire}');
    final total = (subtotal - discount).clamp(0, 1 << 40);
    status = BillStatus.paid;
    paymentMethod = method.wire;
    return total;
  }

  @override
  Future<void> markPrepDone(String id) async {
    await enter('markPrepDone', id);
    takeaways = [
      for (final o in takeaways)
        if (o.billId != id) o
    ];
  }

  List<PaidBill> paid = [];
  String cancelResult = 'OK';

  @override
  Future<List<PaidBill>> paidBills() async {
    await enter('paidBills');
    return List.of(paid);
  }

  @override
  Future<String> cancelPaidBill(String id, String ownerPin, String reason) async {
    await enter('cancelPaidBill', '$id:$ownerPin:$reason');
    if (cancelResult == 'OK') paid = [for (final b in paid) if (b.billId != id) b];
    return cancelResult;
  }
}

class FakeStocktakeRepository with FakeBase implements StocktakeRepository {
  List<CountItem> items = [];
  final List<String> saved = [];

  @override
  Future<List<CountItem>> sheet(CountKind kind) async {
    await enter('sheet', kind.wire);
    return List.of(items);
  }

  @override
  Future<void> submit(String ingredientId, CountKind kind, int qty) async {
    await enter('submit', '$ingredientId:${kind.wire}:$qty');
    saved.add('$ingredientId=$qty');
    items = [for (final i in items) i.id == ingredientId ? i.markCounted() : i];
  }
}

class FakeInventoryRepository
    with FakeBase
    implements InventoryRepository, CashRepository {
  List<IngredientOption> ingredientOptions = [];
  List<WasteTypeOption> wasteTypeOptions = [];

  @override
  Future<List<IngredientOption>> ingredients() async {
    await enter('ingredients');
    return List.of(ingredientOptions);
  }

  @override
  Future<List<WasteTypeOption>> wasteTypes() async {
    await enter('wasteTypes');
    return List.of(wasteTypeOptions);
  }

  @override
  Future<void> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
  }) =>
      enter('addWaste', '$ingredientId:$qty:$typeCode:${note ?? ''}');

  @override
  Future<void> addMovement(
          {required bool incoming, required int amount, String? note}) =>
      enter('addMovement', '${incoming ? 'in' : 'out'}:$amount:${note ?? ''}');
}

/// RpcClient giả: trả về dữ liệu đã dựng sẵn theo tên hàm và ghi lại (hàm, tham số) để kiểm tên tham số.
class FakeRpcClient implements RpcClient {
  FakeRpcClient(this.responses);

  final Map<String, dynamic> responses;
  final List<({String fn, Map<String, dynamic>? params})> calls = [];

  @override
  Future<dynamic> call(String fn, [Map<String, dynamic>? params]) async {
    calls.add((fn: fn, params: params));
    if (!responses.containsKey(fn)) {
      throw StateError('FakeRpcClient: chưa dựng dữ liệu cho "$fn"');
    }
    final r = responses[fn];
    if (r is AppFailure) throw r;
    return r;
  }
}

// ---------------------------------------------------------------- dữ liệu mẫu
TableSlot slot(String name,
        {String area = 'a1',
        String areaName = 'Tầng 1',
        String? bill,
        int portions = 0}) =>
    TableSlot(
      areaId: area,
      areaName: areaName,
      tableId: 't-$name',
      tableName: name,
      billId: bill,
      billNo: bill == null ? null : 84,
      portions: portions,
    );

const sizeM = MenuSizeOption(id: 'cf-m', name: 'M', price: 25000);
const sizeL = MenuSizeOption(id: 'cf-l', name: 'L', price: 30000);
const sizeBm = MenuSizeOption(id: 'bm-1', name: 'Phần', price: 20000);

const sampleMenu = [
  MenuItemEntry(
      id: 'bm', name: 'Bánh mì trứng', group: 'Ăn nhẹ', sizes: [sizeBm]),
  MenuItemEntry(
      id: 'cf', name: 'Cà phê sữa', group: null, sizes: [sizeM, sizeL]),
];

TakeawayOrder order(String id, int no,
        {BillStatus status = BillStatus.open,
        int portions = 1,
        String items = 'Cà phê'}) =>
    TakeawayOrder(
      billId: id,
      billNo: no,
      status: status,
      openedAt: DateTime(2026, 10, 23, 8, 10 + no),
      portions: portions,
      items: items,
    );

CountItem countItem(String id,
        {bool counted = false, bool weekly = false, bool important = true}) =>
    CountItem(
      id: id,
      name: 'NL $id',
      unit: 'ml',
      important: important,
      weekly: weekly,
      group: null,
      counted: counted,
    );
