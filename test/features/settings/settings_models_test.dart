import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/settings/application/audit_csv.dart';
import 'package:fore/features/settings/domain/settings_models.dart';
import 'package:fore/features/settings/presentation/team_screens.dart';

TeamMember _member({
  String role = 'staff',
  String job = 'staff',
  bool me = false,
  bool active = true,
}) =>
    TeamMember.fromJson({
      'staff_id': 'x',
      'full_name': 'A',
      'role': role,
      'job_role': job,
      'active': active,
      'is_me': me,
    });

void main() {
  group('quyền', () {
    test('chủ quán luôn có mọi quyền; vai trò khác chỉ có quyền được cấp', () {
      final owner = MyPermissions.fromJson({'is_owner': true, 'permissions': {}});
      expect(owner.can('data.export'), isTrue);
      expect(owner.can('bat-ky-quyen-nao'), isTrue);

      final mgr = MyPermissions.fromJson({
        'is_owner': false,
        'job_role': 'manager',
        'permissions': {'members.manage': true, 'data.export': false},
      });
      expect(mgr.jobRole, JobRole.manager);
      expect(mgr.can('members.manage'), isTrue);
      expect(mgr.can('data.export'), isFalse);
      expect(mgr.can('chua-co'), isFalse);
    });

    test('vai trò lạ rơi về Nhân viên (ít quyền nhất)', () {
      expect(JobRole.parse('ceo'), JobRole.staff);
      expect(JobRole.parse(null), JobRole.staff);
      expect(JobRole.parse('cashier').label, 'Thu ngân');
    });

    test('danh mục quyền không trùng khóa và có khóa nhạy cảm', () {
      final keys = permissionCatalog.map((p) => p.key).toList();
      expect(keys.toSet().length, keys.length);
      expect(permissionCatalog.where((p) => p.sensitive), isNotEmpty);
    });
  });

  group('canManageMember khớp luật ở database', () {
    final owner = MyPermissions.fromJson({'is_owner': true});
    final mgr = MyPermissions.fromJson({
      'is_owner': false,
      'job_role': 'manager',
      'permissions': {'members.manage': true},
    });
    final noPerm = MyPermissions.fromJson({'is_owner': false, 'permissions': {}});

    test('không ai động vào chủ quán hay chính mình', () {
      expect(canManageMember(owner, _member(role: 'owner')), isFalse);
      expect(canManageMember(owner, _member(me: true)), isFalse);
    });

    test('chủ quản lý được quản lý khác; quản lý chỉ quản lý cấp dưới', () {
      expect(canManageMember(owner, _member(job: 'manager')), isTrue);
      expect(canManageMember(mgr, _member(job: 'manager')), isFalse);
      expect(canManageMember(mgr, _member(job: 'cashier')), isTrue);
    });

    test('không có quyền thành viên thì không thao tác được', () {
      expect(canManageMember(noPerm, _member()), isFalse);
    });
  });

  test('tổng quan nhân sự tách đang làm / đã nghỉ', () {
    final t = TeamOverview.fromJson({
      'members': [
        {'staff_id': 'a', 'full_name': 'A', 'role': 'owner', 'active': true},
        {'staff_id': 'b', 'full_name': 'B', 'role': 'staff', 'active': false},
      ],
      'invites': [],
    });
    expect(t.working.map((m) => m.staffId), ['a']);
    expect(t.revoked.map((m) => m.staffId), ['b']);
    expect(t.members.first.roleLabel, 'Chủ quán');
  });

  test('khu vực: chỉ tính bàn đang dùng vào số chỗ', () {
    final a = FloorArea.fromJson({
      'id': 'a',
      'name': 'Tầng trệt',
      'tables': [
        {'id': '1', 'name': 'B01', 'seats': 2, 'active': true},
        {'id': '2', 'name': 'B02', 'seats': 4, 'active': true},
        {'id': '3', 'name': 'B03', 'seats': 6, 'active': false},
      ],
    });
    expect(a.activeTables, 2);
    expect(a.seatTotal, 6);
  });

  test('số điện thoại quán hiển thị lại dạng 0xxx, số lạ giữ nguyên', () {
    expect(localPhone('84901234567'), '0901234567');
    expect(localPhone('842838123456'), '02838123456');
    expect(localPhone('+1 415 555 0101'), '+1 415 555 0101');
    expect(localPhone(null), isNull);
    final p = ShopProfile.fromJson({'id': 'x', 'code': 'Q0001', 'name': 'A', 'phone': '84901234567'});
    expect(p.phone, '0901234567');
  });

  test('hồ sơ quán: nháp gửi đủ trường và giờ mặc định', () {
    final j = const ShopProfileDraft(name: 'Fore', address: '12 Nguyễn Du').toJson();
    expect(j['open_time'], '06:00');
    expect(j['open_daily'], true);
    expect(j['tax_code'], isNull);
  });

  group('CSV nhật ký', () {
    test('có dòng tiêu đề, escape dấu ngoặc kép và dấu phẩy', () {
      final csv = auditCsv([
        AuditEvent(
          id: 1,
          at: DateTime(2026, 11, 8, 9, 41),
          action: 'revoke_member',
          entity: 'staff',
          actorName: 'Chủ, "Minh"',
          detail: const {'name': 'Lan'},
        ),
      ]);
      final lines = csv.trim().split('\r\n');
      expect(lines.first, 'Thời gian,Người thực hiện,Hành động,Đối tượng,Chi tiết');
      expect(lines[1], contains('"2026-11-08 09:41"'));
      expect(lines[1], contains('"Chủ, ""Minh"""'));
      expect(lines[1], contains('Thu hồi thành viên'));
    });

    test('chặn CSV injection: ô bắt đầu bằng = + - @ được thêm dấu nháy', () {
      final csv = auditCsv([
        AuditEvent(id: 1, at: DateTime(2026), action: 'x', entity: '=SUM(A1)', actorName: '+cmd'),
      ]);
      expect(csv, contains('"\'=SUM(A1)"'));
      expect(csv, contains('"\'+cmd"'));
    });

    test('hành động lạ giữ nguyên mã để không che dữ liệu', () {
      expect(auditLabel('mot_hanh_dong_moi'), 'mot_hanh_dong_moi');
    });
  });
}
