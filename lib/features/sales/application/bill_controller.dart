import '../../../core/application/action_notifier.dart';
import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/text.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';

/// Một bill đang xem: thực đơn, giỏ món đang chọn (chưa gửi), các dòng đã gọi, giảm giá, thanh toán.
///
/// Giỏ món nằm ở máy cho tới khi bấm "Thêm vào bill": mỗi món chỉ gửi MỘT lần với số lượng đã chọn,
/// nên bill gọn gàng và không gửi lệnh cho từng lần chạm "+".
class BillController extends ActionNotifier {
  BillController(this._repo, this.billId, {this.maxLineQty = 99});

  final SalesRepository _repo;
  final String billId;

  /// Giới hạn mỗi dòng. Database là nơi quyết định (cài đặt `max_line_qty`); số này chỉ để chặn sớm.
  final int maxLineQty;

  LoadPhase phase = LoadPhase.loading;
  BillView? bill;
  List<MenuItemEntry> menu = const [];
  AppFailure? failure;

  final Map<String, int> _cart = {};
  String _query = '';
  String? _group;

  String get query => _query;
  String? get selectedGroup => _group;

  Future<void> load() async {
    if (bill == null) {
      phase = LoadPhase.loading;
      notify();
    }
    try {
      final results =
          await Future.wait<Object>([_repo.bill(billId), _repo.menu()]);
      bill = results[0] as BillView;
      menu = results[1] as List<MenuItemEntry>;
      failure = null;
      phase = LoadPhase.ready;
    } on AppFailure catch (f) {
      failure = f;
      phase = bill == null ? LoadPhase.error : LoadPhase.ready;
    }
    notify();
  }

  @override
  Future<void> onStale() => _refreshBill();

  /// Tải lại riêng bill (sau mỗi thao tác). Lỗi mạng ở đây không làm mất giao diện đang hiển thị.
  Future<void> _refreshBill() async {
    try {
      bill = await _repo.bill(billId);
      failure = null;
    } on AppFailure catch (f) {
      failure = f;
    }
    notify();
  }

  // ---------------------------------------------------------------- giỏ món
  Map<String, int> get cart => Map.unmodifiable(_cart);

  int cartQty(String sizeId) => _cart[sizeId] ?? 0;

  void setCartQty(String sizeId, int qty) {
    final q = qty.clamp(0, maxLineQty);
    if (q == 0) {
      _cart.remove(sizeId);
    } else {
      _cart[sizeId] = q;
    }
    notify();
  }

  void clearCart() {
    _cart.clear();
    notify();
  }

  int get cartPortions => _cart.values.fold(0, (a, b) => a + b);

  int get cartTotal {
    final price = <String, int>{
      for (final item in menu)
        for (final size in item.sizes) size.id: size.price,
    };
    return _cart.entries
        .fold(0, (sum, e) => sum + (price[e.key] ?? 0) * e.value);
  }

  // ---------------------------------------------------------------- thực đơn
  /// Các nhóm món để lọc. Món không có nhóm xếp vào "Khác".
  List<String> get groups {
    final seen = <String>[];
    for (final item in menu) {
      final g = item.group ?? 'Khác';
      if (!seen.contains(g)) seen.add(g);
    }
    return seen;
  }

  void selectGroup(String? group) {
    _group = group;
    notify();
  }

  void setQuery(String value) {
    _query = value;
    notify();
  }

  List<MenuItemEntry> get visibleMenu {
    final q = foldVietnamese(_query.trim());
    return [
      for (final item in menu)
        if ((_group == null || (item.group ?? 'Khác') == _group) &&
            (q.isEmpty || foldVietnamese(item.name).contains(q)))
          item,
    ];
  }

  // ---------------------------------------------------------------- thao tác
  bool get isOpen => bill?.isOpen ?? false;

  /// Được thanh toán khi bill còn mở, có món, và không còn món nào trong giỏ chưa gửi.
  bool get canPay =>
      isOpen && (bill?.activeLines.isNotEmpty ?? false) && _cart.isEmpty;

  /// Gửi giỏ món vào bill. Nếu giữa chừng lỗi: món đã gửi được bỏ khỏi giỏ, món còn lại giữ nguyên để thử lại.
  Future<bool> submitCart() async {
    final done = await runAction<bool>(() async {
      final entries = _cart.entries.where((e) => e.value > 0).toList();
      try {
        for (final e in entries) {
          await _repo.addLine(billId, e.key, e.value);
          _cart.remove(e.key);
        }
      } finally {
        await _refreshBill();
      }
      return true;
    });
    return done ?? false;
  }

  Future<bool> voidLine(String lineId, String reason) async {
    final done = await runAction<bool>(() async {
      await _repo.voidLine(lineId, reason);
      await _refreshBill();
      return true;
    });
    return done ?? false;
  }

  /// `amount` = 0 nghĩa là bỏ giảm giá. Giảm giá lớn hơn 0 bắt buộc có lý do.
  Future<bool> setDiscount(int amount, String reason) async {
    final current = bill;
    if (current == null) return false;
    if (amount < 0 || amount > current.subtotal) {
      throw const DatabaseFailure('DISCOUNT_INVALID');
    }
    if (amount > 0 && reason.trim().isEmpty) {
      throw const DatabaseFailure('REASON_REQUIRED');
    }
    final done = await runAction<bool>(() async {
      await _repo.setDiscount(billId, amount, reason.trim());
      await _refreshBill();
      return true;
    });
    return done ?? false;
  }

  Future<bool> cancelBill(String reason) async {
    if (reason.trim().isEmpty) throw const DatabaseFailure('REASON_REQUIRED');
    final done = await runAction<bool>(() async {
      await _repo.cancelOpenBill(billId, reason.trim());
      await _refreshBill();
      return true;
    });
    return done ?? false;
  }

  /// Thu tiền. Trả số tiền đã thu; `null` nếu đang bận.
  Future<int?> pay(PaymentMethod method) => runAction<int>(() async {
        final total = await _repo.pay(billId, method);
        await _refreshBill();
        return total;
      });
}
