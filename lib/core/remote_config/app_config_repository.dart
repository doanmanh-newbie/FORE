import '../data/json_row.dart';
import '../data/rpc_client.dart';
import '../errors/app_failure.dart';
import 'remote_app_config.dart';

/// Đọc cấu hình từ xa. Ném [AppFailure] khi lỗi (controller tự dùng giá trị an toàn).
abstract interface class AppConfigRepository {
  Future<RemoteAppConfig> fetch();
}

/// Gọi `get_app_config()` (cần đăng nhập), trả object `{key: value}`.
class RpcAppConfigRepository implements AppConfigRepository {
  RpcAppConfigRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<RemoteAppConfig> fetch() async {
    try {
      return RemoteAppConfig.fromJson(
          asObject(await _rpc.call('get_app_config')));
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }
}

/// Luôn trả cấu hình mặc định (không chặn gì). Dùng khi không truyền repository (test cũ).
class StaticAppConfigRepository implements AppConfigRepository {
  const StaticAppConfigRepository([this.config = RemoteAppConfig.fallback]);

  final RemoteAppConfig config;

  @override
  Future<RemoteAppConfig> fetch() async => config;
}
