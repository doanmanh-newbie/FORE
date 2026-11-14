import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/shift/domain/shift_models.dart';
import 'package:fore/features/shift/domain/shift_repository.dart';

/// Bản giả của [ShiftRepository] cho test: không cần mạng, không cần Supabase.
class FakeShiftRepository implements ShiftRepository {
  CurrentShift? shift;

  /// Lỗi cho mọi lệnh gọi (ví dụ mất mạng).
  AppFailure? failure;

  /// Mô phỏng người khác mở ca ngay trước khi mình bấm.
  bool someoneOpensFirst = false;

  final openedWith = <int>[];

  /// Làm `currentShift()` trả chậm (để dựng tình huống đổi tài khoản giữa chừng).
  Duration delay = Duration.zero;

  @override
  Future<CurrentShift?> currentShift() async {
    final result = shift; // chụp lại lúc gọi, như một request đã gửi đi
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    return result;
  }

  @override
  Future<void> openShift({required int openingCash}) async {
    if (failure != null) throw failure!;
    if (someoneOpensFirst || shift != null) {
      shift ??= CurrentShift(
        id: 's1',
        openedByName: 'An',
        openedAt: DateTime(2026, 10, 25, 8, 2),
      );
      throw const ShiftAlreadyOpenFailure();
    }
    openedWith.add(openingCash);
    shift = CurrentShift(
      id: 's1',
      openedByName: 'Mình',
      openedAt: DateTime(2026, 10, 25, 8, 0),
      openedByMe: true,
    );
  }
}
