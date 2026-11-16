part of 'kho_models.dart';

// ---------- Kiểm kê ----------
enum StocktakeStatus {
  draft,
  submitted,
  recount,
  approved;

  static StocktakeStatus parse(String? v) => switch (v) {
        'submitted' => StocktakeStatus.submitted,
        'recount' => StocktakeStatus.recount,
        'approved' => StocktakeStatus.approved,
        _ => StocktakeStatus.draft,
      };
}

/// Dòng trên phiếu đếm MÙ của nhân viên: không có số hệ thống.
class CountLine {
  const CountLine({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.editable,
    required this.recountRequested,
    this.group,
    this.countedQty,
  });

  factory CountLine.fromJson(Map<String, dynamic> j) => CountLine(
        ingredientId: _str(j, 'ingredient_id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        group: _strOrNull(j, 'group_name'),
        countedQty: _intOrNull(j, 'counted_qty'),
        recountRequested: _bool(j, 'recount_requested'),
        editable: _bool(j, 'editable'),
      );

  final String ingredientId;
  final String name;
  final String unit;
  final String? group;
  final int? countedQty;
  final bool recountRequested;
  final bool editable;
}

class CountSheet {
  const CountSheet({
    required this.id,
    required this.code,
    required this.status,
    required this.lines,
    this.startedAt,
    this.savedAt,
    this.submittedAt,
    this.reviewNote,
  });

  factory CountSheet.fromJson(Map<String, dynamic> j) => CountSheet(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        status: StocktakeStatus.parse(_strOrNull(j, 'status')),
        startedAt: _time(j, 'started_at'),
        savedAt: _time(j, 'saved_at'),
        submittedAt: _time(j, 'submitted_at'),
        reviewNote: _strOrNull(j, 'review_note'),
        lines: _list(j, 'lines').map(CountLine.fromJson).toList(),
      );

  final String id;
  final String code;
  final StocktakeStatus status;
  final DateTime? startedAt;
  final DateTime? savedAt;
  final DateTime? submittedAt;
  final String? reviewNote;
  final List<CountLine> lines;
}

class StocktakeSummary {
  const StocktakeSummary({
    required this.id,
    required this.code,
    required this.status,
    required this.staffName,
    required this.lineCount,
    required this.varianceLines,
    this.submittedAt,
    this.reviewedAt,
    this.netValue,
  });

  factory StocktakeSummary.fromJson(Map<String, dynamic> j) => StocktakeSummary(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        status: StocktakeStatus.parse(_strOrNull(j, 'status')),
        staffName: _str(j, 'staff_name'),
        submittedAt: _time(j, 'submitted_at'),
        reviewedAt: _time(j, 'reviewed_at'),
        lineCount: _int(j, 'line_count'),
        varianceLines: _int(j, 'variance_lines'),
        netValue: _intOrNull(j, 'net_value'),
      );

  final String id;
  final String code;
  final StocktakeStatus status;
  final String staffName;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final int lineCount;
  final int varianceLines;
  final int? netValue;
}

class ReviewLine {
  const ReviewLine({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.recountRequested,
    this.group,
    this.countedQty,
    this.systemQty,
    this.unitCost,
    this.variance,
    this.varianceValue,
    this.recountPrevQty,
    this.decision,
  });

  factory ReviewLine.fromJson(Map<String, dynamic> j) => ReviewLine(
        ingredientId: _str(j, 'ingredient_id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        group: _strOrNull(j, 'group_name'),
        countedQty: _intOrNull(j, 'counted_qty'),
        systemQty: _intOrNull(j, 'system_qty'),
        unitCost: _dbl(j, 'unit_cost'),
        variance: _intOrNull(j, 'variance'),
        varianceValue: _intOrNull(j, 'variance_value'),
        recountPrevQty: _intOrNull(j, 'recount_prev_qty'),
        recountRequested: _bool(j, 'recount_requested'),
        decision: _strOrNull(j, 'decision'),
      );

  final String ingredientId;
  final String name;
  final String unit;
  final String? group;
  final int? countedQty;
  final int? systemQty;
  final double? unitCost;
  final int? variance;
  final int? varianceValue;
  final int? recountPrevQty;
  final bool recountRequested;
  final String? decision;

  bool get hasVariance => (variance ?? 0) != 0;
}

class StocktakeDetail {
  const StocktakeDetail({
    required this.id,
    required this.code,
    required this.status,
    required this.staffName,
    required this.stockValueNow,
    required this.lines,
    this.submittedAt,
    this.reviewedAt,
    this.reviewReason,
    this.reviewNote,
    this.reviewerName,
  });

  factory StocktakeDetail.fromJson(Map<String, dynamic> j) => StocktakeDetail(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        status: StocktakeStatus.parse(_strOrNull(j, 'status')),
        staffName: _str(j, 'staff_name'),
        submittedAt: _time(j, 'submitted_at'),
        reviewedAt: _time(j, 'reviewed_at'),
        reviewReason: _strOrNull(j, 'review_reason'),
        reviewNote: _strOrNull(j, 'review_note'),
        reviewerName: _strOrNull(j, 'reviewer_name'),
        stockValueNow: _int(j, 'stock_value_now'),
        lines: _list(j, 'lines').map(ReviewLine.fromJson).toList(),
      );

  final String id;
  final String code;
  final StocktakeStatus status;
  final String staffName;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewReason;
  final String? reviewNote;
  final String? reviewerName;
  final int stockValueNow;
  final List<ReviewLine> lines;

  List<ReviewLine> get varianceLines =>
      lines.where((l) => l.hasVariance).toList();

  /// Tổng tiền các dòng THIẾU (số âm) và THỪA (số dương).
  int get shortValue => varianceLines
      .map((l) => l.varianceValue ?? 0)
      .where((v) => v < 0)
      .fold(0, (a, b) => a + b);

  int get overValue => varianceLines
      .map((l) => l.varianceValue ?? 0)
      .where((v) => v > 0)
      .fold(0, (a, b) => a + b);

  int get netValue => shortValue + overValue;
}

class StocktakeResult {
  const StocktakeResult(
      {required this.code, required this.adjustedLines, required this.netValue});

  factory StocktakeResult.fromJson(Map<String, dynamic> j) => StocktakeResult(
      code: _str(j, 'code'),
      adjustedLines: _int(j, 'adjusted_lines'),
      netValue: _int(j, 'net_value'));

  final String code;
  final int adjustedLines;
  final int netValue;
}

