import '../../../core/application/action_notifier.dart';
import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

/// Ghi hao hụt (đổ bỏ, làm sai, cho nhân viên, thử vị...). Loại chọn từ danh sách do app lấy từ database,
/// không gõ tự do. Loại cần ghi chú thì ghi chú phải từ [minNoteLength] ký tự.
class WasteController extends ActionNotifier {
  WasteController(this._repo);

  /// Khớp luật của database (`add_waste`): loại bắt buộc ghi chú cần từ 5 ký tự.
  static const minNoteLength = 5;

  final InventoryRepository _repo;

  LoadPhase phase = LoadPhase.loading;
  List<IngredientOption> ingredients = const [];
  List<WasteTypeOption> types = const [];
  AppFailure? failure;

  IngredientOption? ingredient;
  WasteTypeOption? type;
  UnitChoice? unitChoice;
  String quantityText = '';
  String note = '';

  Future<void> load() async {
    if (ingredients.isEmpty) {
      phase = LoadPhase.loading;
      notify();
    }
    try {
      final results =
          await Future.wait<Object>([_repo.ingredients(), _repo.wasteTypes()]);
      ingredients = results[0] as List<IngredientOption>;
      types = results[1] as List<WasteTypeOption>;
      failure = null;
      phase = LoadPhase.ready;
    } on AppFailure catch (f) {
      failure = f;
      phase = ingredients.isEmpty ? LoadPhase.error : LoadPhase.ready;
    }
    notify();
  }

  void selectIngredient(IngredientOption option) {
    ingredient = option;
    unitChoice = unitChoices(option.unit).first;
    notify();
  }

  void selectType(WasteTypeOption option) {
    type = option;
    notify();
  }

  void setUnit(UnitChoice choice) {
    unitChoice = choice;
    notify();
  }

  void setQuantityText(String text) {
    quantityText = text;
    notify();
  }

  void setNote(String value) {
    note = value;
    notify();
  }

  int? get quantity {
    final choice = unitChoice;
    return choice == null ? null : quantityInBase(quantityText, choice);
  }

  bool get noteRequired => type?.requiresNote ?? false;
  bool get noteOk => !noteRequired || note.trim().length >= minNoteLength;

  bool get canSubmit =>
      ingredient != null && type != null && quantity != null && noteOk && !busy;

  void reset() {
    ingredient = null;
    type = null;
    unitChoice = null;
    quantityText = '';
    note = '';
    notify();
  }

  Future<bool> submit() async {
    final item = ingredient;
    final kind = type;
    final qty = quantity;
    if (item == null) throw const DatabaseFailure('NOT_FOUND');
    if (kind == null) throw const DatabaseFailure('WASTE_TYPE_INVALID');
    if (qty == null) throw const DatabaseFailure('QTY_INVALID');
    if (!noteOk) throw const DatabaseFailure('NOTE_REQUIRED');
    final done = await runAction<bool>(() async {
      await _repo.addWaste(
          ingredientId: item.id, qty: qty, typeCode: kind.code, note: note);
      return true;
    });
    if (done ?? false) reset();
    return done ?? false;
  }
}
