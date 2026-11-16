import '../../../core/data/json_row.dart';
import '../../../core/data/rpc_client.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/stocktake_models.dart';
import '../domain/stocktake_repository.dart';

class RpcStocktakeRepository implements StocktakeRepository {
  RpcStocktakeRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<List<CountItem>> sheet(CountKind kind) async {
    try {
      final rows =
          asRows(await _rpc.call('count_sheet', {'p_kind': kind.wire}));
      return [for (final r in rows) CountItem.fromRow(r)];
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }

  @override
  Future<void> submit(String ingredientId, CountKind kind, int qty) async {
    await _rpc.call('submit_stock_count', {
      'p_ingredient': ingredientId,
      'p_kind': kind.wire,
      'p_qty': qty,
    });
  }
}
