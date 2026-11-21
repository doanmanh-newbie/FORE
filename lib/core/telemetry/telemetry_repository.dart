import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/rpc_client.dart';

/// Tên sự kiện gửi lên `log_event` (chỉ chữ thường, số, `_`, `.` — database kiểm tra).
abstract final class TelemetryEvents {
  static const shiftOpen = 'shift_open';
  static const shiftClose = 'shift_close';
  static const billPaid = 'bill_paid';
}

/// Ghi lỗi, sự kiện và lịch sử đăng nhập lên database (`09_admin.sql`).
///
/// Mọi hàm KHÔNG BAO GIỜ ném lỗi: ghi log hỏng (mất mạng, chưa đăng nhập) thì bỏ qua,
/// để việc ghi log không làm hỏng nghiệp vụ hay gây vòng lặp lỗi.
abstract interface class TelemetryRepository {
  /// `log_error`. `shopId` null: database tự lấy quán đang chọn.
  Future<void> logError({
    required String message,
    String? stack,
    String? shopId,
    String? appVersion,
    String? platform,
    Map<String, dynamic>? context,
  });

  /// `log_event`. `shopId` null: database tự lấy quán đang chọn.
  Future<void> logEvent(String name,
      {Map<String, dynamic>? props, String? shopId});

  /// `record_login`: IP và user agent do server lấy từ header.
  Future<void> recordLogin();
}

/// Gửi mà không chờ và không bao giờ ném lỗi: nghiệp vụ (mở ca, thanh toán, đăng nhập)
/// không bị chậm hay hỏng vì ghi log.
extension FireAndForgetTelemetry on TelemetryRepository {
  void trackEvent(String name, {Map<String, dynamic>? props, String? shopId}) =>
      _fire(() => logEvent(name, props: props, shopId: shopId));

  void trackLogin() => _fire(recordLogin);

  static void _fire(Future<void> Function() send) {
    try {
      unawaited(send().catchError((Object e) {
        debugPrint('Fore: ghi telemetry lỗi: $e');
      }));
    } catch (e) {
      debugPrint('Fore: ghi telemetry lỗi: $e');
    }
  }
}

/// Bản không làm gì: mặc định cho controller khi không truyền telemetry (test, màn hình độc lập).
class NoopTelemetryRepository implements TelemetryRepository {
  const NoopTelemetryRepository();

  @override
  Future<void> logError({
    required String message,
    String? stack,
    String? shopId,
    String? appVersion,
    String? platform,
    Map<String, dynamic>? context,
  }) async {}

  @override
  Future<void> logEvent(String name,
      {Map<String, dynamic>? props, String? shopId}) async {}

  @override
  Future<void> recordLogin() async {}
}

class RpcTelemetryRepository implements TelemetryRepository {
  RpcTelemetryRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<void> logError({
    required String message,
    String? stack,
    String? shopId,
    String? appVersion,
    String? platform,
    Map<String, dynamic>? context,
  }) =>
      _send('log_error', {
        'p_message': message,
        'p_stack': stack,
        'p_shop_id': shopId,
        'p_app_version': appVersion,
        'p_platform': platform,
        'p_context': context,
      });

  @override
  Future<void> logEvent(String name,
          {Map<String, dynamic>? props, String? shopId}) =>
      _send(
          'log_event', {'p_name': name, 'p_props': props, 'p_shop_id': shopId});

  @override
  Future<void> recordLogin() => _send('record_login');

  Future<void> _send(String fn, [Map<String, dynamic>? params]) async {
    try {
      await _rpc.call(fn, params);
    } catch (e) {
      // Không ném tiếp, không gọi lại log_error (tránh vòng lặp).
      debugPrint('Fore: không ghi được $fn: $e');
    }
  }
}
