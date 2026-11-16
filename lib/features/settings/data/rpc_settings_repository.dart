import '../../../core/data/rpc_client.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

/// Gọi các hàm của database/08_settings.sql (và `invite_staff`, `cancel_invite` có sẵn từ module 02/04).
class RpcSettingsRepository implements SettingsRepository {
  RpcSettingsRepository(this._rpc);

  final RpcClient _rpc;

  Future<T> _parse<T>(Future<dynamic> call, T Function(dynamic raw) map) async {
    final raw = await call;
    try {
      return map(raw);
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }

  String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  @override
  Future<MyPermissions> myPermissions() => _parse(_rpc.call('my_permissions'),
      (r) => MyPermissions.fromJson(settingsObject(r)));

  @override
  Future<TeamOverview> team() => _parse(_rpc.call('team_overview'),
      (r) => TeamOverview.fromJson(settingsObject(r)));

  @override
  Future<String> invite({
    required String fullName,
    required JobRole role,
    String? phone,
    String? email,
  }) async {
    final id = '${await _rpc.call('invite_staff', {
          'p_phone': _clean(phone),
          'p_full_name': fullName.trim(),
          'p_email': _clean(email),
        })}';
    // Nếu bước gán vai trò lỗi, lời mời vẫn tồn tại với vai trò "Nhân viên" (ít quyền nhất).
    if (role != JobRole.staff) {
      await _rpc.call(
          'team_set_invite_role', {'p_invite': id, 'p_job_role': role.code});
    }
    return id;
  }

  @override
  Future<DateTime> resendInvite(String inviteId) async {
    final raw = await _rpc.call('team_resend_invite', {'p_invite': inviteId});
    return DateTime.tryParse('$raw') ?? DateTime.now();
  }

  @override
  Future<void> cancelInvite(String inviteId) async {
    await _rpc.call('cancel_invite', {'p_invite': inviteId});
  }

  @override
  Future<void> setMemberRole(String staffId, JobRole role) async {
    await _rpc
        .call('team_set_role', {'p_staff': staffId, 'p_job_role': role.code});
  }

  @override
  Future<void> revokeMember(String staffId) async {
    await _rpc.call('team_revoke', {'p_staff': staffId});
  }

  @override
  Future<RoleConfig> roleConfig(JobRole role) => _parse(
      _rpc.call('roles_get', {'p_job_role': role.code}),
      (r) => RoleConfig.fromJson(settingsObject(r)));

  @override
  Future<int> saveRole(JobRole role, Map<String, bool> permissions,
      {List<String>? shopIds}) async {
    final raw = await _rpc.call('roles_save', {
      'p_job_role': role.code,
      'p_permissions': permissions,
      'p_shops': shopIds,
    });
    return raw is num ? raw.round() : 0;
  }

  @override
  Future<ShopProfile> shopProfile() => _parse(_rpc.call('shop_profile_get'),
      (r) => ShopProfile.fromJson(settingsObject(r)));

  @override
  Future<ShopProfile> saveShopProfile(ShopProfileDraft draft) => _parse(
      _rpc.call('shop_profile_save', {'p': draft.toJson()}),
      (r) => ShopProfile.fromJson(settingsObject(r)));

  @override
  Future<List<Branch>> branches() => _parse(_rpc.call('branches_overview'),
      (r) => settingsRows(r).map(Branch.fromJson).toList());

  @override
  Future<List<FloorArea>> floor() => _parse(_rpc.call('floor_overview'), (r) {
        final o = settingsObject(r);
        return settingsRows(o['areas'] ?? const [])
            .map(FloorArea.fromJson)
            .toList();
      });

  @override
  Future<String> saveArea(String? id, String name) async =>
      '${await _rpc.call('area_save', {'p_id': id, 'p_name': name})}';

  @override
  Future<void> setAreaActive(String id, bool active) async {
    await _rpc.call('area_set_active', {'p_id': id, 'p_active': active});
  }

  @override
  Future<String> saveTable(
          {String? id,
          required String areaId,
          required String name,
          required int seats}) async =>
      '${await _rpc.call('table_save', {
            'p_id': id,
            'p_area': areaId,
            'p_name': name,
            'p_seats': seats,
          })}';

  @override
  Future<void> setTableActive(String id, bool active) async {
    await _rpc.call('table_set_active', {'p_id': id, 'p_active': active});
  }

  @override
  Future<AuditFeed> auditFeed(DateTime from, DateTime to,
          {String? actorId}) =>
      _parse(
        _rpc.call('audit_feed', {
          'p_from': _day(from),
          'p_to': _day(to),
          'p_actor': actorId,
          'p_limit': 200,
        }),
        (r) => AuditFeed.fromJson(settingsObject(r)),
      );

  @override
  Future<SupportReceipt> createSupport({
    required SupportTopic topic,
    required String message,
    required bool callback,
    required bool shareDiagnostics,
    Map<String, dynamic>? diagnostics,
  }) =>
      _parse(
        _rpc.call('support_create', {
          'p_topic': topic.code,
          'p_message': message.trim(),
          'p_contact': callback ? 'callback' : 'in_app',
          'p_diagnostics': shareDiagnostics ? diagnostics : null,
          'p_consent': shareDiagnostics,
        }),
        (r) => SupportReceipt.fromJson(settingsObject(r)),
      );

  @override
  Future<List<SupportTicket>> supportTickets() => _parse(
      _rpc.call('support_list'),
      (r) => settingsRows(r).map(SupportTicket.fromJson).toList());
}
