import 'sales_models.dart';

/// Mọi thao tác bán hàng. Số tiền và quy tắc do database quyết định; app chỉ gọi và hiển thị.
abstract interface class SalesRepository {
  Future<List<TableSlot>> tableMap();

  Future<List<TakeawayOrder>> takeawayOrders();

  Future<List<MenuItemEntry>> menu();

  Future<BillView> bill(String billId);

  /// Mở bill mới. Ăn tại quán cần `tableId`; mang đi thì để `null`. Trả mã bill.
  Future<String> openBill(
      {String? tableId, required BillType type, int? guests, String? requestId});

  Future<void> addLine(String billId, String sizeId, int qty, {String? requestId});

  Future<void> voidLine(String lineId, String reason);

  Future<void> setDiscount(String billId, int discount, String reason);

  Future<void> cancelOpenBill(String billId, String reason);

  /// Thu tiền và chốt bill. Trả số tiền đã thu.
  Future<int> pay(String billId, PaymentMethod method, {String? requestId});

  Future<void> markPrepDone(String billId);
}
