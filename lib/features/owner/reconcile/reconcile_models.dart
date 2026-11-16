import '../domain/owner_dashboard_models.dart';

/// Trạng thái đối soát do database quyết định (ok | warn | alert | no_data).
enum ReconcileStatus { ok, warn, alert, noData }

ReconcileStatus reconcileStatusOf(Object? raw) => switch (raw) {
      'ok' => ReconcileStatus.ok,
      'warn' => ReconcileStatus.warn,
      'alert' => ReconcileStatus.alert,
      _ => ReconcileStatus.noData,
    };

int? _asInt(Object? value) => value is num ? value.round() : null;

double? _asDouble(Object? value) => value is num ? value.toDouble() : null;

Map<String, dynamic> _asMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _asRows(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false)
    : <Map<String, dynamic>>[];

ReconcileStatus _cashStatusFromVariance(int? variance) {
  if (variance == null) return ReconcileStatus.noData;
  final amount = variance.abs();
  if (amount >= 50000) return ReconcileStatus.alert;
  if (amount >= 20000) return ReconcileStatus.warn;
  return ReconcileStatus.ok;
}

/// Một nguyên liệu trong báo cáo đối soát ca (một phần tử của `ingredients`).
class IngredientRecon {
  const IngredientRecon({
    required this.name,
    required this.unit,
    required this.important,
    required this.status,
    required this.justifiedWaste,
    required this.streakCount,
    required this.streakFlag,
    this.opening,
    this.purchased,
    this.closing,
    this.actualUsed,
    this.theoretical,
    this.variance,
    this.variancePct,
    this.adjusted,
    this.adjustedPct,
    this.equivCups,
    this.equivRevenue,
  });

  factory IngredientRecon.fromMap(Map<String, dynamic> row) => IngredientRecon(
        name: '${row['ingredient_name'] ?? 'Nguyên liệu'}',
        unit: '${row['unit'] ?? ''}',
        important: row['importance'] == 'important',
        status: reconcileStatusOf(row['status']),
        justifiedWaste: _asInt(row['justified_waste']) ?? 0,
        streakCount: _asInt(row['streak_count']) ?? 0,
        streakFlag: row['streak_flag'] == true,
        opening: _asInt(row['opening_qty']),
        purchased: _asInt(row['purchased_qty']),
        closing: _asInt(row['closing_qty']),
        actualUsed: _asInt(row['actual_used']),
        theoretical: _asInt(row['theoretical_used']),
        variance: _asInt(row['variance']),
        variancePct: _asDouble(row['variance_pct']),
        adjusted: _asInt(row['adjusted_variance']),
        adjustedPct: _asDouble(row['adjusted_pct']),
        equivCups: _asDouble(row['equiv_cups']),
        equivRevenue: _asInt(row['equiv_revenue']),
      );

  final String name;
  final String unit;
  final bool important;
  final ReconcileStatus status;
  final int justifiedWaste;
  final int streakCount;
  final bool streakFlag;
  final int? opening;
  final int? purchased;
  final int? closing;
  final int? actualUsed;
  final int? theoretical;
  final int? variance;
  final double? variancePct;
  final int? adjusted;
  final double? adjustedPct;
  final double? equivCups;
  final int? equivRevenue;

  bool get hasData => status != ReconcileStatus.noData;

  bool get needsAttention =>
      status == ReconcileStatus.warn || status == ReconcileStatus.alert;

  /// Hụt: dùng nhiều hơn lượng lý thuyết theo món đã bán.
  bool get isShort => (adjusted ?? 0) > 0;

  /// Doanh thu ước tính bị hụt (theo giá bán trung bình), chỉ tính khi đang cảnh báo.
  int get revenueLoss {
    if (!needsAttention || !isShort) return 0;
    final value = equivRevenue ?? 0;
    return value > 0 ? value : 0;
  }
}

/// Kết quả đối soát tiền mặt (`cash` của shift_report).
class CashRecon {
  const CashRecon({
    required this.status,
    this.opening,
    this.prevClosing,
    this.openingDiff,
    this.cashSales = 0,
    this.transferSales = 0,
    this.cashIn = 0,
    this.cashOut = 0,
    this.expected,
    this.closing,
    this.variance,
    this.cancelledCount = 0,
    this.cancelledAmount = 0,
    this.openingDiffFlag = false,
  });

  factory CashRecon.fromMap(Map<String, dynamic> row) {
    final expected = _asInt(row['expected_cash']);
    final closing = _asInt(row['closing_cash']);
    final variance = _asInt(row['variance']) ??
        (expected != null && closing != null ? closing - expected : null);
    final rawStatus = row['status'];
    return CashRecon(
      status: rawStatus == null
          ? _cashStatusFromVariance(variance)
          : reconcileStatusOf(rawStatus),
      opening: _asInt(row['opening_cash']),
      prevClosing: _asInt(row['prev_closing_cash']),
      openingDiff: _asInt(row['opening_diff']),
      cashSales: _asInt(row['cash_sales']) ?? 0,
      transferSales: _asInt(row['transfer_sales']) ?? 0,
      cashIn: _asInt(row['cash_in']) ?? 0,
      cashOut: _asInt(row['cash_out']) ?? 0,
      expected: expected,
      closing: closing,
      variance: variance,
      cancelledCount: _asInt(row['cancelled_after_paid_count']) ?? 0,
      cancelledAmount: _asInt(row['cancelled_after_paid_amount']) ?? 0,
      openingDiffFlag: row['opening_diff_flag'] == true,
    );
  }

  final ReconcileStatus status;
  final int? opening;
  final int? prevClosing;
  final int? openingDiff;
  final int cashSales;
  final int transferSales;
  final int cashIn;
  final int cashOut;
  final int? expected;
  final int? closing;
  final int? variance;
  final int cancelledCount;
  final int cancelledAmount;

  /// Tiền đầu ca lệch so với cuối ca trước từ ngưỡng của quán.
  final bool openingDiffFlag;

  bool get hasData => expected != null && closing != null && variance != null;

  bool get needsAttention =>
      status == ReconcileStatus.warn || status == ReconcileStatus.alert;
}

/// Hao hụt có lý do, gộp theo (nguyên liệu, loại).
class WasteRecon {
  const WasteRecon({
    required this.name,
    required this.unit,
    required this.reasonLabel,
    required this.entries,
    required this.qty,
    required this.wasteTotal,
    required this.theoretical,
    required this.wastePct,
    required this.warn,
  });

  factory WasteRecon.fromMap(Map<String, dynamic> row) => WasteRecon(
        name: '${row['ingredient_name'] ?? 'Nguyên liệu'}',
        unit: '${row['unit'] ?? ''}',
        reasonLabel: '${row['reason_label'] ?? 'Hao hụt'}',
        entries: _asInt(row['entries']) ?? 0,
        qty: _asInt(row['qty']) ?? 0,
        wasteTotal: _asInt(row['waste_total']) ?? 0,
        theoretical: _asInt(row['theoretical_used']) ?? 0,
        wastePct: _asDouble(row['waste_pct_total']),
        warn: row['flag'] == 'warn',
      );

  final String name;
  final String unit;
  final String reasonLabel;
  final int entries;
  final int qty;
  final int wasteTotal;
  final int theoretical;
  final double? wastePct;
  final bool warn;
}

/// Một khoản thu/chi tiền mặt trong ca.
class CashMovement {
  const CashMovement({
    required this.incoming,
    required this.amount,
    required this.note,
    required this.byName,
    required this.at,
  });

  factory CashMovement.fromMap(Map<String, dynamic> row) => CashMovement(
        incoming: row['direction'] == 'in',
        amount: _asInt(row['amount']) ?? 0,
        note: '${row['note'] ?? ''}'.trim(),
        byName: '${row['entered_by_name'] ?? ''}'.trim(),
        at: DateTime.tryParse('${row['entered_at']}')?.toLocal(),
      );

  final bool incoming;
  final int amount;
  final String note;
  final String byName;
  final DateTime? at;
}

/// Một bill đã thu tiền rồi bị hủy trong ca.
class CancelledBill {
  const CancelledBill({
    required this.billNo,
    required this.amount,
    required this.reason,
    required this.cancelledByName,
    required this.approvedByName,
    required this.cancelledAt,
    required this.cash,
  });

  factory CancelledBill.fromMap(Map<String, dynamic> row) => CancelledBill(
        billNo: _asInt(row['bill_no']),
        amount: _asInt(row['amount']) ?? 0,
        reason: '${row['reason'] ?? ''}'.trim(),
        cancelledByName: '${row['cancelled_by_name'] ?? ''}'.trim(),
        approvedByName: '${row['approved_by_name'] ?? ''}'.trim(),
        cancelledAt: DateTime.tryParse('${row['cancelled_at']}')?.toLocal(),
        cash: row['payment_method'] != 'transfer',
      );

  final int? billNo;
  final int amount;
  final String reason;
  final String cancelledByName;
  final String approvedByName;
  final DateTime? cancelledAt;
  final bool cash;
}

/// Một lần ghi hao hụt: ai ghi, lúc nào, loại gì.
class WasteEntry {
  const WasteEntry({
    required this.id,
    required this.originalQty,
    required this.name,
    required this.unit,
    required this.qty,
    required this.reasonLabel,
    required this.note,
    required this.byName,
    required this.at,
  });

  factory WasteEntry.fromMap(Map<String, dynamic> row) => WasteEntry(
        id: '${row['id'] ?? ''}',
        originalQty: _asInt(row['original_qty']) ?? _asInt(row['qty']) ?? 0,
        name: '${row['ingredient_name'] ?? 'Nguyên liệu'}',
        unit: '${row['unit'] ?? ''}',
        qty: _asInt(row['qty']) ?? 0,
        reasonLabel: '${row['reason_label'] ?? 'Hao hụt'}',
        note: '${row['note'] ?? ''}'.trim(),
        byName: '${row['entered_by_name'] ?? ''}'.trim(),
        at: DateTime.tryParse('${row['entered_at']}')?.toLocal(),
      );

  final String id;
  final int originalQty;
  final String name;
  final String unit;
  final int qty;
  final String reasonLabel;
  final String note;
  final String byName;
  final DateTime? at;

  bool get corrected => qty != originalQty;
}

/// Một phiếu nhập kho trong ca. `qty` là số hiệu lực sau điều chỉnh của chủ.
class PurchaseEntry {
  const PurchaseEntry({
    required this.id,
    required this.name,
    required this.unit,
    required this.qty,
    required this.originalQty,
    required this.late,
    required this.note,
    required this.byName,
    required this.at,
  });

  factory PurchaseEntry.fromMap(Map<String, dynamic> row) => PurchaseEntry(
        id: '${row['id'] ?? ''}',
        name: '${row['ingredient_name'] ?? 'Nguyên liệu'}',
        unit: '${row['unit'] ?? ''}',
        qty: _asInt(row['qty']) ?? 0,
        originalQty: _asInt(row['original_qty']) ?? _asInt(row['qty']) ?? 0,
        late: row['is_late_entry'] == true,
        note: '${row['note'] ?? ''}'.trim(),
        byName: '${row['entered_by_name'] ?? ''}'.trim(),
        at: DateTime.tryParse('${row['entered_at']}')?.toLocal(),
      );

  final String id;
  final String name;
  final String unit;
  final int qty;
  final int originalQty;
  final bool late;
  final String note;
  final String byName;
  final DateTime? at;

  bool get corrected => qty != originalQty;
}

/// Báo cáo đối soát một ca đã đóng, đã bóc từ JSON của `shift_report`.
class ReconcileReport {
  const ReconcileReport({
    required this.source,
    required this.shiftId,
    required this.overall,
    required this.openedAt,
    required this.closedAt,
    required this.openedByName,
    required this.closedByName,
    required this.ingredients,
    required this.cash,
    required this.waste,
    required this.movements,
    required this.cancelledBills,
    required this.wasteEntries,
    required this.purchases,
    required this.itemsWithoutRecipe,
    required this.handled,
    required this.note,
  });

  factory ReconcileReport.fromOwner(OwnerShiftReport source) {
    final report = source.report;
    final shift = source.shift;
    final summary = _asMap(report['summary']);
    final warnings = _asMap(report['warnings']);
    return ReconcileReport(
      source: source,
      shiftId: '${shift['id']}',
      overall: reconcileStatusOf(summary['overall']),
      openedAt: DateTime.tryParse('${shift['opened_at']}')?.toLocal(),
      closedAt: DateTime.tryParse('${shift['closed_at']}')?.toLocal(),
      openedByName: '${shift['opened_by_name'] ?? ''}'.trim(),
      closedByName: '${shift['closed_by_name'] ?? ''}'.trim(),
      ingredients: _asRows(report['ingredients'])
          .map(IngredientRecon.fromMap)
          .toList(growable: false),
      cash: CashRecon.fromMap(source.cash),
      waste: _asRows(report['waste'])
          .map(WasteRecon.fromMap)
          .toList(growable: false),
      movements: _asRows(report['cash_movements'])
          .map(CashMovement.fromMap)
          .toList(growable: false),
      cancelledBills: _asRows(report['cancelled_bills'])
          .map(CancelledBill.fromMap)
          .toList(growable: false),
      wasteEntries: _asRows(report['waste_entries'])
          .map(WasteEntry.fromMap)
          .toList(growable: false),
      purchases: _asRows(report['purchases'])
          .map(PurchaseEntry.fromMap)
          .toList(growable: false),
      itemsWithoutRecipe: _asInt(warnings['items_without_recipe']) ?? 0,
      handled: source.handled,
      note: source.note,
    );
  }

  /// Bản gốc từ dashboard, dùng để lưu trạng thái xử lý.
  final OwnerShiftReport source;
  final String shiftId;
  final ReconcileStatus overall;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String openedByName;
  final String closedByName;
  final List<IngredientRecon> ingredients;
  final CashRecon cash;
  final List<WasteRecon> waste;
  final List<CashMovement> movements;
  final List<CancelledBill> cancelledBills;
  final List<WasteEntry> wasteEntries;
  final List<PurchaseEntry> purchases;
  final int itemsWithoutRecipe;
  final bool handled;
  final String note;

  String get title =>
      'Ca của ${openedByName.isEmpty ? 'nhân viên' : openedByName}';

  List<IngredientRecon> get attentionIngredients => ingredients
      .where((ingredient) => ingredient.needsAttention)
      .toList(growable: false);

  List<IngredientRecon> get streakIngredients => ingredients
      .where((ingredient) => ingredient.streakFlag)
      .toList(growable: false);

  int get noDataIngredientCount =>
      ingredients.where((ingredient) => !ingredient.hasData).length;

  /// Doanh thu ước tính bị hụt: lấy nguyên liệu hụt nhiều nhất. Không cộng các nguyên liệu
  /// với nhau vì nhiều nguyên liệu có thể cùng nằm trong một ly, cộng lại sẽ tính một ly nhiều lần.
  int get ingredientLoss => ingredients.fold<int>(
      0, (top, ingredient) => ingredient.revenueLoss > top ? ingredient.revenueLoss : top);

  /// Tiền mặt thiếu, chỉ tính khi database đã đánh dấu cần xem.
  int get cashShortfall {
    final variance = cash.variance;
    if (!cash.hasData || variance == null || variance >= 0) return 0;
    return cash.needsAttention ? -variance : 0;
  }

  int get totalImpact => ingredientLoss + cashShortfall;

  bool get needsAttention =>
      overall == ReconcileStatus.warn || overall == ReconcileStatus.alert;
}
