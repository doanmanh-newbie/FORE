import 'package:flutter/foundation.dart';

import '../../../core/application/notify_when_alive.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';

/// Tạo tài khoản nhân viên bằng số điện thoại hoặc email, tên, ngày sinh và mật khẩu.
/// Tạo xong là đăng nhập luôn (không còn bước xác nhận OTP).
class StaffRegisterController extends ChangeNotifier with NotifyWhenAlive {
  StaffRegisterController(this._repository);

  final AuthRepository _repository;

  ContactKind _kind = ContactKind.phone;
  ContactKind get kind => _kind;

  bool _loading = false;
  bool get loading => _loading;

  String? contactError;
  String? nameError;
  String? birthDateError;
  String? passwordError;
  String? confirmError;
  String? formError;

  void setKind(ContactKind kind) {
    if (_loading || kind == _kind) return;
    _kind = kind;
    contactError = formError = null;
    notifyListeners();
  }

  void clearContactError() {
    if (contactError == null && formError == null) return;
    contactError = formError = null;
    notifyListeners();
  }

  void clearNameError() {
    if (nameError == null) return;
    nameError = null;
    notifyListeners();
  }

  void clearBirthDateError() {
    if (birthDateError == null) return;
    birthDateError = null;
    notifyListeners();
  }

  /// Trả về true khi đã tạo tài khoản và đăng nhập.
  Future<bool> submit({
    required String contactText,
    required String fullName,
    required DateTime? birthDate,
    required String password,
    required String confirm,
    DateTime? now,
  }) async {
    final today = now ?? DateTime.now();
    final parsed = StaffContact.tryParse(_kind, contactText);
    final contact = parsed.contact;
    final name = fullName.trim();

    contactError = parsed.error;
    nameError = name.isEmpty ? 'Nhập tên hiển thị.' : null;
    birthDateError = birthDate == null
        ? 'Chọn ngày sinh.'
        : birthDate.isAfter(today)
            ? 'Ngày sinh không được ở tương lai.'
            : null;
    passwordError = password.length < AppConfig.minPasswordLength
        ? 'Mật khẩu cần ít nhất ${AppConfig.minPasswordLength} ký tự.'
        : null;
    confirmError = confirm == password ? null : 'Hai mật khẩu chưa giống nhau.';
    formError = null;

    if (contact == null ||
        birthDate == null ||
        [nameError, birthDateError, passwordError, confirmError]
            .any((e) => e != null)) {
      notifyListeners();
      return false;
    }

    _loading = true;
    notifyListeners();
    try {
      await _repository.signUpStaff(
        contact,
        password,
        fullName: name,
        birthDate: birthDate,
      );
      _loading = false;
      notifyListeners();
      return true;
    } on StaffAlreadyExistsFailure catch (failure) {
      contactError = failure.userMessage;
    } on WeakPasswordFailure catch (failure) {
      passwordError = failure.userMessage;
    } on ContactInvalidFailure catch (failure) {
      contactError = failure.userMessage;
    } on AppFailure catch (failure) {
      formError = failure.userMessage;
    }
    _loading = false;
    notifyListeners();
    return false;
  }
}
