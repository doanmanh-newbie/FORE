import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/application/notify_when_alive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';

/// Tạo tài khoản nhân viên; chỉ hoàn tất khi người dùng xác minh OTP.
class StaffRegisterController extends ChangeNotifier with NotifyWhenAlive {
  StaffRegisterController(
    this._repository, {
    this.resendDelay = const Duration(seconds: 60),
  });

  final AuthRepository _repository;
  final Duration resendDelay;

  ContactKind _kind = ContactKind.phone;
  ContactKind get kind => _kind;

  bool _loading = false;
  bool get loading => _loading;

  bool _otpRequested = false;
  bool get otpRequested => _otpRequested;

  int _resendSeconds = 0;
  int get resendSeconds => _resendSeconds;
  bool get canResend => _otpRequested && !_loading && _resendSeconds == 0;

  String? contactError;
  String? nameError;
  String? birthDateError;
  String? otpError;
  String? formError;

  StaffContact? _challengeContact;
  String? _fullName;
  DateTime? _birthDate;
  Timer? _resendTimer;

  void setKind(ContactKind kind) {
    if (_loading || kind == _kind) return;
    _kind = kind;
    _challengeContact = null;
    _otpRequested = false;
    _clearTimer();
    contactError = otpError = formError = null;
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

  /// Gửi OTP đăng ký. Trả về true chỉ khi mã được gửi, chưa phải tài khoản đã đăng nhập.
  Future<bool> submit({
    required String contactText,
    required String fullName,
    required DateTime? birthDate,
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
    otpError = formError = null;

    if (contact == null || nameError != null || birthDateError != null) {
      notifyListeners();
      return false;
    }

    _challengeContact = contact;
    _fullName = name;
    _birthDate = birthDate;
    return _requestOtp(createUser: true);
  }

  Future<bool> verifyOtp(String rawToken) async {
    final contact = _challengeContact;
    final token = rawToken.trim();
    otpError = formError = null;
    if (contact == null) {
      formError = 'Hãy yêu cầu mã xác nhận trước.';
      notifyListeners();
      return false;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(token)) {
      otpError = 'Nhập mã xác nhận gồm 6 chữ số.';
      notifyListeners();
      return false;
    }

    _loading = true;
    notifyListeners();
    try {
      await _repository.verifyStaffOtp(contact, token);
      _loading = false;
      _clearTimer();
      notifyListeners();
      return true;
    } on AppFailure catch (failure) {
      otpError = failure.userMessage;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> resendOtp() async {
    if (!canResend || _challengeContact == null) return;
    await _requestOtp(createUser: true);
  }

  Future<bool> _requestOtp({required bool createUser}) async {
    _loading = true;
    notifyListeners();
    try {
      await _repository.requestStaffOtp(
        _challengeContact!,
        createUser: createUser,
        fullName: _fullName,
        birthDate: _birthDate,
      );
      _otpRequested = true;
      _startTimer();
      _loading = false;
      notifyListeners();
      return true;
    } on StaffAlreadyExistsFailure catch (failure) {
      contactError = failure.userMessage;
      _loading = false;
      notifyListeners();
      return false;
    } on AppFailure catch (failure) {
      formError = failure.userMessage;
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  void _startTimer() {
    _clearTimer();
    _resendSeconds = resendDelay.inSeconds;
    if (_resendSeconds == 0) return;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds <= 1) {
        _resendSeconds = 0;
        timer.cancel();
        _resendTimer = null;
      } else {
        _resendSeconds--;
      }
      notifyListeners();
    });
  }

  void _clearTimer() {
    _resendTimer?.cancel();
    _resendTimer = null;
    _resendSeconds = 0;
  }

  @override
  void dispose() {
    _clearTimer();
    super.dispose();
  }
}
