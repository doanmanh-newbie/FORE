import 'package:flutter/foundation.dart';

import '../../../core/application/notify_when_alive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/validation/field_validator.dart';
import '../domain/auth_repository.dart';

/// Logic màn Đăng nhập: kiểm tra ô nhập, gọi đăng nhập, giữ trạng thái.
/// Màn hình chỉ vẽ và chuyển sự kiện vào đây.
class LoginController extends ChangeNotifier with NotifyWhenAlive {
  LoginController(this._repository);

  final AuthRepository _repository;

  static const _emailValidator = CompositeValidator([
    RequiredValidator('Nhập email.'),
    EmailFormatValidator('Email chưa đúng định dạng.'),
  ]);
  static const _passwordValidator = RequiredValidator('Nhập mật khẩu.');

  bool _loading = false;
  bool get loading => _loading;

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
      return true;
    } on AppFailure catch (f) {
      _formError = f.userMessage;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
