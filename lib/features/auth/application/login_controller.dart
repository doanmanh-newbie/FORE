import 'package:flutter/foundation.dart';

import '../../../core/application/notify_when_alive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/telemetry/telemetry_repository.dart';
import '../../../core/validation/field_validator.dart';
import '../domain/auth_repository.dart';

/// Logic màn Đăng nhập: kiểm tra ô nhập, gọi đăng nhập, giữ trạng thái.
/// Màn hình chỉ vẽ và chuyển sự kiện vào đây.
class LoginController extends ChangeNotifier with NotifyWhenAlive {
  LoginController(this._repository,
      {TelemetryRepository telemetry = const NoopTelemetryRepository()})
      : _telemetry = telemetry;

  final AuthRepository _repository;
  final TelemetryRepository _telemetry;

  static const _emailValidator = CompositeValidator([
    RequiredValidator('Nhập email.'),
    EmailFormatValidator('Email chưa đúng định dạng.'),
  ]);
  static const _passwordValidator = RequiredValidator('Nhập mật khẩu.');

  bool _loading = false;

  /// Đang đăng nhập (email hoặc Google/Facebook): khóa cả form.
  bool get loading => _loading || _socialLoading != null;

  /// Chỉ nút email/mật khẩu đang quay.
  bool get passwordLoading => _loading;

  SocialProvider? _socialLoading;

  /// Nút Google/Facebook đang chờ (để quay đúng nút đó).
  SocialProvider? get socialLoading => _socialLoading;

  String? _emailError;
  String? get emailError => _emailError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  /// Lỗi chung (sai mật khẩu, mất mạng) hiện phía trên nút.
  String? _formError;
  String? get formError => _formError;

  /// Trả về `true` nếu đăng nhập thành công.
  Future<bool> submit({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();
    _emailError = _emailValidator.validate(cleanEmail);
    _passwordError = _passwordValidator.validate(password);
    _formError = null;
    if (_emailError != null || _passwordError != null) {
      notifyListeners();
      return false;
    }

    _loading = true;
    notifyListeners();
    try {
      await _repository.signIn(email: cleanEmail, password: password);
      _telemetry.trackLogin();
      return true;
    } on AppFailure catch (f) {
      _formError = f.userMessage;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Đăng nhập bằng Google/Facebook. Trả `true` nếu đã có phiên; người dùng tự hủy thì
  /// trả `false` và không hiện lỗi.
  Future<bool> signInWithSocial(SocialProvider provider) async {
    if (loading) return false;
    _emailError = null;
    _passwordError = null;
    _formError = null;
    _socialLoading = provider;
    notifyListeners();
    try {
      final user = await _repository.signInWithSocial(provider);
      if (user == null) return false;
      _telemetry.trackLogin();
      return true;
    } on AppFailure catch (f) {
      _formError = f.userMessage;
      return false;
    } finally {
      _socialLoading = null;
      notifyListeners();
    }
  }
}
