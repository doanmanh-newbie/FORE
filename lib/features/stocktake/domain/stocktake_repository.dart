import 'stocktake_models.dart';

abstract interface class StocktakeRepository {
  Future<List<CountItem>> sheet(CountKind kind);

  /// Lưu số đo thực tế (đơn vị gốc, số nguyên, có thể bằng 0).
  Future<void> submit(String ingredientId, CountKind kind, int qty);
}
