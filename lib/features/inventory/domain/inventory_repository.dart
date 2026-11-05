import 'inventory_models.dart';

abstract interface class InventoryRepository {
  Future<List<IngredientOption>> ingredients();

  Future<List<WasteTypeOption>> wasteTypes();

  /// Nhập hàng. `qty` theo đơn vị gốc, số nguyên > 0.
  Future<void> addPurchase({
    required String ingredientId,
    required int qty,
    bool late = false,
    String? note,
    String? requestId,
  });

  /// Ghi hao hụt có lý do để đối soát không tính nhầm.
  Future<void> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
    String? requestId,
  });
}

abstract interface class CashRepository {
  /// `incoming` = thu vào két, ngược lại là chi ra.
  Future<void> addMovement(
      {required bool incoming, required int amount, String? note});
}
