import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/json_row.dart';
import '../../core/data/rpc_client.dart';
import '../../core/data/rpc_errors.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/network_errors.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';

/// Các repository gọi trực tiếp các RPC super-admin trong `database/09_admin.sql`.

class SupabaseAdminShopsRepository implements AdminShopsRepository {
  SupabaseAdminShopsRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<List<AdminShop>> listShops() async {
    final raw = await _rpc.call('admin_list_shops');
    return asRows(raw).map(AdminShop.fromJson).toList();
  }
}

class SupabaseAdminUsersRepository implements AdminUsersRepository {
  SupabaseAdminUsersRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<AdminUserPage> listUsers({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final query = search?.trim();
    final raw = await _rpc.call('admin_list_users', {
      'p_search': (query == null || query.isEmpty) ? null : query,
      'p_limit': limit,
      'p_offset': offset,
    });
    final items = asRows(raw).map(AdminUser.fromJson).toList();
    final totalCount = items.isEmpty ? 0 : items.first.totalCount;
    return AdminUserPage(
      items: items,
      totalCount: totalCount,
      limit: limit,
      offset: offset,
    );
  }
}

class SupabaseAdminErrorsRepository implements AdminErrorsRepository {
  SupabaseAdminErrorsRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<List<AdminErrorLog>> listErrors({
    int limit = 50,
    DateTime? before,
  }) async {
    final raw = await _rpc.call('admin_list_errors', {
      'p_limit': limit,
      'p_before': before?.toUtc().toIso8601String(),
    });
    return asRows(raw).map(AdminErrorLog.fromJson).toList();
  }
}

class SupabaseAdminEventsRepository implements AdminEventsRepository {
  SupabaseAdminEventsRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<List<AdminEventCount>> fetchEventCounts({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _rpc.call('admin_event_counts', {
      'p_from': from.toUtc().toIso8601String(),
      'p_to': to.toUtc().toIso8601String(),
    });
    return asRows(raw).map(AdminEventCount.fromJson).toList();
  }
}

class SupabaseAdminLoginsRepository implements AdminLoginsRepository {
  SupabaseAdminLoginsRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<List<AdminLoginIp>> listLogins({
    String? userId,
    int limit = 100,
  }) async {
    final trimmed = userId?.trim();
    final raw = await _rpc.call('admin_list_logins', {
      'p_user_id': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
      'p_limit': limit,
    });
    return asRows(raw).map(AdminLoginIp.fromJson).toList();
  }
}

class SupabaseAdminConfigRepository implements AdminConfigRepository {
  SupabaseAdminConfigRepository(this._rpc, [this._client]);

  final RpcClient _rpc;
  final SupabaseClient? _client;

  @override
  Future<List<AdminConfigEntry>> listConfigs() async {
    final client = _client;
    if (client != null) {
      try {
        final raw = await client
            .from('app_config')
            .select('key, value, updated_at, updated_by')
            .order('key', ascending: true);
        return asRows(raw).map(AdminConfigEntry.fromJson).toList();
      } on AppFailure {
        rethrow;
      } on PostgrestException catch (e) {
        if (e.code == 'PGRST202') {
          throw const MissingRpcFailure('get_app_config');
        }
        throw mapPostgrestError(message: e.message, code: e.code);
      } on AuthRetryableFetchException {
        throw const NoNetworkFailure();
      } on AuthException {
        throw const SessionExpiredFailure();
      } on TimeoutException {
        throw const NoNetworkFailure();
      } catch (e) {
        if (looksLikeNetworkError(e)) throw const NoNetworkFailure();
        throw UnknownFailure(e);
      }
    }

    // Fallback qua RPC `get_app_config()` (hữu ích trong unit test chỉ truyền RpcClient).
    final raw = await _rpc.call('get_app_config');
    final map = asObject(raw);
    final entries = [
      for (final entry in map.entries)
        AdminConfigEntry(key: entry.key, value: entry.value),
    ]..sort((a, b) => a.key.compareTo(b.key));
    return entries;
  }

  @override
  Future<AdminConfigEntry> setConfig({
    required String key,
    required dynamic value,
  }) async {
    final raw = await _rpc.call('admin_set_config', {
      'p_key': key.trim().toLowerCase(),
      'p_value': value,
    });
    return AdminConfigEntry.fromJson(asObject(raw));
  }
}
