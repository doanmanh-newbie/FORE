import '../../../core/application/action_notifier.dart';
import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';

/// Phiếu đếm kho MÙ của nhân viên (và chủ khi tự đếm): nhập số đếm được, lưu nháp, gửi chủ duyệt.
/// Không có số hệ thống; "chưa đếm" khác với 0.
class CountController extends ActionNotifier {
  CountController(this._repo);

  final KhoRepository _repo;

  LoadPhase phase = LoadPhase.loading;
  AppFailure? failure;
  CountSheet? sheet;

  /// Số đang nhập trên máy, chưa chắc đã lưu lên server. `null` = chưa đếm.
  final Map<String, int?> _local = {};
  final Set<String> _dirty = {};

  Future<void> start() async {
    phase = LoadPhase.loading;
    notify();
    try {
      final s = await _repo.startStocktake();
      await _load(s.id);
    } on AppFailure catch (f) {
      failure = f;
      phase = LoadPhase.error;
      notify();
    }
  }

  Future<void> openExisting(String id) async {
    phase = LoadPhase.loading;
    notify();
    try {
      await _load(id);
    } on AppFailure catch (f) {
      failure = f;
      phase = LoadPhase.error;
      notify();
    }
  }

  Future<void> _load(String id) async {
    final loaded = await _repo.countSheet(id);
    sheet = loaded;
    _local
      ..clear()
      ..addEntries(loaded.lines.map((l) => MapEntry(l.ingredientId, l.countedQty)));
    _dirty.clear();
    failure = null;
    phase = LoadPhase.ready;
    notify();
  }

  List<CountLine> get lines => sheet?.lines ?? const [];

  /// Dòng đang được đếm (phiếu đếm lại chỉ gồm các dòng chủ yêu cầu).
  List<CountLine> get activeLines => sheet?.status == StocktakeStatus.recount
      ? lines.where((l) => l.recountRequested).toList()
      : lines;

  int? qtyOf(String ingredientId) => _local[ingredientId];

  void setQty(String ingredientId, int? qty) {
    _local[ingredientId] = qty;
    _dirty.add(ingredientId);
    notify();
  }

  int get countedCount =>
      activeLines.where((l) => _local[l.ingredientId] != null).length;

  int get totalCount => activeLines.length;

  bool get complete => totalCount > 0 && countedCount == totalCount;

  bool get hasUnsaved => _dirty.isNotEmpty;

  bool get locked =>
      sheet != null &&
      sheet!.status != StocktakeStatus.draft &&
      sheet!.status != StocktakeStatus.recount;

  Future<bool> saveDraft() async {
    final s = sheet;
    if (s == null) return false;
    if (_dirty.isEmpty) return true;
    final done = await runAction<bool>(() async {
      await _repo.saveCounts(s.id, {for (final k in _dirty) k: _local[k]});
      _dirty.clear();
      return true;
    });
    return done ?? false;
  }

  /// Lưu rồi gửi chủ duyệt. Chỉ gửi được khi đã đếm đủ.
  Future<bool> submit() async {
    final s = sheet;
    if (s == null) return false;
    if (!complete) throw const DatabaseFailure('COUNT_INCOMPLETE');
    final done = await runAction<bool>(() async {
      if (_dirty.isNotEmpty) {
        await _repo.saveCounts(s.id, {for (final k in _dirty) k: _local[k]});
        _dirty.clear();
      }
      await _repo.submitStocktake(s.id);
      return true;
    });
    if (done ?? false) await _load(s.id);
    return done ?? false;
  }
}
