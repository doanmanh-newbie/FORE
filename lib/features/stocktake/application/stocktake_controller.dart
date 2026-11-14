import '../../../core/application/action_notifier.dart';
import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/stocktake_models.dart';
import '../domain/stocktake_repository.dart';

/// Phiếu kiểm kê ĐẾM MÙ. Quy tắc cứng:
///  - màn hình không bao giờ nhận hay hiển thị số dự kiến, số tồn, hay số đã đếm lần trước;
///  - sau khi lưu, số vừa nhập bị bỏ khỏi bộ nhớ và dòng chỉ hiện "Đã đếm" (không có đúng/sai);
///  - muốn sửa thì đếm lại từ ô trống (database dùng số lưu sau cùng, và đánh dấu nếu đếm lại nhiều lần).
class StocktakeController extends ActionNotifier {
  StocktakeController(this._repo, this.kind);

  final StocktakeRepository _repo;
  final CountKind kind;

  LoadPhase phase = LoadPhase.loading;
  List<CountItem> items = const [];
  AppFailure? failure;

  final Map<String, int> _drafts = {};
  final Set<String> _recount = {};

  Future<void> load() async {
    if (items.isEmpty) {
      phase = LoadPhase.loading;
      notify();
    }
    try {
      items = await _repo.sheet(kind);
      failure = null;
      phase = LoadPhase.ready;
    } on AppFailure catch (f) {
      failure = f;
      phase = items.isEmpty ? LoadPhase.error : LoadPhase.ready;
    }
    notify();
  }

  @override
  Future<void> onStale() => load();

  /// Nguyên liệu phải đếm mỗi ca, loại quan trọng đứng đầu (thứ tự do database trả).
  List<CountItem> get dailyItems => [
        for (final i in items)
          if (!i.weekly) i
      ];

  /// Nguyên liệu chỉ kiểm theo tuần: không bắt buộc đếm lúc cuối ca.
  List<CountItem> get weeklyItems => [
        for (final i in items)
          if (i.weekly) i
      ];

  /// Dòng này đang cần ô nhập (chưa đếm, hoặc người dùng chọn đếm lại).
  bool needsInput(CountItem item) =>
      !item.counted || _recount.contains(item.id);

  int get dailyTotal => dailyItems.length;
  int get dailyCounted => dailyItems.where((i) => i.counted).length;
  bool get allDailyCounted => dailyCounted == dailyTotal;

  /// Số dòng đã gõ số nhưng chưa lưu.
  int get pendingCount => _drafts.length;
  bool get hasPending => _drafts.isNotEmpty;

  void startRecount(CountItem item) {
    _recount.add(item.id);
    notify();
  }

  /// Ghi nhận số vừa gõ (đơn vị gốc, số nguyên ≥ 0). `null` = ô trống.
  void setDraft(String ingredientId, int? qty) {
    if (qty == null || qty < 0) {
      _drafts.remove(ingredientId);
    } else {
      _drafts[ingredientId] = qty;
    }
    notify();
  }

  /// Lưu mọi dòng đã gõ. Dừng ở dòng lỗi đầu tiên (các dòng trước đó vẫn đã lưu), rồi tải lại phiếu.
  /// Trả số dòng đã lưu; `null` nếu đang bận.
  Future<int?> saveAll() => runAction<int>(() async {
        final entries = _drafts.entries.toList();
        var saved = 0;
        try {
          for (final e in entries) {
            await _repo.submit(e.key, kind, e.value);
            _drafts.remove(e.key); // số vừa lưu biến mất khỏi bộ nhớ ngay
            _recount.remove(e.key);
            items = [
              for (final i in items) i.id == e.key ? i.markCounted() : i
            ];
            saved++;
          }
        } finally {
          notify();
        }
        await load();
        return saved;
      });
}
