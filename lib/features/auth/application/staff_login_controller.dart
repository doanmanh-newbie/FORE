import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/application/notify_when_alive.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';

/// Gửi và xác minh mã OTP nhân viên; không phân biệt tài khoản tồn tại trong thông báo gửi mã.
class StaffLoginController extends ChangeNotifier with NotifyWhenAlive {
  StaffLoginController(
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
  String? otpError;
  String? formError;
  StaffContact? _challengeContact;
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

  /// Gửi mã đăng nhập. Trả về true khi yêu cầu gửi được chấp nhận, chưa phải đăng nhập.
  Future<bool> submit(String raw) async {
    contactError = otpError = formError = null;
    final parsed = StaffContact.tryParse(_kind, raw);
    final contact = parsed.contact;
    if (contact == null) {
      contactError = parsed.error;
      notifyListeners();
      return false;
    }
    _challengeContact = contact;
    return _requestOtp(createUser: false);
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
    await _requestOtp(createUser: false);
  }

  Future<bool> _requestOtp({required bool createUser}) async {
    _loading = true;
    notifyListeners();
    try {
      await _repository.requestStaffOtp(
        _challengeContact!,
        createUser: createUser,
      );
      _otpRequested = true;
      _startTimer();
      _loading = false;
      notifyListeners();
      return true;
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
