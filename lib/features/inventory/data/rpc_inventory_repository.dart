import '../../../core/data/json_row.dart';
import '../../../core/data/rpc_client.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/inventory_models.dart';
import '../domain/inventory_repository.dart';

class RpcInventoryRepository implements InventoryRepository, CashRepository {
  RpcInventoryRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<List<IngredientOption>> ingredients() async {
    try {
      return [
        for (final r in asRows(await _rpc.call('ingredient_list')))
          IngredientOption.fromRow(r),
      ];
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }

  @override
  Future<List<WasteTypeOption>> wasteTypes() async {
    try {
      return [
        for (final r in asRows(await _rpc.call('waste_type_list')))
          WasteTypeOption.fromRow(r),
      ];
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }

  @override
  Future<void> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
  }) async {
    // inv_waste_add: cùng luồng với Kho (mã HH-, theo quyền inventory.record)
    await _rpc.call('inv_waste_add', {
      'p_ingredient': ingredientId,
      'p_qty': qty,
      'p_type': typeCode,
      'p_note': _clean(note),
    });
  }

  @override
  Future<void> addMovement(
      {required bool incoming, required int amount, String? note}) async {
    await _rpc.call('add_cash_movement', {
      'p_direction': incoming ? 'in' : 'out',
      'p_amount': amount,
      'p_note': _clean(note),
    });
  }

  String? _clean(String? note) {
    final t = note?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
