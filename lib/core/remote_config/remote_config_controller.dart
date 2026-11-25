import 'package:flutter/foundation.dart';

import '../errors/app_failure.dart';
import 'app_config_repository.dart';
import 'remote_app_config.dart';

/// Tải cấu hình từ xa khi có người đăng nhập (`get_app_config` cần đăng nhập)
/// và quyết định app được vào bình thường, bị chặn bảo trì hay phải cập nhật.
///
/// Lỗi mạng / bảng trống: giữ cấu hình đã có, chưa có thì dùng [RemoteAppConfig.fallback]
/// (không chặn), để sự cố máy chủ không khóa người dùng ngoài app.
class RemoteConfigController extends ChangeNotifier {
  RemoteConfigController(this._repository, {required this.appVersion});

  final AppConfigRepository _repository;
  final String appVersion;

  RemoteAppConfig _config = RemoteAppConfig.fallback;
  RemoteAppConfig get config => _config;

  bool _loading = false;
  bool get loading => _loading;

  bool _updateDismissed = false;
  String? _userId;
  int _generation = 0;
  bool _disposed = false;

  RemoteConfigVerdict get verdict {
    if (_userId == null) return RemoteConfigVerdict.ok;
    final v = _config.verdictFor(appVersion);
    if (v == RemoteConfigVerdict.updateSuggested && _updateDismissed) {
      return RemoteConfigVerdict.ok;
    }
    return v;
  }

  /// Gắn với người đang đăng nhập (`null` = đã đăng xuất). Đổi người thì tải lại.
  void bindUser(String? userId) {
    if (userId == _userId) return;
    _userId = userId;
    _generation++;
    _updateDismissed = false;
    if (userId == null) {
      _config = RemoteAppConfig.fallback;
      _loading = false;
      _notify();
      return;
    }
    load();
  }

  /// Tải lại cấu hình (khi đăng nhập, hoặc bấm "Kiểm tra lại" ở màn bảo trì).
  Future<void> load() async {
    if (_userId == null) return;
    final generation = _generation;
    _loading = true;
    _notify();
    try {
      final config = await _repository.fetch();
      if (generation != _generation) return;
      _config = config;
    } on AppFailure catch (f) {
      if (generation != _generation) return;
      debugPrint('Fore: không tải được cấu hình từ xa: ${f.code}');
    } catch (e) {
      if (generation != _generation) return;
      debugPrint('Fore: không tải được cấu hình từ xa: $e');
    }
    _loading = false;
    _notify();
  }

  /// Bỏ qua lời nhắc cập nhật không bắt buộc cho tới lần đăng nhập sau.
  void dismissUpdate() {
    _updateDismissed = true;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
