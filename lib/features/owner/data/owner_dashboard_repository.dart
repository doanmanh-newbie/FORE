import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/owner_dashboard_models.dart';

/// Lỗi liên quan phiên/thiết bị: phải đưa lên cho lớp phiên xử lý, không được
/// coi là "thiếu một nguồn dữ liệu phụ".
bool isAuthFailure(Object error) {
  if (error is AuthException) return true;
  if (error is PostgrestException) {
    final text = error.message.toLowerCase();
    return error.code == 'PGRST301' ||
        error.code == 'PGRST303' ||
        text.contains('jwt') ||
        text.contains('not_logged_in') ||
        text.contains('staff_device_untrusted');
  }
  return false;
}

/// Gắn `has_recipe` cho từng món từ `missing_recipe_sizes` của dashboard.
/// Trả `false` (và không gắn gì) khi server không trả khóa này, ví dụ server cũ:
/// thiếu dữ liệu không được hiểu là "đủ công thức".
bool applyRecipeCoverage(
  List<Map<String, dynamic>> menu,
  Map<String, dynamic> dashboard,
) {
  final missing = dashboard['missing_recipe_sizes'];
  if (missing is! List || dashboard['missing_recipe_count'] is! num) {
    return false;
  }
  final missingIds = missing.map((id) => '$id').toSet();
  for (final row in menu) {
    row['has_recipe'] = !missingIds.contains('${row['size_id']}');
  }
  return true;
}

/// Chạy một nguồn phụ: lỗi dịch vụ -> dùng [fallback] và ghi tên vào [onMissing];
/// lỗi xác thực -> ném lại.
Future<T> optionalOrFallback<T>(
  Future<T> request,
  T fallback,
  void Function() onMissing,
) =>
    request.catchError((Object error, StackTrace stack) {
      if (isAuthFailure(error)) {
        return Future<T>.error(error, stack);
      }
      onMissing();
      return fallback;
    });

abstract interface class OwnerDashboardDataSource {
  Future<OwnerDashboardData> load();

  /// Danh sách ca đã đóng theo khoảng giờ mở ca; `filter`: all | attention | unhandled.
  Future<OwnerShiftPage> loadShiftPage({
    required DateTime from,
    required DateTime to,
    String filter = 'all',
    int limit = 10,
    DateTime? before,
  });

  /// Báo cáo mới nhất của một ca (dùng sau khi chủ sửa phiếu nhập hoặc hao hụt).
  Future<Map<String, dynamic>> loadShiftReport(String shiftId);

  Future<void> correctWaste(String wasteId, int newQty, String reason);

  Future<void> correctPurchase(String purchaseId, int newQty, String reason);

  Future<void> setShiftReview(String shiftId, bool handled, String? note);

  Future<void> markNotificationsRead(List<String> keys);
}

/// Dữ liệu thật dành cho dashboard chủ quán. Không dùng số minh họa từ bản thiết kế.
class OwnerDashboardRepository implements OwnerDashboardDataSource {
  OwnerDashboardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<OwnerDashboardData> load() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final businessStart = now.hour < 6
        ? today.subtract(const Duration(days: 1)).add(const Duration(hours: 6))
        : today.add(const Duration(hours: 6));
    final businessEnd = businessStart.add(const Duration(days: 1));

    final dashboardResult = await _client.rpc(
      'owner_dashboard',
      params: {
        'p_from': businessStart.toUtc().toIso8601String(),
        'p_to': businessEnd.toUtc().toIso8601String(),
      },
    );
    if (dashboardResult is! Map) {
      throw const FormatException('owner_dashboard trả sai định dạng');
    }
    final dashboard = Map<String, dynamic>.from(dashboardResult);
    final shifts = (dashboard['reports'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row['shift'] as Map))
        .toList(growable: false);
    final reports = (dashboard['reports'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .where((row) => row['report'] is Map)
        .map((row) => OwnerShiftReport(
              shift: Map<String, dynamic>.from(row['shift'] as Map),
              report: Map<String, dynamic>.from(row['report'] as Map),
              review:
                  Map<String, dynamic>.from(row['review'] as Map? ?? const {}),
            ))
        .toList(growable: false);
    // Các nguồn phụ lỗi riêng lẻ không làm hỏng cả màn hình: hiện phần còn lại và báo phần thiếu.
    final unavailable = <String>{};
    Future<T> optional<T>(String name, Future<T> request, T fallback) =>
        optionalOrFallback(request, fallback, () => unavailable.add(name));
    final secondary = await Future.wait<dynamic>([
      optional<dynamic>('menu', _client.rpc('menu_for_sale'), <dynamic>[]),
      optional<dynamic>(
        'stock',
        _client
            .from('v_expected_stock')
            .select('ingredient_id, name, unit, expected_qty, last_count_at'),
        <dynamic>[],
      ),
      optional<dynamic>(
        'trend',
        _client.rpc('owner_sales_trend', params: {
          'p_business_start': businessStart.toUtc().toIso8601String(),
          'p_days': 7,
        }),
        <dynamic>[],
      ),
    ]);
    final menu = (secondary[0] as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    if (!applyRecipeCoverage(menu, dashboard)) unavailable.add('recipe');
    final expectedStock = (secondary[1] as List<dynamic>)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
    final recentSales = (secondary[2] as List<dynamic>)
        .whereType<Map>()
        .map((row) => DailySalesPoint.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);
    final notifications = (dashboard['notifications'] as List<dynamic>? ??
            const [])
        .whereType<Map>()
        .map((row) => OwnerNotification.fromMap(Map<String, dynamic>.from(row)))
        .toList(growable: false);

    return OwnerDashboardData(
      shifts: shifts,
      reports: reports,
      openShift: dashboard['open_shift'] is Map
          ? Map<String, dynamic>.from(dashboard['open_shift'] as Map)
          : null,
      cashSales: (dashboard['cash_sales'] as num?)?.toInt() ?? 0,
      transferSales: (dashboard['transfer_sales'] as num?)?.toInt() ?? 0,
      yesterdaySales: (dashboard['yesterday_sales'] as num?)?.toInt() ?? 0,
      billCount: (dashboard['bill_count'] as num?)?.toInt() ?? 0,
      pendingInvites: (dashboard['pending_invites'] as num?)?.toInt() ?? 0,
      activeStaffCount: (dashboard['active_staff_count'] as num?)?.toInt() ?? 0,
      menu: menu,
      expectedStock: expectedStock,
      lowStock: (dashboard['low_stock'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      notifications: notifications,
      missingRecipeCount:
          (dashboard['missing_recipe_count'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.now(),
      businessStart: businessStart,
      businessEnd: businessEnd,
      recentSales: recentSales,
      pendingReviewCount:
          (dashboard['pending_review_count'] as num?)?.toInt() ?? 0,
      unavailable: unavailable,
    );
  }

  @override
  Future<OwnerShiftPage> loadShiftPage({
    required DateTime from,
    required DateTime to,
    String filter = 'all',
    int limit = 10,
    DateTime? before,
  }) async {
    final result = await _client.rpc('owner_shift_list', params: {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
      'p_filter': filter,
      'p_limit': limit,
      'p_before': before?.toUtc().toIso8601String(),
    });
    if (result is! Map) {
      throw const FormatException('owner_shift_list trả sai định dạng');
    }
    final items = (result['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .where((row) => row['report'] is Map && row['shift'] is Map)
        .map((row) => OwnerShiftReport(
              shift: Map<String, dynamic>.from(row['shift'] as Map),
              report: Map<String, dynamic>.from(row['report'] as Map),
              review:
                  Map<String, dynamic>.from(row['review'] as Map? ?? const {}),
            ))
        .toList(growable: false);
    return OwnerShiftPage(
      items: items,
      hasMore: result['has_more'] == true,
      nextBefore: DateTime.tryParse('${result['next_before']}'),
      openShift: result['open_shift'] is Map
          ? Map<String, dynamic>.from(result['open_shift'] as Map)
          : null,
    );
  }

  @override
  Future<Map<String, dynamic>> loadShiftReport(String shiftId) async {
    final result = await _client.rpc('shift_report', params: {'p_shift': shiftId});
    if (result is! Map) {
      throw const FormatException('shift_report trả sai định dạng');
    }
    return Map<String, dynamic>.from(result);
  }

  @override
  Future<void> correctWaste(String wasteId, int newQty, String reason) async {
    await _client.rpc('correct_waste', params: {
      'p_waste': wasteId,
      'p_new_qty': newQty,
      'p_reason': reason,
    });
  }

  @override
  Future<void> correctPurchase(
      String purchaseId, int newQty, String reason) async {
    await _client.rpc('correct_purchase', params: {
      'p_purchase': purchaseId,
      'p_new_qty': newQty,
      'p_reason': reason,
    });
  }

  @override
  Future<void> setShiftReview(
      String shiftId, bool handled, String? note) async {
    await _client.rpc('set_shift_review', params: {
      'p_shift': shiftId,
      'p_handled': handled,
      'p_note': note,
    });
  }

  @override
  Future<void> markNotificationsRead(List<String> keys) async {
    await _client.rpc('mark_owner_notifications_read', params: {
      'p_keys': keys,
    });
  }
}
