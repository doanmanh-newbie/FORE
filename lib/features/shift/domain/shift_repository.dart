import 'shift_models.dart';

/// Hợp đồng truy cập ca làm việc. Mọi lỗi ném ra là một `AppFailure`.
abstract interface class ShiftRepository {
  /// Ca đang mở, hoặc `null` nếu quán chưa mở ca.
  Future<CurrentShift?> currentShift();

  /// Mở ca với số tiền mặt đầu ca (đồng).
  /// Ném `ShiftAlreadyOpenFailure` nếu người khác đã mở ca trước.
  Future<void> openShift({required int openingCash});
}
