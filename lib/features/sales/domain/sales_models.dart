import '../../../core/data/json_row.dart';

enum BillStatus {
  open,
  paid,
  cancelled;

  static BillStatus parse(String value) => switch (value) {
        'open' => BillStatus.open,
        'paid' => BillStatus.paid,
        'cancelled' => BillStatus.cancelled,
        _ => throw FormatException('Trạng thái bill lạ: $value'),
      };
}

enum BillType {
  dineIn('dine_in'),
  takeAway('take_away');

  const BillType(this.wire);

  /// Giá trị database dùng.
  final String wire;

  static BillType parse(String value) => values.firstWhere(
        (t) => t.wire == value,
        orElse: () => throw FormatException('Loại bill lạ: $value'),
      );
}

enum PaymentMethod {
  cash('cash', 'Tiền mặt'),
  transfer('transfer', 'Chuyển khoản');

  const PaymentMethod(this.wire, this.label);

  final String wire;
  final String label;
}

/// "#084": số bill hiển thị 3 chữ số.
String formatBillNo(int billNo) => '#${billNo.toString().padLeft(3, '0')}';

/// Một bàn trên bản đồ; nếu đang có khách thì kèm bill đang mở của bàn.
class TableSlot {
  const TableSlot({
    required this.areaId,
    required this.areaName,
    required this.tableId,
    required this.tableName,
    this.billId,
    this.billNo,
    this.portions = 0,
    this.guests,
    this.billOpenedAt,
  });

  factory TableSlot.fromRow(Map<String, dynamic> row) => TableSlot(
        areaId: row.str('area_id'),
        areaName: row.str('area_name'),
        tableId: row.str('table_id'),
        tableName: row.str('table_name'),
        billId: row.strOrNull('bill_id'),
        billNo: row.intOrNull('bill_no'),
        portions: row.intOrNull('portions') ?? 0,
        guests: row.intOrNull('guests'),
        billOpenedAt: row.timeOrNull('bill_opened_at'),
      );

  final String areaId;
  final String areaName;
  final String tableId;
  final String tableName;
  final String? billId;
  final int? billNo;
  final int portions;
  final int? guests;
  final DateTime? billOpenedAt;

  bool get isBusy => billId != null;
}

/// Các bàn của một khu, giữ nguyên thứ tự database trả về.
class AreaGroup {
  const AreaGroup({required this.id, required this.name, required this.tables});

  final String id;
  final String name;
  final List<TableSlot> tables;

  int get busyCount => tables.where((t) => t.isBusy).length;
}

/// Đơn mang đi chưa làm xong (đã thu tiền hay chưa đều nằm trong danh sách này).
class TakeawayOrder {
  const TakeawayOrder({
    required this.billId,
    required this.billNo,
    required this.status,
    required this.openedAt,
    required this.portions,
    required this.items,
  });

  factory TakeawayOrder.fromRow(Map<String, dynamic> row) => TakeawayOrder(
        billId: row.str('bill_id'),
        billNo: row.integer('bill_no'),
        status: BillStatus.parse(row.str('status')),
        openedAt: row.time('opened_at'),
        portions: row.integer('portions'),
        items: row.str('items'),
      );

  final String billId;
  final int billNo;
  final BillStatus status;
  final DateTime openedAt;
  final int portions;
  final String items;

  bool get isPaid => status == BillStatus.paid;
}

class MenuSizeOption {
  const MenuSizeOption(
      {required this.id, required this.name, required this.price});

  final String id;
  final String name;
  final int price;
}

class MenuItemEntry {
  const MenuItemEntry({
    required this.id,
    required this.name,
    required this.group,
    required this.sizes,
  });

  final String id;
  final String name;
  final String? group;
  final List<MenuSizeOption> sizes;
}

/// Gộp các dòng phẳng của `menu_for_sale()` thành danh sách món, mỗi món có nhiều size.
/// Giữ nguyên thứ tự database trả về.
List<MenuItemEntry> groupMenuRows(List<Map<String, dynamic>> rows) {
  final order = <String>[];
  final names = <String, String>{};
  final groups = <String, String?>{};
  final sizes = <String, List<MenuSizeOption>>{};
  for (final row in rows) {
    final itemId = row.str('item_id');
    if (!sizes.containsKey(itemId)) {
      order.add(itemId);
      names[itemId] = row.str('item_name');
      groups[itemId] = row.strOrNull('group_name');
      sizes[itemId] = [];
    }
    sizes[itemId]!.add(MenuSizeOption(
      id: row.str('size_id'),
      name: row.str('size_name'),
      price: row.integer('price'),
    ));
  }
  return [
    for (final id in order)
      MenuItemEntry(
          id: id, name: names[id]!, group: groups[id], sizes: sizes[id]!),
  ];
}

class BillLine {
  const BillLine({
    required this.id,
    required this.sizeId,
    required this.itemName,
    required this.sizeName,
    required this.qty,
    required this.unitPrice,
    required this.voided,
  });

  factory BillLine.fromJson(Map<String, dynamic> row) => BillLine(
        id: row.str('id'),
        sizeId: row.str('size_id'),
        itemName: row.str('item_name'),
        sizeName: row.str('size_name'),
        qty: row.integer('qty'),
        unitPrice: row.integer('unit_price'),
        voided: row.flag('voided'),
      );

  final String id;
  final String sizeId;
  final String itemName;
  final String sizeName;
  final int qty;
  final int unitPrice;
  final bool voided;

  int get total => qty * unitPrice;
}

/// Một bill đầy đủ. Số tiền do database tính (`subtotal`, `payable`); app chỉ hiển thị.
class BillView {
  const BillView({
    required this.id,
    required this.billNo,
    required this.status,
    required this.type,
    required this.tableName,
    required this.areaName,
    required this.guests,
    required this.openedAt,
    required this.discount,
    required this.discountReason,
    required this.paymentMethod,
    required this.prepDone,
    required this.lines,
    required this.subtotal,
    required this.payable,
    this.tenderedAmount,
    this.paymentRef,
    this.cancelledAt,
    this.cancelReason,
  });

  factory BillView.fromJson(Map<String, dynamic> json) => BillView(
        id: json.str('id'),
        billNo: json.integer('bill_no'),
        status: BillStatus.parse(json.str('status')),
        type: BillType.parse(json.str('bill_type')),
        tableName: json.strOrNull('table_name'),
        areaName: json.strOrNull('area_name'),
        guests: json.intOrNull('guests'),
        openedAt: json.time('opened_at'),
        discount: json.integer('discount'),
        discountReason: json.strOrNull('discount_reason'),
        paymentMethod: json.strOrNull('payment_method'),
        prepDone: json.flag('prep_done'),
        lines: [
          for (final l in asRows(json['lines'])) BillLine.fromJson(l),
        ],
        subtotal: json.integer('subtotal'),
        payable: json.integer('payable'),
        tenderedAmount: json.intOrNull('tendered_amount'),
        paymentRef: json.strOrNull('payment_ref'),
        cancelledAt: json['cancelled_at'] != null ? json.time('cancelled_at') : null,
        cancelReason: json.strOrNull('cancel_reason'),
      );

  final String id;
  final int billNo;
  final BillStatus status;
  final BillType type;
  final String? tableName;
  final String? areaName;
  final int? guests;
  final DateTime openedAt;
  final int discount;
  final String? discountReason;
  final String? paymentMethod;
  final bool prepDone;
  final List<BillLine> lines;
  final int subtotal;
  final int payable;
  final int? tenderedAmount;
  final String? paymentRef;
  final DateTime? cancelledAt;
  final String? cancelReason;

  bool get isOpen => status == BillStatus.open;
  List<BillLine> get activeLines => [
        for (final l in lines)
          if (!l.voided) l
      ];
  int get portions => activeLines.fold(0, (sum, l) => sum + l.qty);

  String get title => type == BillType.takeAway
      ? 'Mang đi ${formatBillNo(billNo)}'
      : (tableName ?? 'Bill ${formatBillNo(billNo)}');
}

/// Thông tin chuyển khoản / QR ngân hàng của quán
class PaymentQrInfo {
  const PaymentQrInfo({
    required this.configured,
    this.bankCode,
    this.accountNo,
    this.accountName,
    this.contentPrefix = 'FORE',
  });

  factory PaymentQrInfo.fromRow(Map<String, dynamic> row) => PaymentQrInfo(
        configured: row.flag('configured'),
        bankCode: row.strOrNull('bank_code'),
        accountNo: row.strOrNull('account_no'),
        accountName: row.strOrNull('account_name'),
        contentPrefix: row.strOrNull('content_prefix') ?? 'FORE',
      );

  final bool configured;
  final String? bankCode;
  final String? accountNo;
  final String? accountName;
  final String contentPrefix;

  /// Tạo link mã VietQR chuẩn theo thông tin hóa đơn
  String? makeQrUrl({required int billNo, required int amount}) {
    if (!configured || bankCode == null || accountNo == null) return null;
    final content = Uri.encodeComponent('$contentPrefix BILL$billNo');
    return 'https://img.vietqr.io/image/$bankCode-$accountNo-compact2.png?amount=$amount&addInfo=$content&accountName=${Uri.encodeComponent(accountName ?? '')}';
  }
}

/// Tóm tắt một hóa đơn trong ca (dùng cho danh sách lịch sử)
class ShiftBillSummary {
  const ShiftBillSummary({
    required this.billId,
    required this.billNo,
    required this.billType,
    required this.status,
    this.tableName,
    this.areaName,
    required this.portions,
    this.totalAmount,
    this.paymentMethod,
    this.paymentRef,
    required this.openedAt,
    this.paidAt,
    this.cancelledAt,
    this.cancelReason,
  });

  factory ShiftBillSummary.fromRow(Map<String, dynamic> row) => ShiftBillSummary(
        billId: row.str('bill_id'),
        billNo: row.integer('bill_no'),
        billType: BillType.parse(row.str('bill_type')),
        status: BillStatus.parse(row.str('status')),
        tableName: row.strOrNull('table_name'),
        areaName: row.strOrNull('area_name'),
        portions: row.integer('portions'),
        totalAmount: row.intOrNull('total_amount'),
        paymentMethod: row.strOrNull('payment_method'),
        paymentRef: row.strOrNull('payment_ref'),
        openedAt: row.time('opened_at'),
        paidAt: row['paid_at'] != null ? row.time('paid_at') : null,
        cancelledAt: row['cancelled_at'] != null ? row.time('cancelled_at') : null,
        cancelReason: row.strOrNull('cancel_reason'),
      );

  final String billId;
  final int billNo;
  final BillType billType;
  final BillStatus status;
  final String? tableName;
  final String? areaName;
  final int portions;
  final int? totalAmount;
  final String? paymentMethod;
  final String? paymentRef;
  final DateTime openedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final String? cancelReason;

  String get title => billType == BillType.takeAway
      ? 'Mang đi ${formatBillNo(billNo)}'
      : (tableName ?? 'Bill ${formatBillNo(billNo)}');
}
