import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/data/supabase_admin_repositories.dart';
import 'package:fore/core/data/rpc_client.dart';

class _RecordingRpcClient implements RpcClient {
  final List<(String fn, Map<String, dynamic>? params)> calls = [];
  dynamic Function(String fn, Map<String, dynamic>? params)? handler;

  @override
  Future<dynamic> call(String fn, [Map<String, dynamic>? params]) async {
    calls.add((fn, params));
    return handler?.call(fn, params);
  }
}

void main() {
  group('Admin Supabase repositories RPC contract (09_admin.sql)', () {
    test('admin_list_shops parses all columns', () async {
      final rpc = _RecordingRpcClient()
        ..handler = (_, __) => [
              {
                'id': '11111111-1111-1111-1111-111111111111',
                'name': 'Quán Fore',
                'code': 'FORE01',
                'created_at': '2026-10-01T02:00:00Z',
                'owner_user_id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
                'owner_name': 'Chủ Quán',
                'owner_email': 'owner@fore.vn',
                'member_count': 5,
                'last_bill_at': '2026-11-20T08:00:00Z',
              },
            ];

      final repo = SupabaseAdminShopsRepository(rpc);
      final shops = await repo.listShops();

      expect(rpc.calls.single.$1, 'admin_list_shops');
      expect(shops, hasLength(1));
      expect(shops.first.code, 'FORE01');
      expect(shops.first.memberCount, 5);
      expect(shops.first.ownerEmail, 'owner@fore.vn');
    });

    test('admin_list_users sends p_search, p_limit, p_offset and computes totalCount',
        () async {
      final rpc = _RecordingRpcClient()
        ..handler = (_, __) => [
              {
                'user_id': 'u-1',
                'email': 'a@fore.vn',
                'phone': '0901234567',
                'full_name': 'Nguyễn A',
                'shop_count': 2,
                'shop_names': 'Quán 1, Quán 2',
                'last_login_at': '2026-11-20T09:00:00Z',
                'is_platform_admin': true,
                'total_count': 42,
              },
            ];

      final repo = SupabaseAdminUsersRepository(rpc);
      final page = await repo.listUsers(search: ' a@fore ', limit: 20, offset: 20);

      expect(rpc.calls.single.$1, 'admin_list_users');
      expect(rpc.calls.single.$2, {
        'p_search': 'a@fore',
        'p_limit': 20,
        'p_offset': 20,
      });
      expect(page.totalCount, 42);
      expect(page.currentPage, 2);
      expect(page.totalPages, 3);
      expect(page.items.single.isPlatformAdmin, isTrue);
    });

    test('admin_list_errors sends p_limit and p_before ISO timestamp', () async {
      final before = DateTime.utc(2026, 11, 20, 10, 0);
      final rpc = _RecordingRpcClient()
        ..handler = (_, __) => [
              {
                'id': 99,
                'created_at': '2026-11-20T09:30:00Z',
                'user_id': 'u-1',
                'user_email': 'a@fore.vn',
                'shop_id': 's-1',
                'shop_name': 'Quán 1',
                'app_version': '0.1.0+1',
                'platform': 'android',
                'message': 'Boom',
                'stack': '#0 main',
                'context': {'k': 1},
              },
            ];

      final repo = SupabaseAdminErrorsRepository(rpc);
      final errors = await repo.listErrors(limit: 25, before: before);

      expect(rpc.calls.single.$1, 'admin_list_errors');
      expect(rpc.calls.single.$2, {
        'p_limit': 25,
        'p_before': before.toIso8601String(),
      });
      expect(errors.single.id, 99);
      expect(errors.single.stack, '#0 main');
    });

    test('admin_event_counts sends p_from and p_to', () async {
      final from = DateTime.utc(2026, 11, 1);
      final to = DateTime.utc(2026, 11, 8);
      final rpc = _RecordingRpcClient()
        ..handler = (_, __) => [
              {
                'day': '2026-11-02',
                'name': 'bill_paid',
                'event_count': 15,
                'user_count': 4,
              },
            ];

      final repo = SupabaseAdminEventsRepository(rpc);
      final rows = await repo.fetchEventCounts(from: from, to: to);

      expect(rpc.calls.single.$1, 'admin_event_counts');
      expect(rpc.calls.single.$2, {
        'p_from': from.toIso8601String(),
        'p_to': to.toIso8601String(),
      });
      expect(rows.single.name, 'bill_paid');
      expect(rows.single.eventCount, 15);
      expect(rows.single.userCount, 4);
    });

    test('admin_list_logins sends p_user_id and p_limit', () async {
      final rpc = _RecordingRpcClient()
        ..handler = (_, __) => [
              {
                'id': 7,
                'user_id': 'u-1',
                'user_email': 'a@fore.vn',
                'ip': '1.2.3.4',
                'user_agent': 'Chrome',
                'created_at': '2026-11-20T09:00:00Z',
              },
            ];

      final repo = SupabaseAdminLoginsRepository(rpc);
      final rows = await repo.listLogins(userId: 'u-1', limit: 50);

      expect(rpc.calls.single.$1, 'admin_list_logins');
      expect(rpc.calls.single.$2, {'p_user_id': 'u-1', 'p_limit': 50});
      expect(rows.single.ip, '1.2.3.4');
    });

    test('config repository reads get_app_config fallback and calls admin_set_config',
        () async {
      final rpc = _RecordingRpcClient()
        ..handler = (fn, params) {
          if (fn == 'get_app_config') {
            return {'min_version': '1.0.0', 'maintenance': false};
          }
          if (fn == 'admin_set_config') {
            return {
              'key': params!['p_key'],
              'value': params['p_value'],
              'updated_at': '2026-11-21T08:00:00Z',
              'updated_by': 'admin-id',
            };
          }
          throw StateError('Unexpected RPC $fn');
        };

      final repo = SupabaseAdminConfigRepository(rpc);
      final list = await repo.listConfigs();
      expect(list.map((e) => e.key).toList(), ['maintenance', 'min_version']);

      final saved = await repo.setConfig(key: ' MAINTENANCE ', value: true);
      expect(rpc.calls.last.$1, 'admin_set_config');
      expect(rpc.calls.last.$2, {'p_key': 'maintenance', 'p_value': true});
      expect(saved.value, isTrue);
    });
  });
}
