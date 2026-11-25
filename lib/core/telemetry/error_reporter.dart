import 'package:flutter/foundation.dart';

import 'telemetry_repository.dart';

/// Nhận lỗi chưa bắt từ `FlutterError.onError` / `PlatformDispatcher.onError`
/// và gửi qua [TelemetryRepository.logError].
///
/// An toàn khi chính việc gửi bị lỗi: không gửi khi chưa đăng nhập, không gửi lồng nhau,
/// và giới hạn số lỗi mỗi phút để một lỗi lặp trong `build` không xả hàng nghìn dòng.
class ErrorReporter {
  ErrorReporter({
    required TelemetryRepository telemetry,
    required this.appVersion,
    required this.platform,
    required bool Function() isLoggedIn,
    this.maxPerMinute = 20,
    DateTime Function()? now,
  })  : _telemetry = telemetry,
        _isLoggedIn = isLoggedIn,
        _now = now ?? DateTime.now;

  final TelemetryRepository _telemetry;
  final bool Function() _isLoggedIn;
  final DateTime Function() _now;
  final String appVersion;
  final String platform;
  final int maxPerMinute;

  bool _sending = false;
  DateTime? _windowStart;
  int _sentInWindow = 0;

  /// Gắn vào `FlutterError.onError`. Vẫn in lỗi ra console như mặc định.
  void handleFlutterError(FlutterErrorDetails details) {
    FlutterError.presentError(details);
    report(
      details.exception,
      details.stack,
      context: {
        'source': 'flutter',
        if (details.library != null) 'library': details.library,
        if (details.context != null) 'context': details.context.toString(),
      },
    );
  }

  /// Gắn vào `PlatformDispatcher.onError`. Trả `true` = đã xử lý (app không bị tắt).
  bool handlePlatformError(Object error, StackTrace stack) {
    debugPrint('Fore: lỗi chưa bắt: $error\n$stack');
    report(error, stack, context: const {'source': 'platform_dispatcher'});
    return true;
  }

  /// Gửi một lỗi. Trả `true` nếu đã gửi đi (dùng cho test).
  bool report(Object error, StackTrace? stack,
      {Map<String, dynamic>? context}) {
    // Lỗi phát sinh ngay trong lúc đang gửi lỗi: bỏ, tránh lặp.
    if (_sending) return false;
    _sending = true;
    try {
      if (!_isLoggedIn() || !_takeQuota()) return false;
      _telemetry
          .logError(
            message: error.toString(),
            stack: stack?.toString(),
            appVersion: appVersion,
            platform: platform,
            context: context,
          )
          .catchError((Object _) {});
      return true;
    } catch (_) {
      return false;
    } finally {
      _sending = false;
    }
  }

  bool _takeQuota() {
    final now = _now();
    final start = _windowStart;
    if (start == null || now.difference(start) >= const Duration(minutes: 1)) {
      _windowStart = now;
      _sentInWindow = 0;
    }
    if (_sentInWindow >= maxPerMinute) return false;
    _sentInWindow++;
    return true;
  }
}

/// Tên nền tảng gửi kèm lỗi: `web`, `android`, `ios`, `windows`...
String currentPlatformName() => kIsWeb ? 'web' : defaultTargetPlatform.name;
