import 'package:fore/features/settings/domain/settings_models.dart';
import 'package:fore/features/settings/domain/settings_repository.dart';

/// Settings giả cho test màn hình: dữ liệu cố định, ghi lại các lệnh đã gọi.
class FakeSettingsRepository implements SettingsRepository {
  FakeSettingsRepository({this.me = _owner, TeamOverview? team})
      : teamData = team ?? _defaultTeam;

  static const _owner =
      MyPermissions(isOwner: true, jobRole: JobRole.staff, granted: {});

  static final _defaultTeam = TeamOverview.fromJson({
    'members': [
      {'staff_id': 'o', 'full_name': 'Minh Anh', 'role': 'owner', 'job_role': 'staff', 'active': true, 'is_me': true, 'has_pin': false},
      {'staff_id': 'a', 'full_name': 'Ngọc Lan', 'role': 'staff', 'job_role': 'cashier', 'active': true, 'phone': '0901234567', 'has_pin': true, 'on_shift': true},
      {'staff_id': 'b', 'full_name': 'Văn Hải', 'role': 'staff', 'job_role': 'manager', 'active': true, 'has_pin': true},
      {'staff_id': 'c', 'full_name': 'Thu Hà', 'role': 'staff', 'job_role': 'staff', 'active': false, 'has_pin': true},
    ],
    'invites': [
      {'id': 'i1', 'full_name': 'Bảo Trân', 'phone': '0911222333', 'job_role': 'staff', 'expired': false},
      {'id': 'i2', 'full_name': 'Đức Anh', 'phone': '0911000111', 'job_role': 'cashier', 'expired': true},
    ],
  });

  final MyPermissions me;
  final TeamOverview teamData;
  final List<String> calls = [];

  @override
  Future<MyPermissions> myPermissions() async => me;

  @override
  Future<TeamOverview> team() async => teamData;

  @override
  Future<void> revokeMember(String staffId) async => calls.add('revoke:$staffId');

  @override
  Future<void> setMemberRole(String staffId, JobRole role) async =>
      calls.add('role:$staffId:${role.code}');

  @override
  Future<DateTime> resendInvite(String inviteId) async {
    calls.add('resend:$inviteId');
    return DateTime.now();
  }

  @override
  Future<void> cancelInvite(String inviteId) async => calls.add('cancel:$inviteId');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
