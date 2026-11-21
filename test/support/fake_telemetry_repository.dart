import 'package:fore/core/telemetry/telemetry_repository.dart';

/// Bản giả của [TelemetryRepository]: ghi lại mọi lần gọi để test kiểm tra.
class FakeTelemetryRepository implements TelemetryRepository {
  final List<Map<String, dynamic>> errors = [];
  final List<({String name, Map<String, dynamic>? props, String? shopId})>
      events = [];
  int loginCount = 0;

  /// Đặt `true` để giả lập gửi thất bại (bản thật không bao giờ ném, nhưng test cần chắc
  /// nơi gọi vẫn an toàn kể cả khi có ném).
  bool fail = false;

  @override
  Future<void> logError({
    required String message,
    String? stack,
    String? shopId,
    String? appVersion,
    String? platform,
    Map<String, dynamic>? context,
  }) async {
    errors.add({
      'message': message,
      'stack': stack,
      'shop_id': shopId,
      'app_version': appVersion,
      'platform': platform,
      'context': context,
    });
    if (fail) throw StateError('telemetry down');
  }

  @override
  Future<void> logEvent(String name,
      {Map<String, dynamic>? props, String? shopId}) async {
    events.add((name: name, props: props, shopId: shopId));
    if (fail) throw StateError('telemetry down');
  }

  @override
  Future<void> recordLogin() async {
    loginCount++;
    if (fail) throw StateError('telemetry down');
  }
}
