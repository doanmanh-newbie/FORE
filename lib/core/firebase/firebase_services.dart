import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Trạng thái kết nối Firebase của máy này.
enum FirebaseLink {
  /// Đang khởi tạo.
  connecting,

  /// Firebase Core đã chạy.
  connected,

  /// Nền tảng chưa hỗ trợ (web chưa có cấu hình, desktop).
  unsupported,

  /// Có nền tảng nhưng khởi tạo lỗi (thường: thiếu `google-services.json`).
  failed,
}

/// Các dịch vụ Firebase app dùng ngoài Cloud Messaging: Analytics (sự kiện, màn hình) và
/// Crashlytics (báo lỗi). Dữ liệu nghiệp vụ, đăng nhập, lưu ảnh vẫn ở Supabase.
///
/// Mọi lời gọi đều an toàn khi Firebase không có: không ném lỗi, chỉ bỏ qua.
abstract class FirebaseServices extends ChangeNotifier {
  FirebaseLink get link;

  /// Lỗi khởi tạo (để màn "Kết nối Firebase" hiển thị), nếu có.
  String? get error;

  /// Mã dự án Firebase khi đã kết nối.
  String? get projectId;

  bool get analyticsEnabled;
  bool get crashlyticsEnabled;

  Future<void> init();
  Future<void> setAnalyticsEnabled(bool value);
  Future<void> setCrashlyticsEnabled(bool value);

  /// Ghi một sự kiện Analytics (tên snake_case, tối đa 40 ký tự).
  Future<void> logEvent(String name, [Map<String, Object>? params]);

  /// Gửi lỗi lên Crashlytics (không làm sập app).
  Future<void> recordError(Object error, StackTrace? stack,
      {bool fatal = false, String? reason});

  /// Ghi màn hình đang xem lên Analytics (gắn vào `MaterialApp.navigatorObservers`).
  List<NavigatorObserver> get navigatorObservers;
}

/// Không có Firebase (test, web chưa cấu hình).
class NoopFirebaseServices extends FirebaseServices {
  NoopFirebaseServices({this.link = FirebaseLink.unsupported});

  @override
  final FirebaseLink link;
  @override
  String? get error => null;
  @override
  String? get projectId => null;
  @override
  bool get analyticsEnabled => false;
  @override
  bool get crashlyticsEnabled => false;
  @override
  Future<void> init() async {}
  @override
  Future<void> setAnalyticsEnabled(bool value) async {}
  @override
  Future<void> setCrashlyticsEnabled(bool value) async {}
  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {}
  @override
  Future<void> recordError(Object error, StackTrace? stack,
      {bool fatal = false, String? reason}) async {}
  @override
  List<NavigatorObserver> get navigatorObservers => const [];
}

/// Firebase thật trên Android/iOS (đọc `google-services.json` qua plugin Gradle).
class DeviceFirebaseServices extends FirebaseServices {
  static const _analyticsKey = 'firebase.analytics.enabled.v1';
  static const _crashlyticsKey = 'firebase.crashlytics.enabled.v1';

  FirebaseLink _link = FirebaseLink.connecting;
  String? _error;
  String? _projectId;
  bool _analytics = true;
  bool _crashlytics = true;
  FirebaseAnalyticsObserver? _observer;

  @override
  FirebaseLink get link => _link;
  @override
  String? get error => _error;
  @override
  String? get projectId => _projectId;
  @override
  bool get analyticsEnabled => _analytics && _link == FirebaseLink.connected;
  @override
  bool get crashlyticsEnabled =>
      _crashlytics && _link == FirebaseLink.connected;

  static bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<void> init() async {
    if (!platformSupported) {
      _set(FirebaseLink.unsupported);
      return;
    }
    try {
      final app = Firebase.apps.isEmpty
          ? await Firebase.initializeApp()
          : Firebase.app();
      _projectId = app.options.projectId;
      final prefs = await SharedPreferences.getInstance();
      _analytics = prefs.getBool(_analyticsKey) ?? true;
      _crashlytics = prefs.getBool(_crashlyticsKey) ?? true;
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(_analytics);
      // Bản debug không gửi crash để khỏi lẫn lỗi lúc phát triển vào số liệu thật.
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(_crashlytics && !kDebugMode);
      _observer = FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance);
      _set(FirebaseLink.connected);
    } catch (e) {
      debugPrint('Fore: Firebase chưa sẵn sàng: $e');
      _error = '$e';
      _set(FirebaseLink.failed);
    }
  }

  @override
  Future<void> setAnalyticsEnabled(bool value) async {
    if (_link != FirebaseLink.connected) return;
    _analytics = value;
    notifyListeners();
    await _quietly(() async {
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(value);
      await (await SharedPreferences.getInstance()).setBool(_analyticsKey, value);
    });
  }

  @override
  Future<void> setCrashlyticsEnabled(bool value) async {
    if (_link != FirebaseLink.connected) return;
    _crashlytics = value;
    notifyListeners();
    await _quietly(() async {
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(value && !kDebugMode);
      await (await SharedPreferences.getInstance())
          .setBool(_crashlyticsKey, value);
    });
  }

  @override
  Future<void> logEvent(String name, [Map<String, Object>? params]) async {
    if (!analyticsEnabled) return;
    await _quietly(() =>
        FirebaseAnalytics.instance.logEvent(name: name, parameters: params));
  }

  @override
  Future<void> recordError(Object error, StackTrace? stack,
      {bool fatal = false, String? reason}) async {
    if (_link != FirebaseLink.connected) return;
    await _quietly(() => FirebaseCrashlytics.instance
        .recordError(error, stack, fatal: fatal, reason: reason));
  }

  @override
  List<NavigatorObserver> get navigatorObservers =>
      _observer == null ? const [] : [_observer!];

  void _set(FirebaseLink link) {
    _link = link;
    notifyListeners();
  }

  Future<void> _quietly(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      debugPrint('Fore: Firebase lỗi: $e');
    }
  }
}
