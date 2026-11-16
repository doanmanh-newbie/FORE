import 'package:flutter/foundation.dart';

import '../errors/app_failure.dart';
import '../errors/failure_messages.dart';

/// Nền chung cho các controller:
///  - không báo thay đổi sau khi đã bị hủy (tránh lỗi khi tải xong mà màn hình đã đóng);
///  - [runAction] chạy một thao tác ghi: chặn bấm đúp, đặt cờ `busy`, và nếu máy khác vừa
///    đổi dữ liệu (bàn đã có bill, bill đã thanh toán...) thì tự tải lại rồi báo lỗi lên.
abstract class ActionNotifier extends ChangeNotifier {
  bool _disposed = false;
  bool _busy = false;

  bool get busy => _busy;
  bool get disposed => _disposed;

  @protected
  void notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Tải lại dữ liệu sau khi một thao tác bị từ chối vì dữ liệu đã cũ. Mặc định không làm gì.
  @protected
  Future<void> onStale() async {}

  /// Trả `null` nếu đang có thao tác khác chạy (bỏ qua lần bấm này).
  /// Lỗi nghiệp vụ được ném lại dạng [AppFailure] để giao diện báo cho người dùng.
  @protected
  Future<T?> runAction<T>(Future<T> Function() action) async {
    if (_busy) return null;
    _busy = true;
    notify();
    try {
      return await action();
    } on AppFailure catch (f) {
      if (f.shouldRefresh) await onStale();
      rethrow;
    } finally {
      _busy = false;
      notify();
    }
  }
}
