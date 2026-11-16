import 'package:flutter/foundation.dart';

/// Bỏ qua `notifyListeners()` sau khi đã `dispose`: request mạng có thể xong
/// khi màn hình đã đóng, và Flutter sẽ ném lỗi nếu vẫn báo thay đổi.
mixin NotifyWhenAlive on ChangeNotifier {
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
