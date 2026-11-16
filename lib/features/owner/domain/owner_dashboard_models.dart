/// Giá trị đã tải cho một ngày kinh doanh, dùng chung giữa các tab chủ quán.
class OwnerDashboardData {
  const OwnerDashboardData({
    required this.shifts,
    required this.reports,
    required this.openShift,
    required this.cashSales,
    required this.transferSales,
    required this.yesterdaySales,
    required this.billCount,
    required this.pendingInvites,
    required this.activeStaffCount,
    required this.menu,
    required this.expectedStock,
    required this.lowStock,
    required this.missingRecipeCount,
    required this.notifications,
    required this.updatedAt,
    required this.businessStart,
    required this.businessEnd,
    this.recentSales = const [],
    this.pendingReviewCount = 0,
    this.unavailable = const {},
  });

  final List<Map<String, dynamic>> shifts;
  final List<OwnerShiftReport> reports;
  final Map<String, dynamic>? openShift;
  final int cashSales;
  final int transferSales;
  /// Doanh thu hôm qua TÍNH ĐẾN CÙNG GIỜ (database tính), để so sánh công bằng với hôm nay.
  final int yesterdaySales;
  final int billCount;
  final int pendingInvites;
  final int activeStaffCount;
  final List<Map<String, dynamic>> menu;
  final List<Map<String, dynamic>> expectedStock;
  final List<Map<String, dynamic>> lowStock;
  final int missingRecipeCount;
  final List<OwnerNotification> notifications;
  final DateTime updatedAt;
  final DateTime businessStart;
  final DateTime businessEnd;
  final List<DailySalesPoint> recentSales;

  /// Số ca vàng/đỏ trong 7 ngày gần nhất mà chủ chưa đánh dấu đã xử lý.
  final int pendingReviewCount;

  /// Các phần số liệu phụ chưa tải được: `menu`, `stock`, `trend`.
  final Set<String> unavailable;

  int get totalSales => cashSales + transferSales;

  double? get salesChangePercent => yesterdaySales == 0
      ? null
      : (totalSales - yesterdaySales) * 100 / yesterdaySales;
}

class DailySalesPoint {
  const DailySalesPoint({required this.businessStart, required this.sales});

  factory DailySalesPoint.fromMap(Map<String, dynamic> row) => DailySalesPoint(
        businessStart:
            DateTime.parse(row['business_start'] as String).toLocal(),
        sales: (row['sales'] as num?)?.toInt() ?? 0,
      );

  final DateTime businessStart;
  final int sales;
}

/// Báo cáo và trạng thái xử lý do chủ quán lưu cho một ca đã đóng.
class OwnerShiftReport {
  const OwnerShiftReport({
    required this.shift,
    required this.report,
    this.review = const {},
  });

  final Map<String, dynamic> shift;
  final Map<String, dynamic> report;
  final Map<String, dynamic> review;

  bool get handled => review['handled'] as bool? ?? false;
  String get note => review['note'] as String? ?? '';

  Map<String, dynamic> get summary =>
      Map<String, dynamic>.from(report['summary'] as Map? ?? const {});
  Map<String, dynamic> get cash =>
      Map<String, dynamic>.from(report['cash'] as Map? ?? const {});
  String get overall => summary['overall'] as String? ?? 'no_data';
}

/// Một trang danh sách ca đã đóng (từ `owner_shift_list`).
class OwnerShiftPage {
  const OwnerShiftPage({
    required this.items,
    required this.hasMore,
    this.nextBefore,
    this.openShift,
  });

  final List<OwnerShiftReport> items;
  final bool hasMore;

  /// Con trỏ để lấy trang tiếp theo (giờ mở của ca cuối trang).
  final DateTime? nextBefore;
  final Map<String, dynamic>? openShift;
}

/// Thông báo có nguồn dữ liệu ổn định để theo dõi trạng thái đã đọc.
class OwnerNotification {
  const OwnerNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.occurredAt,
    required this.read,
  });

  factory OwnerNotification.fromMap(Map<String, dynamic> row) =>
      OwnerNotification(
        id: row['id'] as String? ?? '',
        kind: row['kind'] as String? ?? 'general',
        title: row['title'] as String? ?? '',
        body: row['body'] as String? ?? '',
        occurredAt: DateTime.tryParse('${row['occurred_at']}')?.toLocal(),
        read: row['read'] as bool? ?? false,
      );

  final String id;
  final String kind;
  final String title;
  final String body;
  final DateTime? occurredAt;
  final bool read;
}
