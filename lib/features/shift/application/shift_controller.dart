import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../domain/shift_models.dart';
import '../domain/shift_repository.dart';

/// Trạng thái ca của quán. `sealed`: màn hình phải xử lý đủ mọi trường hợp.
sealed class ShiftState {
  const ShiftState();
}

class ShiftLoading extends ShiftState {
  const ShiftLoading();
}

/// Quán chưa mở ca.
class ShiftNone extends ShiftState {
  const ShiftNone();
}

/// Đã có ca đang mở (do mình hoặc người khác mở).
class ShiftOpen extends ShiftState {
  const ShiftOpen(this.shift);

  final CurrentShift shift;
}

class ShiftLoadFailed extends ShiftState {
  const ShiftLoadFailed(this.failure);

  final AppFailure failure;
}

/// Kết quả bấm "Mở ca".
enum OpenShiftResult {
  /// Mình vừa mở ca. Gọi `load(quiet: true)` để cập nhật trạng thái.
  opened,

  /// Người khác mở trước vài giây; mình vào ca đó.
  joinedExisting,

  /// Chưa mở được (ô nhập sai hoặc lỗi). Lý do ở `openError`.
  failed,
}

/// Logic ca làm việc: xem ca đang mở và mở ca.
class ShiftController extends ChangeNotifier {
  ShiftController(this._repository);

  /// Tiền đầu ca tối đa chấp nhận (chặn gõ nhầm thêm số 0).
  static const maxOpeningCash = 100000000;

  final ShiftRepository _repository;

  ShiftState _state = const ShiftLoading();
  ShiftState get state => _state;

  bool _opening = false;
  bool get opening => _opening;

  String? _openError;
  String? get openError => _openError;

  /// Quên trạng thái ca đã tải (đăng xuất, đổi tài khoản) để người sau không thấy
  /// thoáng qua dữ liệu của người trước.
  void reset() {
    _generation++; // bỏ kết quả của các request đang bay
    _state = const ShiftLoading();
    _opening = false;
    _openError = null;
    notifyListeners();
  }

  int _generation = 0;
  String? _scope;

  /// Gắn controller với phạm vi hiện tại (quán + người dùng; `null` khi đã đăng xuất).
  /// Đổi phạm vi thì quên ca đã tải, kể cả khi đăng xuất/đổi quán từ nơi không gọi [reset].
  void bindScope(String? scope) {
    if (scope == _scope) return;
    _scope = scope;
    reset();
  }

  /// Tải lại ca đang mở. Gọi khi vào Home và khi bấm "Thử lại".
  ///
  /// `quiet`: không chuyển sang "đang tải" (kéo để làm mới, mở lại app),
  /// để màn hình không nháy; nếu lỗi thì giữ nguyên số liệu đang hiện.
  Future<void> load({bool quiet = false}) async {
    if (!quiet) {
      _state = const ShiftLoading();
      notifyListeners();
    }
    final generation = _generation;
    try {
      final shift = await _repository.currentShift();
      if (generation != _generation) return;
      _state = shift == null ? const ShiftNone() : ShiftOpen(shift);
    } on AppFailure catch (f) {
      if (generation != _generation) return;
      if (!quiet || _state is ShiftLoading) _state = ShiftLoadFailed(f);
    }
    notifyListeners();
  }

  /// Kiểm tra số tiền người dùng gõ. Trả về câu báo lỗi, hoặc `null` nếu hợp lệ.
  static String? validateOpeningCash(String input) {
    final cash = parseVnd(input);
    if (cash == null) return 'Nhập số tiền hợp lệ.';
    if (cash > maxOpeningCash) return 'Số tiền quá lớn, kiểm tra lại.';
    return null;
  }

  /// Xóa thông báo lỗi khi người dùng bắt đầu sửa ô nhập.
  void clearOpenError() {
    if (_openError == null) return;
    _openError = null;
    notifyListeners();
  }

  Future<OpenShiftResult> openShift(String cashInput) async {
    _openError = validateOpeningCash(cashInput);
    if (_openError != null) {
      notifyListeners();
      return OpenShiftResult.failed;
    }
    final cash = parseVnd(cashInput)!;

    _opening = true;
    notifyListeners();
    try {
      await _repository.openShift(openingCash: cash);
      // Chưa tải lại ở đây: màn hình tải lại sau khi đóng màn mở ca, để người
      // dùng thấy thẻ ca và các tab được mở khóa ngay lúc quay về Trang chủ.
      return OpenShiftResult.opened;
    } on ShiftAlreadyOpenFailure {
      // Người khác mở trước: không phải lỗi, mình chỉ cần vào ca đó.
      await _reloadQuietly();
      return OpenShiftResult.joinedExisting;
    } on AppFailure catch (f) {
      _openError = f.userMessage;
      return OpenShiftResult.failed;
    } finally {
      _opening = false;
      notifyListeners();
    }
  }

  /// Tải lại ca đang mở mà không chuyển sang trạng thái "đang tải" (tránh nháy màn).
  Future<void> _reloadQuietly() async {
    final generation = _generation;
    try {
      final shift = await _repository.currentShift();
      if (generation != _generation) return;
      _state = shift == null ? const ShiftNone() : ShiftOpen(shift);
    } on AppFailure catch (f) {
      if (generation != _generation) return;
      _state = ShiftLoadFailed(f);
    }
  }
}
