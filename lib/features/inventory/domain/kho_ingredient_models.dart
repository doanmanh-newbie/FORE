part of 'kho_models.dart';

// ---------- Nguyên liệu ----------
class CatalogItem {
  const CatalogItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.active,
    required this.stock,
    required this.minStock,
    required this.status,
    required this.menuItemCount,
    this.group,
    this.unitCost,
    this.value,
    this.daysLeft,
    this.supplierId,
    this.supplierName,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        group: _strOrNull(j, 'group_name'),
        unit: _str(j, 'unit'),
        active: j['active'] != false,
        stock: _int(j, 'stock'),
        unitCost: _dbl(j, 'unit_cost'),
        value: _intOrNull(j, 'value'),
        minStock: _int(j, 'min_stock_qty'),
        status: StockStatus.parse(_strOrNull(j, 'status')),
        daysLeft: _dbl(j, 'days_left'),
        supplierId: _strOrNull(j, 'default_supplier_id'),
        supplierName: _strOrNull(j, 'supplier_name'),
        menuItemCount: _int(j, 'menu_item_count'),
      );

  final String id;
  final String name;
  final String? group;
  final String unit;
  final bool active;
  final int stock;
  final double? unitCost;
  final int? value;
  final int minStock;
  final StockStatus status;
  final double? daysLeft;
  final String? supplierId;
  final String? supplierName;
  final int menuItemCount;
}

class LotInfo {
  const LotInfo({
    required this.id,
    required this.code,
    required this.qtyReceived,
    required this.qtyRemaining,
    this.receivedAt,
    this.expiry,
    this.unitCost,
  });

  factory LotInfo.fromJson(Map<String, dynamic> j) => LotInfo(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        receivedAt: _time(j, 'received_at'),
        expiry: _time(j, 'expiry_date'),
        qtyReceived: _int(j, 'qty_received'),
        qtyRemaining: _int(j, 'qty_remaining'),
        unitCost: _dbl(j, 'unit_cost'),
      );

  final String id;
  final String code;
  final DateTime? receivedAt;
  final DateTime? expiry;
  final int qtyReceived;
  final int qtyRemaining;
  final double? unitCost;
}

class UsedIn {
  const UsedIn(
      {required this.itemName, required this.sizeName, required this.qty});

  factory UsedIn.fromJson(Map<String, dynamic> j) => UsedIn(
      itemName: _str(j, 'item_name'),
      sizeName: _str(j, 'size_name'),
      qty: _int(j, 'qty'));

  final String itemName;
  final String sizeName;
  final int qty;
}

class IngredientProfile {
  const IngredientProfile({
    required this.id,
    required this.name,
    required this.unit,
    required this.importance,
    required this.active,
    required this.stock,
    required this.minStock,
    required this.status,
    required this.lots,
    required this.usedIn,
    this.group,
    this.storageNote,
    this.stockAt,
    this.unitCost,
    this.lastPurchaseCost,
    this.lastPurchaseAt,
    this.value,
    this.daysLeft,
    this.supplierId,
    this.supplierName,
    this.supplierLeadDays,
  });

  factory IngredientProfile.fromJson(Map<String, dynamic> j) =>
      IngredientProfile(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        group: _strOrNull(j, 'group_name'),
        unit: _str(j, 'unit'),
        importance: _str(j, 'importance', 'normal'),
        active: j['active'] != false,
        storageNote: _strOrNull(j, 'storage_note'),
        stock: _int(j, 'stock'),
        stockAt: _time(j, 'stock_at'),
        unitCost: _dbl(j, 'unit_cost'),
        lastPurchaseCost: _dbl(j, 'last_purchase_cost'),
        lastPurchaseAt: _time(j, 'last_purchase_at'),
        value: _intOrNull(j, 'value'),
        minStock: _int(j, 'min_stock_qty'),
        status: StockStatus.parse(_strOrNull(j, 'status')),
        daysLeft: _dbl(j, 'days_left'),
        supplierId: _strOrNull(j, 'default_supplier_id'),
        supplierName: _strOrNull(j, 'supplier_name'),
        supplierLeadDays: _intOrNull(j, 'supplier_lead_days'),
        lots: _list(j, 'lots').map(LotInfo.fromJson).toList(),
        usedIn: _list(j, 'used_in').map(UsedIn.fromJson).toList(),
      );

  final String id;
  final String name;
  final String? group;
  final String unit;
  final String importance;
  final bool active;
  final String? storageNote;
  final int stock;
  final DateTime? stockAt;
  final double? unitCost;
  final double? lastPurchaseCost;
  final DateTime? lastPurchaseAt;
  final int? value;
  final int minStock;
  final StockStatus status;
  final double? daysLeft;
  final String? supplierId;
  final String? supplierName;
  final int? supplierLeadDays;
  final List<LotInfo> lots;
  final List<UsedIn> usedIn;

  int get menuItemCount => usedIn.map((e) => e.itemName).toSet().length;
}

class Movement {
  const Movement({
    required this.at,
    required this.kind,
    required this.qtyDelta,
    this.refCode,
    this.actorName,
    this.note,
  });

  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
        at: _time(j, 'at') ?? DateTime.now(),
        kind: _str(j, 'kind'),
        qtyDelta: _int(j, 'qty_delta'),
        refCode: _strOrNull(j, 'ref_code'),
        actorName: _strOrNull(j, 'actor_name'),
        note: _strOrNull(j, 'note'),
      );

  final DateTime at;

  /// `purchase`, `waste`, `adjust` hoặc `sale` (gộp theo ngày).
  final String kind;
  final int qtyDelta;
  final String? refCode;
  final String? actorName;
  final String? note;
}

class PriceEvent {
  const PriceEvent({
    required this.at,
    required this.kind,
    this.price,
    this.avgBefore,
    this.avgAfter,
    this.qty,
    this.orderCode,
    this.actorName,
  });

  factory PriceEvent.fromJson(Map<String, dynamic> j) => PriceEvent(
        at: _time(j, 'at') ?? DateTime.now(),
        kind: _str(j, 'kind'),
        price: _dbl(j, 'price'),
        avgBefore: _dbl(j, 'avg_before'),
        avgAfter: _dbl(j, 'avg_after'),
        qty: _intOrNull(j, 'qty'),
        orderCode: _strOrNull(j, 'order_code'),
        actorName: _strOrNull(j, 'actor_name'),
      );

  final DateTime at;
  final String kind;
  final double? price;
  final double? avgBefore;
  final double? avgAfter;
  final int? qty;
  final String? orderCode;
  final String? actorName;
}

class IngredientHistory {
  const IngredientHistory({required this.movements, required this.priceEvents});

  factory IngredientHistory.fromJson(Map<String, dynamic> j) =>
      IngredientHistory(
        movements: _list(j, 'movements').map(Movement.fromJson).toList(),
        priceEvents: _list(j, 'price_events').map(PriceEvent.fromJson).toList(),
      );

  final List<Movement> movements;
  final List<PriceEvent> priceEvents;
}

class IngredientGroup {
  const IngredientGroup({
    required this.id,
    required this.name,
    required this.active,
    required this.ingredientCount,
    required this.menuItemCount,
  });

  factory IngredientGroup.fromJson(Map<String, dynamic> j) => IngredientGroup(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        active: j['active'] != false,
        ingredientCount: _int(j, 'ingredient_count'),
        menuItemCount: _int(j, 'menu_item_count'),
      );

  final String id;
  final String name;
  final bool active;
  final int ingredientCount;
  final int menuItemCount;
}

/// Dữ liệu một lần lưu nguyên liệu (thêm mới hoặc sửa).
class IngredientDraft {
  const IngredientDraft({
    required this.name,
    required this.unit,
    this.groupId,
    this.minStockQty = 0,
    this.defaultSupplierId,
    this.storageNote,
    this.important = false,
  });

  final String name;
  final String unit;
  final String? groupId;
  final int minStockQty;
  final String? defaultSupplierId;
  final String? storageNote;
  final bool important;

  Map<String, dynamic> toJson() => {
        'name': name,
        'unit': unit,
        'group_id': groupId,
        'min_stock_qty': minStockQty,
        'default_supplier_id': defaultSupplierId,
        'storage_note': storageNote,
        'importance': important ? 'important' : 'normal',
      };
}

/// Mục chọn nguyên liệu cho phiếu (không có tồn, không có giá: nhân viên cũng dùng).
class PickerItem {
  const PickerItem({
    required this.id,
    required this.name,
    required this.unit,
    this.group,
    this.defaultSupplierId,
  });

  factory PickerItem.fromJson(Map<String, dynamic> j) => PickerItem(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        group: _strOrNull(j, 'group_name'),
        defaultSupplierId: _strOrNull(j, 'default_supplier_id'),
      );

  final String id;
  final String name;
  final String unit;
  final String? group;
  final String? defaultSupplierId;
}

class LotOption {
  const LotOption({required this.id, required this.code, this.expiry});

  factory LotOption.fromJson(Map<String, dynamic> j) => LotOption(
      id: _str(j, 'id'),
      code: _str(j, 'code'),
      expiry: _time(j, 'expiry_date'));

  final String id;
  final String code;
  final DateTime? expiry;
}

