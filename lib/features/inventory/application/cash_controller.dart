import '../../../core/application/action_notifier.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/inventory_repository.dart';

/// Thu / chi tiền mặt ngoài bán hàng (mua đá, chủ rút tiền...). Chi ra bắt buộc ghi chú; không cần PIN.
class CashController extends ActionNotifier {
  CashController(this._repo);

  /// Khớp luật của database (`add_cash_movement`): chi ra cần ghi chú từ 3 ký tự.
  static const minNoteLength = 3;
  static const maxAmount = 1000000000;

  final CashRepository _repo;

  bool incoming = false; // mặc định "Chi ra": trường hợp hay gặp nhất
  int? amount;
  String note = '';

  void setIncoming(bool value) {
    incoming = value;
    notify();
  }

  void setAmount(int? value) {
    amount = value;
    notify();
  }

  void setNote(String value) {
    note = value;
    notify();
  }

  bool get noteOk => incoming || note.trim().length >= minNoteLength;
  bool get amountOk => amount != null && amount! > 0 && amount! <= maxAmount;
  bool get canSubmit => amountOk && noteOk && !busy;

  void reset() {
    amount = null;
    note = '';
    notify();
  }

  Future<bool> submit() async {
    final value = amount;
    if (value == null || value <= 0 || value > maxAmount) {
      throw const DatabaseFailure('AMOUNT_INVALID');
    }
    if (!noteOk) {
      throw const DatabaseFailure('NOTE_REQUIRED');
    }
    final done = await runAction<bool>(() async {
      await _repo.addMovement(incoming: incoming, amount: value, note: note);
      return true;
    });
    if (done ?? false) reset();
    return done ?? false;
  }
}
