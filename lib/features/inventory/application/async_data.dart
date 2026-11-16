import 'package:flutter/foundation.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';

/// Tải một khối dữ liệu đọc: loading → ready / error. Làm mới lặng lẽ (giữ dữ liệu cũ trên màn).
class AsyncData<T> extends ChangeNotifier {
  AsyncData(this._loader);

  final Future<T> Function() _loader;

  LoadPhase phase = LoadPhase.loading;
  T? data;
  AppFailure? failure;
  bool _disposed = false;
  int _generation = 0;

  Future<void> load({bool silent = false}) async {
    final gen = ++_generation;
    if (!silent || data == null) {
      phase = LoadPhase.loading;
      _notify();
    }
    try {
      final result = await _loader();
      if (gen != _generation) return;
      data = result;
      failure = null;
      phase = LoadPhase.ready;
    } on AppFailure catch (f) {
      if (gen != _generation) return;
      failure = f;
      phase = data == null ? LoadPhase.error : LoadPhase.ready;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
