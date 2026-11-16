part of 'kho_models.dart';

// ---------- Tổng quan ----------
class ValueItem {
  const ValueItem({required this.id, required this.name, required this.value});

  factory ValueItem.fromJson(Map<String, dynamic> j) => ValueItem(
      id: _str(j, 'id'), name: _str(j, 'name'), value: _int(j, 'value'));

  final String id;
  final String name;
  final int value;
}

class LowItem {
  const LowItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.status,
    this.daysLeft,
  });

  factory LowItem.fromJson(Map<String, dynamic> j) => LowItem(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        stock: _int(j, 'stock'),
        daysLeft: _dbl(j, 'days_left'),
        status: StockStatus.parse(_strOrNull(j, 'status')),
      );

  final String id;
  final String name;
  final String unit;
  final int stock;
  final double? daysLeft;
  final StockStatus status;
}

class ExpiringLot {
  const ExpiringLot(
      {required this.name, required this.code, required this.expiry});

  factory ExpiringLot.fromJson(Map<String, dynamic> j) => ExpiringLot(
        name: _str(j, 'name'),
        code: _str(j, 'code'),
        expiry: _time(j, 'expiry_date') ?? DateTime.now(),
      );

  final String name;
  final String code;
  final DateTime expiry;
}

class PendingStocktake {
  const PendingStocktake({
    required this.id,
    required this.code,
    required this.staffName,
    required this.varianceLines,
    this.submittedAt,
  });

  factory PendingStocktake.fromJson(Map<String, dynamic> j) => PendingStocktake(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        staffName: _str(j, 'staff_name'),
        varianceLines: _int(j, 'variance_lines'),
        submittedAt: _time(j, 'submitted_at'),
      );

  final String id;
  final String code;
  final String staffName;
  final int varianceLines;
  final DateTime? submittedAt;
}

class InvOverview {
  const InvOverview({
    required this.updatedAt,
    required this.stockValue,
    required this.unpricedCount,
    required this.topItems,
    required this.lowItems,
    required this.expiringLots,
    required this.pendingStocktakes,
    required this.needsPricingCount,
    required this.draftOrderCount,
    required this.openRequestCount,
    required this.suggestionCount,
    required this.waste7d,
    required this.wastePrev7d,
    required this.ingredientCount,
  });

  factory InvOverview.fromJson(Map<String, dynamic> j) => InvOverview(
        updatedAt: _time(j, 'updated_at') ?? DateTime.now(),
        stockValue: _int(j, 'stock_value'),
        unpricedCount: _int(j, 'unpriced_count'),
        topItems: _list(j, 'top_items').map(ValueItem.fromJson).toList(),
        lowItems: _list(j, 'low_items').map(LowItem.fromJson).toList(),
        expiringLots:
            _list(j, 'expiring_lots').map(ExpiringLot.fromJson).toList(),
        pendingStocktakes: _list(j, 'pending_stocktakes')
            .map(PendingStocktake.fromJson)
            .toList(),
        needsPricingCount: _int(j, 'needs_pricing_count'),
        draftOrderCount: _int(j, 'draft_order_count'),
        openRequestCount: _int(j, 'open_request_count'),
        suggestionCount: _int(j, 'suggestion_count'),
        waste7d: _int(j, 'waste_7d'),
        wastePrev7d: _int(j, 'waste_prev_7d'),
        ingredientCount: _int(j, 'ingredient_count'),
      );

  final DateTime updatedAt;
  final int stockValue;
  final int unpricedCount;
  final List<ValueItem> topItems;
  final List<LowItem> lowItems;
  final List<ExpiringLot> expiringLots;
  final List<PendingStocktake> pendingStocktakes;
  final int needsPricingCount;
  final int draftOrderCount;
  final int openRequestCount;
  final int suggestionCount;
  final int waste7d;
  final int wastePrev7d;
  final int ingredientCount;

  /// Phần trăm thay đổi hao hụt so với 7 ngày trước; `null` nếu kỳ trước không có.
  double? get wasteChangePct => wastePrev7d <= 0
      ? null
      : (waste7d - wastePrev7d) * 100 / wastePrev7d;
}

