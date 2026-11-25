import 'dart:async';

import 'package:fore/core/push/push_notification_service.dart';

/// Bản giả của [PushNotificationService]: test tự quyết định Firebase có sẵn không,
/// người dùng cho quyền không, và tự phát token / thông báo.
class FakePushNotificationService implements PushNotificationService {
  /// `false`: mô phỏng máy chưa có google-services.json.
  bool configured = true;

  /// Ném lỗi khi khởi tạo (mô phỏng Firebase.initializeApp() lỗi).
  Object? initError;

  bool permissionGranted = true;

  /// Token phát ra ngay khi registerDevice() được gọi (null: không phát).
  String? tokenOnRegister = 'fcm-token-1-aaaaaaaaaaaaaaaaaaaaaaaa';

  int initCalls = 0;
  int permissionCalls = 0;
  int registerCalls = 0;
  int unregisterCalls = 0;

  final _tokens = StreamController<String>.broadcast();
  final _messages = StreamController<PushMessage>.broadcast();

  /// FCM cấp token mới (làm mới token).
  void emitToken(String token) => _tokens.add(token);

  /// Thông báo đến khi app đang mở.
  void emitMessage(PushMessage m) => _messages.add(m);

  @override
  Future<bool> init() async {
    initCalls++;
    if (initError != null) throw initError!;
    return configured;
  }

  @override
  Future<bool> requestPermission() async {
    permissionCalls++;
    return permissionGranted;
  }

  @override
  Future<void> registerDevice() async {
    registerCalls++;
    final t = tokenOnRegister;
    if (t != null) scheduleMicrotask(() => _tokens.add(t));
  }

  @override
  Stream<String> get onToken => _tokens.stream;

  @override
  Stream<PushMessage> get onMessage => _messages.stream;

  @override
  Future<void> unregisterDevice() async => unregisterCalls++;

  @override
  String get platform => 'android';
}
