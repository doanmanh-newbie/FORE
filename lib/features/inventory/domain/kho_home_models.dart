part of 'kho_models.dart';

// ---------- Tuần nhìn lại, đổi quán, trang chủ nhân viên ----------
class WeekReview {
  const WeekReview({
    required this.from,
    required this.to,
    required this.days,
    required this.stockValue,
    required this.wasteValue,
    required this.stableDays,
    required this.countedDays,
    required this.stocktakesApproved,
    required this.ordersConfirmed,
    required this.pendingStocktakes,
  });

  factory WeekReview.fromJson(Map<String, dynamic> j) => WeekReview(
        from: DateTime.tryParse(_str(j, 'from')) ?? DateTime.now(),
        to: DateTime.tryParse(_str(j, 'to')) ?? DateTime.now(),
        days: _int(j, 'days'),
        stockValue: _int(j, 'stock_value'),
        wasteValue: _int(j, 'waste_value'),
        stableDays: _int(j, 'stable_days'),
        countedDays: _int(j, 'counted_days'),
        stocktakesApproved: _int(j, 'stocktakes_approved'),
        ordersConfirmed: _int(j, 'orders_confirmed'),
        pendingStocktakes: _int(j, 'pending_stocktakes'),
      );

  final DateTime from;
  final DateTime to;
  final int days;
  final int stockValue;
  final int wasteValue;
  final int stableDays;
  final int countedDays;
  final int stocktakesApproved;
  final int ordersConfirmed;
  final int pendingStocktakes;
}

class ShopSnapshot {
  const ShopSnapshot({
    required this.shopId,
    required this.shopName,
    required this.ownerName,
    required this.isCurrent,
    required this.stockValue,
    required this.waste7d,
    required this.updatedAt,
  });

  factory ShopSnapshot.fromJson(Map<String, dynamic> j) => ShopSnapshot(
        shopId: _str(j, 'shop_id'),
        shopName: _str(j, 'shop_name'),
        ownerName: _str(j, 'owner_name'),
        isCurrent: _bool(j, 'is_current'),
        stockValue: _int(j, 'stock_value'),
        waste7d: _int(j, 'waste_7d'),
        updatedAt: _time(j, 'updated_at') ?? DateTime.now(),
      );

  final String shopId;
  final String shopName;
  final String ownerName;
  final bool isCurrent;
  final int stockValue;
  final int waste7d;
  final DateTime updatedAt;
}

class StaffStocktake {
  const StaffStocktake({
    required this.id,
    required this.code,
    required this.status,
    required this.counted,
    required this.total,
    this.savedAt,
    this.submittedAt,
    this.reviewNote,
  });

  factory StaffStocktake.fromJson(Map<String, dynamic> j) => StaffStocktake(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        status: StocktakeStatus.parse(_strOrNull(j, 'status')),
        savedAt: _time(j, 'saved_at'),
        submittedAt: _time(j, 'submitted_at'),
        counted: _int(j, 'counted'),
        total: _int(j, 'total'),
        reviewNote: _strOrNull(j, 'review_note'),
      );

  final String id;
  final String code;
  final StocktakeStatus status;
  final DateTime? savedAt;
  final DateTime? submittedAt;
  final int counted;
  final int total;
  final String? reviewNote;
}

class StaffHint {
  const StaffHint(
      {required this.ingredientName, required this.lotCode, this.expiry});

  factory StaffHint.fromJson(Map<String, dynamic> j) => StaffHint(
        ingredientName: _str(j, 'ingredient_name'),
        lotCode: _str(j, 'lot_code'),
        expiry: _time(j, 'expiry_date'),
      );

  final String ingredientName;
  final String lotCode;
  final DateTime? expiry;
}

class StaffInventoryHomeData {
  const StaffInventoryHomeData({
    required this.staffName,
    required this.shiftOpen,
    this.shiftOpenedAt,
    this.stocktake,
    this.hint,
  });

  factory StaffInventoryHomeData.fromJson(Map<String, dynamic> j) =>
      StaffInventoryHomeData(
        staffName: _str(j, 'staff_name'),
        shiftOpen: _bool(j, 'shift_open'),
        shiftOpenedAt: _time(j, 'shift_opened_at'),
        stocktake: j['stocktake'] is Map<String, dynamic>
            ? StaffStocktake.fromJson(j['stocktake'] as Map<String, dynamic>)
            : null,
        hint: j['hint'] is Map<String, dynamic>
            ? StaffHint.fromJson(j['hint'] as Map<String, dynamic>)
            : null,
      );

  final String staffName;
  final bool shiftOpen;
  final DateTime? shiftOpenedAt;
  final StaffStocktake? stocktake;
  final StaffHint? hint;
}
