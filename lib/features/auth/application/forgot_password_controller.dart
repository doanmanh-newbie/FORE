import 'package:flutter/foundation.dart';

import '../../../core/application/notify_when_alive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/validation/field_validator.dart';
import '../domain/auth_repository.dart';

/// Gửi email đặt lại mật khẩu.
class ForgotPasswordController extends ChangeNotifier with NotifyWhenAlive {
  ForgotPasswordController(this._repository);

  final AuthRepository _repository;

  static const _emailValidator = CompositeValidator([
    RequiredValidator('Nhập email.'),
    EmailFormatValidator('Email chưa đúng định dạng.'),
  ]);

  bool loading = false;
  bool sent = false;
  String? error;

  Future<void> submit(String email) async {
    final clean = email.trim().toLowerCase();
    error = _emailValidator.validate(clean);
    if (error != null) {
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      await _repository.sendPasswordReset(clean);
      sent = true;
    } on AppFailure catch (f) {
      error = f.userMessage;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
