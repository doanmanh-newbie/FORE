import 'package:flutter/foundation.dart';

import '../../../core/application/notify_when_alive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';

/// Đăng nhập nhân viên bằng số điện thoại hoặc email cùng mật khẩu.
class StaffLoginController extends ChangeNotifier with NotifyWhenAlive {
  StaffLoginController(this._repository);

  final AuthRepository _repository;

  ContactKind _kind = ContactKind.phone;
  ContactKind get kind => _kind;

  bool _loading = false;
  bool get loading => _loading;

  String? contactError;
  String? passwordError;
  String? formError;

  void setKind(ContactKind kind) {
    if (_loading || kind == _kind) return;
    _kind = kind;
    contactError = passwordError = formError = null;
    notifyListeners();
  }

  /// Trả về true khi đã đăng nhập.
  Future<bool> submit(String rawContact, String password) async {
    contactError = passwordError = formError = null;
    final parsed = StaffContact.tryParse(_kind, rawContact);
    final contact = parsed.contact;
    contactError = parsed.error;
    if (password.isEmpty) passwordError = 'Nhập mật khẩu.';
    if (contact == null || passwordError != null) {
      notifyListeners();
      return false;
    }

    _loading = true;
    notifyListeners();
    try {
      await _repository.signInStaff(contact, password);
      _loading = false;
      notifyListeners();
      return true;
    } on InvalidCredentialsFailure {
      formError = 'Số/email hoặc mật khẩu chưa đúng.';
    } on AppFailure catch (failure) {
      formError = failure.userMessage;
    }
    _loading = false;
    notifyListeners();
    return false;
  }
}
