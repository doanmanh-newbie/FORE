import 'package:flutter/foundation.dart';

import '../../../core/config/app_config.dart';
import '../../../core/application/notify_when_alive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/validation/field_validator.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

enum RegisterStatus { editing, loading, success }

/// Logic màn Đăng ký: kiểm tra từng ô, gọi tạo tài khoản, giữ trạng thái.
class RegisterController extends ChangeNotifier with NotifyWhenAlive {
  RegisterController(this._repository);

  final AuthRepository _repository;

  String _password = '';

  static const _nameValidator = RequiredValidator('Nhập họ tên.');
  static const _emailValidator = CompositeValidator([
    RequiredValidator('Nhập email.'),
    EmailFormatValidator('Email chưa đúng định dạng.'),
  ]);
  static const _passwordValidator = MinLengthValidator(
    AppConfig.minPasswordLength,
    'Mật khẩu cần ít nhất ${AppConfig.minPasswordLength} ký tự.',
  );
  late final FieldValidator _confirmValidator = MatchesValidator(
    () => _password,
    'Hai mật khẩu chưa giống nhau.',
  );

  RegisterStatus _status = RegisterStatus.editing;
  RegisterStatus get status => _status;

  /// Email đã đăng ký (hiện ở màn "kiểm tra email" khi Supabase bắt xác nhận email).
  String _registeredEmail = '';
  String get registeredEmail => _registeredEmail;

  /// `true`: đăng ký xong đã đăng nhập luôn (đi tiếp tạo quán).
  bool _signedIn = false;
  bool get signedIn => _signedIn;

  String? nameError;
  String? emailError;
  String? passwordError;
  String? confirmError;

  /// Lỗi chung không gắn với ô nào (mất mạng, lỗi lạ).
  String? formError;

  bool get loading => _status == RegisterStatus.loading;

  Future<void> submit({
    required String fullName,
    required String email,
    required String password,
    required String confirm,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    _password = password;

    nameError = _nameValidator.validate(fullName);
    emailError = _emailValidator.validate(cleanEmail);
    passwordError = _passwordValidator.validate(password);
    confirmError = _confirmValidator.validate(confirm);
    formError = null;

    final hasError = [nameError, emailError, passwordError, confirmError]
        .any((e) => e != null);
    if (hasError) {
      notifyListeners();
      return;
    }

    _status = RegisterStatus.loading;
    notifyListeners();
    try {
      _signedIn = await _repository.signUp(
        fullName: fullName.trim(),
        email: cleanEmail,
        password: password,
        accountKind: AccountKind.owner,
      );
      _registeredEmail = cleanEmail;
      _status = RegisterStatus.success;
    } on EmailAlreadyRegisteredFailure catch (f) {
      emailError = f.userMessage;
      _status = RegisterStatus.editing;
    } on WeakPasswordFailure catch (f) {
      passwordError = f.userMessage;
      _status = RegisterStatus.editing;
    } on AppFailure catch (f) {
      formError = f.userMessage;
      _status = RegisterStatus.editing;
    }
    notifyListeners();
  }
}
