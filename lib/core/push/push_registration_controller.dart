import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/rpc_client.dart';
import 'push_notification_service.dart';

/// Lưu / gỡ token FCM trên database (`09_admin.sql`).
abstract interface class PushTokenRepository {
  Future<void> register(String token, String platform);
  Future<void> unregister(String token);
}

class RpcPushTokenRepository implements PushTokenRepository {
  RpcPushTokenRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<void> register(String token, String platform) => _rpc
      .call('register_fcm_token', {'p_token': token, 'p_platform': platform});

  @override
  Future<void> unregister(String token) =>
      _rpc.call('unregister_fcm_token', {'p_token': token});
}

/// Trạng thái push của máy này (để màn cài đặt có thể hiển thị).
enum PushState {
  /// Chưa có chủ quán đăng nhập.
  idle,

  /// Máy chưa cấu hình Firebase: không có push, app vẫn chạy.
  unavailable,

  /// Chưa có quyền thông báo và chưa hỏi: chờ người dùng bấm "Bật" ở màn giải thích
  /// (chỉ khi controller tạo với `isPermissionGranted`).
  awaitingPermission,

  /// Người dùng từ chối quyền thông báo.
  denied,

  /// Đã lưu token: sẽ nhận push.
  registered,

  /// Lỗi mạng / server khi lưu token (thử lại ở lần đăng nhập hoặc làm mới token sau).
  failed,
}

/// Gắn push với phiên đăng nhập: chủ quán đăng nhập thì xin quyền, lấy token và lưu;
/// đăng xuất / đổi tài khoản thì hủy token cũ. Mọi lỗi đều được nuốt: push hỏng không
/// bao giờ làm hỏng đăng nhập hay app.
class PushRegistrationController extends ChangeNotifier {
  PushRegistrationController(this._service, this._tokens,
      {Future<bool> Function()? isPermissionGranted})
      : _isPermissionGranted = isPermissionGranted;

  final PushNotificationService _service;
  final PushTokenRepository _tokens;

  /// Kiểm tra quyền mà không hỏi. Có giá trị thì khi đăng nhập KHÔNG tự bật hộp thoại hệ thống:
  /// đã có quyền thì đăng ký luôn, chưa có thì chờ [enable] (sau màn giải thích của app).
  /// `null` (test cũ): hỏi quyền ngay khi đăng nhập như trước.
  final Future<bool> Function()? _isPermissionGranted;

  PushState _state = PushState.idle;
  PushState get state => _state;

  /// Token FCM đã lưu của máy (màn "Kết nối Firebase" hiển thị rút gọn).
  String? get token => _token;

  String? _userId;
  String? _token;
  int _generation = 0;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<PushMessage>? _messageSub;
  final _messages = StreamController<PushMessage>.broadcast();
  bool _disposed = false;

  /// Thông báo đến khi app đang mở (app hiện thanh báo).
  Stream<PushMessage> get messages => _messages.stream;

  /// Gọi mỗi khi phiên đổi. `userId` = null: đăng xuất hoặc không phải chủ quán.
  Future<void> bindUser(String? userId) async {
    if (_disposed || userId == _userId) return;
    final generation = ++_generation;
    final previous = _userId;
    final oldToken = _token;
    _userId = userId;
    _token = null;
    await _refreshSub?.cancel();
    _refreshSub = null;

    if (previous != null && oldToken != null) {
      // Đăng xuất / đổi người: gỡ token khỏi tài khoản cũ. RPC có thể thất bại vì đã mất
      // phiên, nên hủy luôn token trên máy: lần gửi sau FCM báo UNREGISTERED và server tự xóa.
      await _quietly(() => _tokens.unregister(oldToken));
      await _quietly(_service.unregisterDevice);
    }
    if (userId == null) {
      _setState(PushState.idle);
      return;
    }

    if (!await _guard(_service.init, fallback: false)) {
      if (generation == _generation) _setState(PushState.unavailable);
      return;
    }
    if (generation != _generation) return;
    _messageSub ??= _service.onMessage.listen(
      (m) {
        if (!_messages.isClosed) _messages.add(m);
      },
      onError: (Object e) => debugPrint('Fore: lỗi nhận push: $e'),
    );

    final check = _isPermissionGranted;
    if (check != null && !await _guard(check, fallback: false)) {
      if (generation == _generation) _setState(PushState.awaitingPermission);
      return;
    }
    await _requestAndRegister(generation);
  }

  /// Người dùng đồng ý ở màn giải thích: hỏi quyền hệ thống rồi đăng ký máy.
  /// Trả `true` nếu được quyền. Không có ai đăng nhập hoặc Firebase chưa sẵn sàng thì `false`.
  Future<bool> enable() async {
    if (_disposed || _userId == null) return false;
    if (_state == PushState.unavailable || _state == PushState.idle) return false;
    await _requestAndRegister(_generation);
    return _state != PushState.denied;
  }

  Future<void> _requestAndRegister(int generation) async {
    if (!await _guard(_service.requestPermission, fallback: false)) {
      if (generation == _generation) _setState(PushState.denied);
      return;
    }
    if (generation != _generation) return;
    await _refreshSub?.cancel();
    // Nghe token TRƯỚC khi đăng ký để không lỡ token đầu tiên; token mới về sau cũng qua đây.
    _refreshSub = _service.onToken.listen(
      (t) => _register(t, generation),
      onError: (Object e) {
        debugPrint('Fore: lỗi nhận token push: $e');
        if (generation == _generation) _setState(PushState.failed);
      },
    );
    final ok = await _guard(() async {
      await _service.registerDevice();
      return true;
    }, fallback: false);
    if (!ok && generation == _generation) _setState(PushState.failed);
  }

  Future<void> _register(String token, int generation) async {
    try {
      await _tokens.register(token, _service.platform);
      if (generation != _generation) return;
      _token = token;
      _setState(PushState.registered);
    } catch (e) {
      debugPrint('Fore: không lưu được token push: $e');
      if (generation == _generation) _setState(PushState.failed);
    }
  }

  Future<T> _guard<T>(Future<T> Function() action,
      {required T fallback}) async {
    try {
      return await action();
    } catch (e) {
      debugPrint('Fore: push lỗi: $e');
      return fallback;
    }
  }

  Future<void> _quietly(Future<void> Function() action) =>
      _guard<void>(action, fallback: null);

  void _setState(PushState s) {
    if (_disposed || _state == s) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _refreshSub?.cancel();
    _messageSub?.cancel();
    _messages.close();
    super.dispose();
  }
}
