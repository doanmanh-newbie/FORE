part of 'kho_models.dart';

// ---------- Phiếu nhập ----------
enum PoStatus {
  draft,
  confirmed,
  cancelled;

  static PoStatus parse(String? v) => switch (v) {
        'confirmed' => PoStatus.confirmed,
        'cancelled' => PoStatus.cancelled,
        _ => PoStatus.draft,
      };
}

class PoSummary {
  const PoSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.lineCount,
    required this.needsPricing,
    this.supplierName,
    this.receivedAt,
    this.updatedAt,
    this.totalAmount,
  });

  factory PoSummary.fromJson(Map<String, dynamic> j) => PoSummary(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        status: PoStatus.parse(_strOrNull(j, 'status') ?? 'confirmed'),
        supplierName: _strOrNull(j, 'supplier_name'),
        receivedAt: _time(j, 'received_at'),
        updatedAt: _time(j, 'updated_at'),
        needsPricing: _bool(j, 'needs_pricing'),
        totalAmount: _intOrNull(j, 'total_amount'),
        lineCount: _int(j, 'line_count'),
      );

  final String id;
  final String code;
  final PoStatus status;
  final String? supplierName;
  final DateTime? receivedAt;
  final DateTime? updatedAt;
  final bool needsPricing;
  final int? totalAmount;
  final int lineCount;
}

class PoLine {
  const PoLine({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.qty,
    this.id,
    this.unitPrice,
    this.lotCode,
    this.expiry,
    this.lastPrice,
  });

  factory PoLine.fromJson(Map<String, dynamic> j) => PoLine(
        id: _strOrNull(j, 'id'),
        ingredientId: _str(j, 'ingredient_id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        qty: _int(j, 'qty'),
        unitPrice: _dbl(j, 'unit_price'),
        lotCode: _strOrNull(j, 'lot_code'),
        expiry: _time(j, 'expiry_date'),
        lastPrice: _dbl(j, 'last_price'),
      );

  final String? id;
  final String ingredientId;
  final String name;
  final String unit;
  final int qty;

  /// Đồng / đơn vị gốc. Nhân viên không bao giờ nhận trường này.
  final double? unitPrice;
  final String? lotCode;
  final DateTime? expiry;
  final double? lastPrice;

  int? get lineTotal => unitPrice == null ? null : (qty * unitPrice!).round();

  PoLine copyWith({
    int? qty,
    double? unitPrice,
    bool clearPrice = false,
    String? lotCode,
    DateTime? expiry,
    bool clearExpiry = false,
  }) =>
      PoLine(
        id: id,
        ingredientId: ingredientId,
        name: name,
        unit: unit,
        qty: qty ?? this.qty,
        unitPrice: clearPrice ? null : (unitPrice ?? this.unitPrice),
        lotCode: lotCode ?? this.lotCode,
        expiry: clearExpiry ? null : (expiry ?? this.expiry),
        lastPrice: lastPrice,
      );

  Map<String, dynamic> toJson({required bool withPrice}) => {
        'ingredient_id': ingredientId,
        'qty': qty,
        if (withPrice) 'unit_price': unitPrice,
        'lot_code': lotCode,
        'expiry_date': expiry?.toIso8601String().substring(0, 10),
      };
}

class PoDetail {
  const PoDetail({
    required this.id,
    required this.code,
    required this.status,
    required this.vatIncluded,
    required this.needsPricing,
    required this.lines,
    this.supplierId,
    this.supplierName,
    this.note,
    this.receivedAt,
    this.createdAt,
    this.createdByName,
    this.shippingFee,
    this.totalAmount,
  });

  factory PoDetail.fromJson(Map<String, dynamic> j) => PoDetail(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        status: PoStatus.parse(_strOrNull(j, 'status')),
        supplierId: _strOrNull(j, 'supplier_id'),
        supplierName: _strOrNull(j, 'supplier_name'),
        note: _strOrNull(j, 'note'),
        vatIncluded: j['vat_included'] != false,
        receivedAt: _time(j, 'received_at'),
        createdAt: _time(j, 'created_at'),
        createdByName: _strOrNull(j, 'created_by_name'),
        needsPricing: _bool(j, 'needs_pricing'),
        shippingFee: _intOrNull(j, 'shipping_fee'),
        totalAmount: _intOrNull(j, 'total_amount'),
        lines: _list(j, 'lines').map(PoLine.fromJson).toList(),
      );

  final String id;
  final String code;
  final PoStatus status;
  final String? supplierId;
  final String? supplierName;
  final String? note;
  final bool vatIncluded;
  final DateTime? receivedAt;
  final DateTime? createdAt;
  final String? createdByName;
  final bool needsPricing;
  final int? shippingFee;
  final int? totalAmount;
  final List<PoLine> lines;
}

/// Nội dung gửi lên khi lưu phiếu.
class PoDraft {
  const PoDraft({
    required this.lines,
    this.supplierId,
    this.note,
    this.vatIncluded = true,
    this.shippingFee = 0,
    this.receivedAt,
  });

  final String? supplierId;
  final String? note;
  final bool vatIncluded;
  final int shippingFee;
  final DateTime? receivedAt;
  final List<PoLine> lines;

  Map<String, dynamic> toJson({required bool withPrice}) => {
        'supplier_id': supplierId,
        'note': note,
        'vat_included': vatIncluded,
        'shipping_fee': shippingFee,
        if (receivedAt != null)
          'received_at': receivedAt!.toUtc().toIso8601String(),
        'lines': [for (final l in lines) l.toJson(withPrice: withPrice)],
      };
}

class ImpactItem {
  const ImpactItem({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.price,
    required this.stockBefore,
    required this.stockAfter,
    this.avgBefore,
    this.avgAfter,
    this.lastPrice,
    this.priceChangePct,
    this.avgChangePct,
  });

  factory ImpactItem.fromJson(Map<String, dynamic> j) => ImpactItem(
        ingredientId: _str(j, 'ingredient_id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        qty: _int(j, 'qty'),
        price: _dbl(j, 'price') ?? 0,
        stockBefore: _int(j, 'stock_before'),
        stockAfter: _int(j, 'stock_after'),
        avgBefore: _dbl(j, 'avg_before'),
        avgAfter: _dbl(j, 'avg_after'),
        lastPrice: _dbl(j, 'last_price'),
        priceChangePct: _dbl(j, 'price_change_pct'),
        avgChangePct: _dbl(j, 'avg_change_pct'),
      );

  final String ingredientId;
  final String name;
  final String unit;
  final int qty;
  final double price;
  final int stockBefore;
  final int stockAfter;
  final double? avgBefore;
  final double? avgAfter;
  final double? lastPrice;
  final double? priceChangePct;
  final double? avgChangePct;
}

class ImpactSize {
  const ImpactSize({
    required this.itemName,
    required this.sizeName,
    required this.sellPrice,
    this.costBefore,
    this.costAfter,
  });

  factory ImpactSize.fromJson(Map<String, dynamic> j) => ImpactSize(
        itemName: _str(j, 'item_name'),
        sizeName: _str(j, 'size_name'),
        sellPrice: _int(j, 'sell_price'),
        costBefore: _intOrNull(j, 'cost_before'),
        costAfter: _intOrNull(j, 'cost_after'),
      );

  final String itemName;
  final String sizeName;
  final int sellPrice;
  final int? costBefore;
  final int? costAfter;

  double? get marginAfterPct => costAfter == null || sellPrice <= 0
      ? null
      : (sellPrice - costAfter!) * 100 / sellPrice;
}

class PoImpact {
  const PoImpact({required this.code, required this.items, required this.sizes});

  factory PoImpact.fromJson(Map<String, dynamic> j) => PoImpact(
        code: _str(j, 'code'),
        items: _list(j, 'items').map(ImpactItem.fromJson).toList(),
        sizes: _list(j, 'sizes').map(ImpactSize.fromJson).toList(),
      );

  final String code;
  final List<ImpactItem> items;
  final List<ImpactSize> sizes;
}

