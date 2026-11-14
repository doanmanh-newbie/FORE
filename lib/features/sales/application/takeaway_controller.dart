import 'dart:async';

import '../../../core/application/action_notifier.dart';
import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';

/// Đơn mang đi chưa xong, cũ nhất ở trên.
class TakeawayController extends ActionNotifier {
  TakeawayController(this._repo);

  final SalesRepository _repo;

  LoadPhase phase = LoadPhase.loading;
  List<TakeawayOrder> orders = const [];
  AppFailure? failure;
  Timer? _timer;

  /// Chỉ gắn nhãn "Chờ lâu nhất" khi có từ 2 đơn trở lên (một đơn thì không có gì để so sánh).
  bool isLongestWaiting(TakeawayOrder order) =>
      orders.length >= 2 && order.billId == orders.first.billId;

  Future<void> load() async {
    if (orders.isEmpty) {
      phase = LoadPhase.loading;
      notify();
    }
    try {
      orders = await _repo.takeawayOrders();
      failure = null;
      phase = LoadPhase.ready;
    } on AppFailure catch (f) {
      failure = f;
      phase = orders.isEmpty ? LoadPhase.error : LoadPhase.ready;
    }
    notify();
  }

  @override
  Future<void> onStale() => load();

  void startAutoRefresh(Duration every) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) {
      if (!busy) load();
    });
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  /// Đánh dấu đã pha xong. Đơn biến mất khỏi danh sách ngay; nếu lỗi thì tải lại để khôi phục.
  Future<bool> markDone(TakeawayOrder order) async {
    final done = await runAction<bool>(() async {
      final before = orders;
      orders = [
        for (final o in orders)
          if (o.billId != order.billId) o
      ];
      notify();
      try {
        await _repo.markPrepDone(order.billId);
      } on AppFailure {
        orders = before;
        notify();
        await load();
        rethrow;
      }
      return true;
    });
    return done ?? false;
  }

  /// Tạo đơn mang đi mới (chưa có món), trả mã bill để mở màn gọi món.
  Future<String?> createOrder() => runAction<String>(() async {
        final id = await _repo.openBill(type: BillType.takeAway);
        await load();
        return id;
      });
}
