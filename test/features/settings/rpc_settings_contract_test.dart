import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/settings/data/rpc_settings_repository.dart';
import 'package:fore/features/settings/domain/settings_models.dart';

import '../../support/fakes.dart';

/// Hợp đồng giữa app và database (08_settings.sql + invite_staff/cancel_invite có sẵn):
/// tên hàm và tên tham số app gửi lên phải khớp chữ ký trong SQL.
Map<String, ({Set<String> all, Set<String> required})> _signatures() {
  final out = <String, ({Set<String> all, Set<String> required})>{};
  final re = RegExp(r'create or replace function (\w+)\(([^)]*)\)', multiLine: true);
  for (final f in Directory('database').listSync().whereType<File>()) {
    if (!RegExp(r'0[1-8]_.*\.sql$').hasMatch(f.path)) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      final all = <String>{};
      final required = <String>{};
      for (final raw in m.group(2)!.split(',')) {
        final part = raw.trim();
        if (part.isEmpty) continue;
        all.add(part.split(RegExp(r'\s+')).first);
        if (!part.toLowerCase().contains(' default ')) {
          required.add(part.split(RegExp(r'\s+')).first);
        }
      }
      out[m.group(1)!] = (all: all, required: required); // bản sau ghi đè bản trước
    }
  }
  return out;
}

void main() {
  test('mọi lời gọi RPC của Settings khớp chữ ký hàm trong database', () async {
    final sigs = _signatures();
    final rpc = FakeRpcClient({
      'my_permissions': <String, dynamic>{},
      'team_overview': <String, dynamic>{},
      'invite_staff': 'inv-1',
      'team_set_invite_role': null,
      'team_resend_invite': '2026-11-15T00:00:00Z',
      'cancel_invite': null,
      'team_set_role': null,
      'team_revoke': null,
      'roles_get': <String, dynamic>{},
      'roles_save': 1,
      'shop_profile_get': <String, dynamic>{},
      'shop_profile_save': <String, dynamic>{},
      'branches_overview': [],
      'floor_overview': {'areas': []},
      'area_save': 'a',
      'area_set_active': null,
      'table_save': 't',
      'table_set_active': null,
      'audit_feed': <String, dynamic>{},
      'support_create': <String, dynamic>{},
      'support_list': [],
    });
    final repo = RpcSettingsRepository(rpc);
    final day = DateTime(2026, 11, 8);

    await repo.myPermissions();
    await repo.team();
    await repo.invite(fullName: 'Lan', role: JobRole.cashier, phone: '0901234567');
    await repo.resendInvite('i');
    await repo.cancelInvite('i');
    await repo.setMemberRole('s', JobRole.manager);
    await repo.revokeMember('s');
    await repo.roleConfig(JobRole.staff);
    await repo.saveRole(JobRole.staff, {'inventory.record': true}, shopIds: ['x']);
    await repo.shopProfile();
    await repo.saveShopProfile(const ShopProfileDraft(name: 'Fore', address: 'x'));
    await repo.branches();
    await repo.floor();
    await repo.saveArea(null, 'Tầng trệt');
    await repo.setAreaActive('a', false);
    await repo.saveTable(areaId: 'a', name: 'B01', seats: 2);
    await repo.setTableActive('t', false);
    await repo.auditFeed(day, day, actorId: 's');
    await repo.createSupport(
        topic: SupportTopic.printer,
        message: 'May in loi',
        callback: false,
        shareDiagnostics: true,
        diagnostics: {'app_version': 'dev'});
    await repo.supportTickets();

    for (final c in rpc.calls) {
      final sig = sigs[c.fn];
      expect(sig, isNotNull, reason: 'database chưa có hàm ${c.fn}');
      final sent = (c.params ?? const <String, dynamic>{}).keys.toSet();
      expect(sent.difference(sig!.all), isEmpty, reason: '${c.fn}: gửi tham số database không có');
      expect(sig.required.difference(sent), isEmpty, reason: '${c.fn}: thiếu tham số bắt buộc');
    }
    final used = rpc.calls.map((c) => c.fn).toSet();
    expect(used.contains('team_set_invite_role'), isTrue);
  });

  test('mời vai trò Nhân viên không cần gọi gán vai trò (đã là mặc định)', () async {
    final rpc = FakeRpcClient({'invite_staff': 'inv-1'});
    await RpcSettingsRepository(rpc)
        .invite(fullName: 'Lan', role: JobRole.staff, phone: '0901234567');
    expect(rpc.calls.map((c) => c.fn), ['invite_staff']);
  });

  test('chỉ chủ mới đặt được vai trò Quản lý: không gửi team_set_invite_role cho Nhân viên', () async {
    final rpc = FakeRpcClient({'invite_staff': 'inv-1', 'team_set_invite_role': null});
    await RpcSettingsRepository(rpc)
        .invite(fullName: 'Lan', role: JobRole.manager, phone: '0901234567');
    expect(rpc.calls.map((c) => c.fn), ['invite_staff', 'team_set_invite_role']);
    expect(rpc.calls.last.params!['p_job_role'], 'manager');
  });
}
