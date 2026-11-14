import 'inventory_models.dart';

abstract interface class InventoryRepository {
  Future<List<IngredientOption>> ingredients();

  Future<List<WasteTypeOption>> wasteTypes();

  /// Ghi hao hụt có lý do để đối soát không tính nhầm.
  Future<void> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
  });
}

abstract interface class CashRepository {
  /// `incoming` = thu vào két, ngược lại là chi ra.
  Future<void> addMovement(
      {required bool incoming, required int amount, String? note});
}
