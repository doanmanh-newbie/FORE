import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/phone.dart';
import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';

/// Chủ quán: xem nhân viên, thêm nhân viên bằng số điện thoại, hủy lời mời.
class TeamController extends ChangeNotifier {
  TeamController(this._repository);

  final ShopRepository _repository;

  List<TeamMember> _members = const [];
  List<TeamMember> get members => _members;

  List<PendingInvite> _pending = const [];
  List<PendingInvite> get pending =>
      _pending.where((invite) => invite.status == 'pending').toList();
  List<PendingInvite> get inviteHistory => _pending;

  bool _loading = true;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  bool _inviting = false;
  bool get inviting => _inviting;

  /// Lỗi của form mời (hiện trong hộp thoại).
  String? phoneError;
  String? nameError;
  String? emailError;
  String? formError;

  Future<void> load({bool quiet = false}) async {
    if (!quiet) {
      _loading = true;
      notifyListeners();
    }
    try {
      final results = await Future.wait([
        _repository.team(),
        _repository.inviteHistory(),
      ]);
      _members = results[0] as List<TeamMember>;
      _pending = results[1] as List<PendingInvite>;
      _error = null;
    } on OwnerOnlyFailure {
      if (!quiet || _loading) {
        _error = 'Gmail đăng nhập chưa có vai trò chủ trong quán đang chọn. '
            'Nếu bạn vừa reset database, hãy đăng xuất, đăng nhập lại rồi tạo quán để tạo quyền chủ.';
      }
    } on AppFailure catch (f) {
      if (!quiet || _loading) _error = f.userMessage;
    }
    _loading = false;
    notifyListeners();
  }

  void clearFormErrors() {
    phoneError = nameError = emailError = formError = null;
  }

  /// Gửi lời mời. Trả về `true` nếu thành công.
  Future<bool> invite({
    String phone = '',
    required String fullName,
    String email = '',
  }) async {
    clearFormErrors();
    final cleanPhone = phone.trim().isEmpty ? null : Phone.toE164(phone);
    if (phone.trim().isNotEmpty && cleanPhone == null) {
      phoneError = 'Số điện thoại chưa đúng. Ví dụ: 0901 234 567.';
    }
    if (fullName.trim().isEmpty) nameError = 'Nhập tên hiển thị.';
    final cleanEmail = email.trim();
    if (cleanEmail.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(cleanEmail)) {
      emailError = 'Email chưa đúng định dạng.';
    }
    if (cleanPhone == null && cleanEmail.isEmpty) {
      formError = 'Nhập số điện thoại, email hoặc cả hai.';
    }
    if (phoneError != null ||
        nameError != null ||
        emailError != null ||
        formError != null) {
      notifyListeners();
      return false;
    }

    _inviting = true;
    notifyListeners();
    try {
      await _repository.inviteStaff(
        phone: cleanPhone,
        fullName: fullName.trim(),
        email: cleanEmail.isEmpty ? null : cleanEmail.toLowerCase(),
      );
      await load(quiet: true);
      _inviting = false;
      notifyListeners();
      return true;
    } on InvalidPhoneFailure catch (f) {
      phoneError = f.userMessage;
    } on AlreadyMemberFailure catch (f) {
      phoneError = f.userMessage;
    } on AlreadyInvitedFailure catch (f) {
      phoneError = f.userMessage;
    } on OwnerOnlyFailure {
      formError =
          'Phiên đăng nhập hoặc quán đang chọn không còn quyền chủ quán. Hãy đăng nhập lại tài khoản chủ rồi gửi lời mời.';
    } on AppFailure catch (f) {
      formError = f.userMessage;
    }
    _inviting = false;
    notifyListeners();
    return false;
  }

  /// Trả về `null` nếu xong, hoặc câu lỗi.
  Future<String?> cancel(PendingInvite invite) async {
    try {
      await _repository.cancelInvite(invite.id);
      _pending = _pending.where((p) => p.id != invite.id).toList();
      notifyListeners();
      return null;
    } on InviteNotFoundFailure {
      await load(quiet: true);
      return null; // đã bị người đó xử lý trước: danh sách đã làm mới
    } on AppFailure catch (f) {
      return f.userMessage;
    }
  }
}
