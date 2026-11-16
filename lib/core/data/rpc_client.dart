import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/app_failure.dart';
import 'rpc_errors.dart';

/// Cách duy nhất để app gọi hàm của database. Mọi repository dùng interface này,
/// nên test chỉ cần một bản giả, không cần mạng hay Supabase.
abstract interface class RpcClient {
  /// Gọi hàm `fn` của database. Kết quả là JSON đã giải mã:
  /// hàm `returns table` trả `List`, `returns jsonb` trả `Map`, `returns uuid` trả `String`.
  /// Mọi lỗi được đổi thành [AppFailure].
  Future<dynamic> call(String fn, [Map<String, dynamic>? params]);
}

class SupabaseRpcClient implements RpcClient {
  SupabaseRpcClient(this._client);

  final SupabaseClient _client;

  @override
  Future<dynamic> call(String fn, [Map<String, dynamic>? params]) async {
    try {
      return await _client.rpc<dynamic>(fn, params: params);
    } on AppFailure {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') throw MissingRpcFailure(fn);
      throw mapPostgrestError(message: e.message, code: e.code);
    } on AuthRetryableFetchException {
      throw const NoNetworkFailure();
    } on AuthException {
      throw const SessionExpiredFailure();
    } on SocketException {
      throw const NoNetworkFailure();
    } on TimeoutException {
      throw const NoNetworkFailure();
    } catch (e) {
      throw UnknownFailure(e);
    }
  }
}
