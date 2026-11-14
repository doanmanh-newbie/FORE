import '../../../../core/data/json_row.dart';
import '../../../../core/data/rpc_client.dart';
import '../../../../core/errors/app_failure.dart';
import '../domain/ops_shift_models.dart';
import '../domain/ops_shift_repository.dart';

class RpcOpsShiftRepository implements OpsShiftRepository {
  RpcOpsShiftRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<ShopInfo?> shopInfo() => _parse(() async {
        final rows = asRows(await _rpc.call('shop_info'));
        return rows.isEmpty ? null : ShopInfo.fromRow(rows.first);
      });

  @override
  Future<OpsCurrentShift?> currentShift() => _parse(() async {
        final rows = asRows(await _rpc.call('current_shift'));
        return rows.isEmpty ? null : OpsCurrentShift.fromRow(rows.first);
      });

  @override
  Future<void> openShift(int openingCash) async {
    await _rpc.call('open_shift', {'p_opening_cash': openingCash});
  }

  @override
  Future<CloseStatus> closeStatus() => _parse(() async {
        final rows = asRows(await _rpc.call('shift_close_status'));
        if (rows.isEmpty) {
          throw const FormatException('shift_close_status không trả dòng nào');
        }
        return CloseStatus.fromRow(rows.first);
      });

  @override
  Future<void> closeShift(int closingCash) async {
    await _rpc.call('close_shift', {'p_closing_cash': closingCash});
  }

  /// Dữ liệu trả về sai định dạng thì báo là lỗi chung, kèm chi tiết để ghi log.
  Future<T> _parse<T>(Future<T> Function() read) async {
    try {
      return await read();
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }
}
