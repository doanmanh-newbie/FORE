import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Một thông báo nhận được khi app đang mở.
class PushMessage {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;

  /// Dữ liệu kèm theo (`kind`, `shop_id`, `shift_id`, `bill_id`... do Edge Function gửi).
  final Map<String, String> data;
}

/// Lớp mỏng bọc Firebase Messaging để phần logic ([PushRegistrationController]) test được bằng bản giả.
abstract interface class PushNotificationService {
  /// Khởi tạo Firebase. Trả `false` khi máy chưa cấu hình Firebase (thiếu `google-services.json`,
  /// chạy web/desktop chưa có options...) — khi đó app chạy bình thường, chỉ không có push.
  Future<bool> init();

  /// Xin quyền hiển thị thông báo. `true` nếu được phép (kể cả tạm thời).
  Future<bool> requestPermission();

  /// Đăng ký máy với FCM. Token (và mọi token mới về sau) đến qua [onToken].
  Future<void> registerDevice();

  /// Token FCM của máy: lần đầu sau [registerDevice], và mỗi khi FCM cấp token mới.
  Stream<String> get onToken;

  /// Thông báo đến khi app đang mở (khi app ở nền, hệ điều hành tự hiển thị).
  Stream<PushMessage> get onMessage;

  /// Hủy đăng ký máy (đăng xuất): token cũ hết hiệu lực, lần gửi sau FCM báo UNREGISTERED
  /// và Edge Function tự xóa token khỏi database.
  Future<void> unregisterDevice();

  /// `android` / `ios` / `web` / `other` (khớp `device_tokens.platform`).
  String get platform;
}

/// Không có push (test, hoặc tắt hẳn).
class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Future<bool> init() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<void> registerDevice() async {}
  @override
  Stream<String> get onToken => const Stream.empty();
  @override
  Stream<PushMessage> get onMessage => const Stream.empty();
  @override
  Future<void> unregisterDevice() async {}
  @override
  String get platform => 'other';
}

/// Xử lý tin đến khi app ở nền/đã tắt. Thông báo có `notification` được hệ điều hành tự hiển thị,
/// nên ở đây không cần làm gì; hàm phải là hàm cấp cao nhất và giữ được khi build release.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

class FirebasePushNotificationService implements PushNotificationService {
  bool? _ready;

  FirebaseMessaging get _fm => FirebaseMessaging.instance;

  @override
  Future<bool> init() async {
    if (_ready != null) return _ready!;
    // Web cần FirebaseOptions riêng (chưa cấu hình); desktop không hỗ trợ FCM.
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return _ready = false;
    }
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      return _ready = true;
    } catch (e) {
      // Thường gặp: thiếu android/app/google-services.json khi chạy dev. Không làm crash app.
      debugPrint('Fore: chưa cấu hình Firebase, tắt push: $e');
      return _ready = false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    final s = await _fm.requestPermission();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  @override
  Future<void> registerDevice() => _fm.register();

  @override
  Stream<String> get onToken => _fm.onRegistered;

  @override
  Stream<PushMessage> get onMessage => FirebaseMessaging.onMessage.map(
        (m) => PushMessage(
          title: m.notification?.title,
          body: m.notification?.body,
          data: {
            for (final e in m.data.entries) e.key: '${e.value}',
          },
        ),
      );

  @override
  Future<void> unregisterDevice() => _fm.unregister();

  @override
  String get platform => switch (defaultTargetPlatform) {
        TargetPlatform.android => 'android',
        TargetPlatform.iOS => 'ios',
        _ => kIsWeb ? 'web' : 'other',
      };
}
