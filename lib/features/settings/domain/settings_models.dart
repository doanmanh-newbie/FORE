/// Mô hình dữ liệu của tab "Thêm" (database/08_settings.sql): quyền, nhân sự, hồ sơ quán,
/// khu vực và bàn, nhật ký, hỗ trợ. Không phụ thuộc Flutter hay Supabase.
library;

num? _num(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  throw FormatException('Trường "$k" cần là số, nhận được: $v');
}

int _int(Map<String, dynamic> m, String k, [int fallback = 0]) =>
    _num(m, k)?.round() ?? fallback;

String _str(Map<String, dynamic> m, String k, [String fallback = '']) {
  final v = m[k];
  return v == null ? fallback : '$v';
}

String? _strOrNull(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v == null) return null;
  final t = '$v'.trim();
  return t.isEmpty ? null : t;
}

bool _bool(Map<String, dynamic> m, String k) => m[k] == true;

DateTime? _time(Map<String, dynamic> m, String k) {
  final v = m[k];
  return v is String ? DateTime.tryParse(v) : null;
}

List<Map<String, dynamic>> _list(Map<String, dynamic> m, String k) {
  final v = m[k];
  if (v == null) return const [];
  if (v is! List) throw FormatException('Trường "$k" cần là danh sách');
  return [
    for (final e in v)
      if (e is Map<String, dynamic>) e
  ];
}

List<Map<String, dynamic>> settingsRows(dynamic raw) {
  if (raw is! List) {
    throw FormatException('Cần danh sách, nhận được: ${raw.runtimeType}');
  }
  return [
    for (final e in raw)
      if (e is Map<String, dynamic>) e
  ];
}

Map<String, dynamic> settingsObject(dynamic raw) {
  if (raw is Map<String, dynamic>) return raw;
  throw FormatException('Cần đối tượng JSON, nhận được: ${raw.runtimeType}');
}

// ---------- Vai trò và quyền ----------

/// Vai trò chi tiết của nhân viên (chủ quán luôn có mọi quyền và không nằm trong danh sách này).
enum JobRole {
  manager('manager', 'Quản lý'),
  cashier('cashier', 'Thu ngân'),
  staff('staff', 'Nhân viên');

  const JobRole(this.code, this.label);

  final String code;
  final String label;

  static JobRole parse(String? v) => JobRole.values.firstWhere(
        (r) => r.code == v,
        orElse: () => JobRole.staff,
      );
}

/// Một quyền có công tắc. Chỉ liệt kê quyền ĐÃ được database áp dụng.
class PermissionDef {
  const PermissionDef(this.key, this.label, this.hint, {this.sensitive = false});

  final String key;
  final String label;
  final String hint;
  final bool sensitive;
}

const permissionCatalog = <PermissionDef>[
  PermissionDef('inventory.record', 'Ghi nhận kho',
      'Nhập hàng nhanh, ghi hao hụt, đếm và gửi kiểm kê'),
  PermissionDef('floor.manage', 'Quản lý khu vực và bàn',
      'Thêm, sửa, tạm ẩn khu vực và bàn'),
  PermissionDef('inventory.costs', 'Xem giá vốn trong Kho',
      'Tồn có giá trị, giá nhập, giá bình quân, nhà cung cấp',
      sensitive: true),
  PermissionDef('inventory.approve', 'Duyệt điều chỉnh kho',
      'Xem chênh lệch kiểm kê và duyệt thay đổi tồn',
      sensitive: true),
  PermissionDef('data.export', 'Xem nhật ký và xuất dữ liệu',
      'Nhật ký quản trị và tệp CSV',
      sensitive: true),
  PermissionDef('members.manage', 'Quản lý thành viên',
      'Xem danh sách, đổi vai trò và thu hồi (mời người mới vẫn do chủ quán)',
      sensitive: true),
  PermissionDef('shop.manage', 'Sửa hồ sơ quán',
      'Tên, liên hệ, giờ mở cửa, thông tin hóa đơn',
      sensitive: true),
];

class MyPermissions {
  const MyPermissions(
      {required this.isOwner, required this.jobRole, required this.granted});

  factory MyPermissions.fromJson(Map<String, dynamic> j) {
    final p = j['permissions'];
    return MyPermissions(
      isOwner: _bool(j, 'is_owner'),
      jobRole: JobRole.parse(_strOrNull(j, 'job_role')),
      granted: {
        if (p is Map<String, dynamic>)
          for (final e in p.entries)
            if (e.value == true) e.key
      },
    );
  }

  final bool isOwner;
  final JobRole jobRole;
  final Set<String> granted;

  bool can(String key) => isOwner || granted.contains(key);
}

class RoleConfig {
  const RoleConfig(
      {required this.role, required this.members, required this.permissions});

  factory RoleConfig.fromJson(Map<String, dynamic> j) {
    final p = j['permissions'];
    return RoleConfig(
      role: JobRole.parse(_strOrNull(j, 'job_role')),
      members: [for (final e in (j['members'] as List? ?? const [])) '$e'],
      permissions: {
        if (p is Map<String, dynamic>)
          for (final e in p.entries) e.key: e.value == true
      },
    );
  }

  final JobRole role;
  final List<String> members;
  final Map<String, bool> permissions;

  bool allowed(String key) => permissions[key] ?? false;
}

// ---------- Nhân sự ----------
class TeamMember {
  const TeamMember({
    required this.staffId,
    required this.fullName,
    required this.isOwner,
    required this.jobRole,
    required this.active,
    required this.hasPin,
    required this.isMe,
    required this.onShift,
    this.phone,
    this.email,
    this.joinedAt,
    this.deactivatedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        staffId: _str(j, 'staff_id'),
        fullName: _str(j, 'full_name'),
        isOwner: _str(j, 'role') == 'owner',
        jobRole: JobRole.parse(_strOrNull(j, 'job_role')),
        active: j['active'] != false,
        phone: _strOrNull(j, 'phone'),
        email: _strOrNull(j, 'email'),
        hasPin: _bool(j, 'has_pin'),
        joinedAt: _time(j, 'joined_at'),
        deactivatedAt: _time(j, 'deactivated_at'),
        isMe: _bool(j, 'is_me'),
        onShift: _bool(j, 'on_shift'),
      );

  final String staffId;
  final String fullName;
  final bool isOwner;
  final JobRole jobRole;
  final bool active;
  final String? phone;
  final String? email;
  final bool hasPin;
  final DateTime? joinedAt;
  final DateTime? deactivatedAt;
  final bool isMe;
  final bool onShift;

  String get roleLabel => isOwner ? 'Chủ quán' : jobRole.label;
}

class TeamInvite {
  const TeamInvite({
    required this.id,
    required this.fullName,
    required this.jobRole,
    required this.expired,
    this.phone,
    this.email,
    this.createdAt,
    this.expiresAt,
  });

  factory TeamInvite.fromJson(Map<String, dynamic> j) => TeamInvite(
        id: _str(j, 'id'),
        fullName: _str(j, 'full_name'),
        phone: _strOrNull(j, 'phone'),
        email: _strOrNull(j, 'email'),
        jobRole: JobRole.parse(_strOrNull(j, 'job_role')),
        createdAt: _time(j, 'created_at'),
        expiresAt: _time(j, 'expires_at'),
        expired: _bool(j, 'expired'),
      );

  final String id;
  final String fullName;
  final String? phone;
  final String? email;
  final JobRole jobRole;
  final DateTime? createdAt;
  final DateTime? expiresAt;
  final bool expired;
}

class TeamOverview {
  const TeamOverview({required this.members, required this.invites});

  factory TeamOverview.fromJson(Map<String, dynamic> j) => TeamOverview(
        members: _list(j, 'members').map(TeamMember.fromJson).toList(),
        invites: _list(j, 'invites').map(TeamInvite.fromJson).toList(),
      );

  final List<TeamMember> members;
  final List<TeamInvite> invites;

  List<TeamMember> get working => members.where((m) => m.active).toList();
  List<TeamMember> get revoked => members.where((m) => !m.active).toList();
}

/// Số điện thoại lưu ở database dạng quốc tế (84901234567); hiển thị lại dạng quen thuộc 0901234567.
String? localPhone(String? stored) {
  if (stored == null) return null;
  final d = stored.replaceAll(RegExp(r'[^0-9]'), '');
  // Vietnamese mobile numbers have 9 digits after country code 84; fixed-line
  // numbers can have 10 digits (for example 84 + 28 + 8-digit subscriber).
  if (d.startsWith('84') && d.length >= 11 && d.length <= 12) {
    return '0${d.substring(2)}';
  }
  return stored;
}

// ---------- Hồ sơ quán ----------
class ShopProfile {
  const ShopProfile({
    required this.id,
    required this.code,
    required this.name,
    required this.openDaily,
    required this.openTime,
    required this.closeTime,
    required this.timezone,
    required this.canEdit,
    required this.missingInvoiceInfo,
    this.legalName,
    this.taxCode,
    this.email,
    this.phone,
    this.address,
  });

  factory ShopProfile.fromJson(Map<String, dynamic> j) => ShopProfile(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        name: _str(j, 'name'),
        legalName: _strOrNull(j, 'legal_name'),
        taxCode: _strOrNull(j, 'tax_code'),
        email: _strOrNull(j, 'email'),
        phone: localPhone(_strOrNull(j, 'phone')),
        address: _strOrNull(j, 'address'),
        openDaily: j['open_daily'] != false,
        openTime: _str(j, 'open_time', '06:00'),
        closeTime: _str(j, 'close_time', '22:00'),
        timezone: _str(j, 'timezone', 'Asia/Ho_Chi_Minh'),
        canEdit: _bool(j, 'can_edit'),
        missingInvoiceInfo: _bool(j, 'missing_invoice_info'),
      );

  final String id;
  final String code;
  final String name;
  final String? legalName;
  final String? taxCode;
  final String? email;
  final String? phone;
  final String? address;
  final bool openDaily;
  final String openTime;
  final String closeTime;
  final String timezone;
  final bool canEdit;
  final bool missingInvoiceInfo;
}

class ShopProfileDraft {
  const ShopProfileDraft({
    required this.name,
    required this.address,
    this.legalName,
    this.taxCode,
    this.email,
    this.phone,
    this.openDaily = true,
    this.openTime = '06:00',
    this.closeTime = '22:00',
    this.timezone = 'Asia/Ho_Chi_Minh',
  });

  final String name;
  final String address;
  final String? legalName;
  final String? taxCode;
  final String? email;
  final String? phone;
  final bool openDaily;
  final String openTime;
  final String closeTime;
  final String timezone;

  Map<String, dynamic> toJson() => {
        'name': name,
        'address': address,
        'legal_name': legalName,
        'tax_code': taxCode,
        'email': email,
        'phone': phone,
        'open_daily': openDaily,
        'open_time': openTime,
        'close_time': closeTime,
        'timezone': timezone,
      };
}

class Branch {
  const Branch({
    required this.shopId,
    required this.code,
    required this.name,
    required this.isCurrent,
    required this.activeMembers,
    required this.pendingInvites,
    this.address,
  });

  factory Branch.fromJson(Map<String, dynamic> j) => Branch(
        shopId: _str(j, 'shop_id'),
        code: _str(j, 'code'),
        name: _str(j, 'name'),
        address: _strOrNull(j, 'address'),
        isCurrent: _bool(j, 'is_current'),
        activeMembers: _int(j, 'active_members'),
        pendingInvites: _int(j, 'pending_invites'),
      );

  final String shopId;
  final String code;
  final String name;
  final String? address;
  final bool isCurrent;
  final int activeMembers;
  final int pendingInvites;
}

// ---------- Khu vực và bàn ----------
class FloorTable {
  const FloorTable({
    required this.id,
    required this.name,
    required this.seats,
    required this.active,
    required this.inUse,
  });

  factory FloorTable.fromJson(Map<String, dynamic> j) => FloorTable(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        seats: _int(j, 'seats', 2),
        active: j['active'] != false,
        inUse: _bool(j, 'in_use'),
      );

  final String id;
  final String name;
  final int seats;
  final bool active;
  final bool inUse;
}

class FloorArea {
  const FloorArea(
      {required this.id,
      required this.name,
      required this.active,
      required this.tables});

  factory FloorArea.fromJson(Map<String, dynamic> j) => FloorArea(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        active: j['active'] != false,
        tables: _list(j, 'tables').map(FloorTable.fromJson).toList(),
      );

  final String id;
  final String name;
  final bool active;
  final List<FloorTable> tables;

  int get seatTotal =>
      tables.where((t) => t.active).fold(0, (a, t) => a + t.seats);
  int get activeTables => tables.where((t) => t.active).length;
}

// ---------- Nhật ký ----------
class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.at,
    required this.action,
    required this.entity,
    this.actorName,
    this.detail,
  });

  factory AuditEvent.fromJson(Map<String, dynamic> j) => AuditEvent(
        id: _int(j, 'id'),
        at: _time(j, 'at') ?? DateTime.now(),
        action: _str(j, 'action'),
        entity: _str(j, 'entity'),
        actorName: _strOrNull(j, 'actor_name'),
        detail: j['detail'] is Map<String, dynamic>
            ? j['detail'] as Map<String, dynamic>
            : null,
      );

  final int id;
  final DateTime at;
  final String action;
  final String entity;
  final String? actorName;
  final Map<String, dynamic>? detail;
}

class AuditActor {
  const AuditActor({required this.id, required this.name});

  factory AuditActor.fromJson(Map<String, dynamic> j) =>
      AuditActor(id: _str(j, 'staff_id'), name: _str(j, 'full_name'));

  final String id;
  final String name;
}

class AuditFeed {
  const AuditFeed({required this.actors, required this.events});

  factory AuditFeed.fromJson(Map<String, dynamic> j) => AuditFeed(
        actors: _list(j, 'actors').map(AuditActor.fromJson).toList(),
        events: _list(j, 'events').map(AuditEvent.fromJson).toList(),
      );

  final List<AuditActor> actors;
  final List<AuditEvent> events;
}

// ---------- Hỗ trợ ----------
enum SupportTopic {
  setup('setup', 'Bắt đầu và thiết lập quán'),
  printer('printer', 'Máy in không kết nối'),
  permissions('permissions', 'Quyền nhân viên và ca làm'),
  data('data', 'Dữ liệu và gói sử dụng'),
  other('other', 'Việc khác');

  const SupportTopic(this.code, this.label);

  final String code;
  final String label;

  static SupportTopic parse(String? v) => SupportTopic.values
      .firstWhere((t) => t.code == v, orElse: () => SupportTopic.other);
}

class SupportTicket {
  const SupportTicket(
      {required this.id,
      required this.code,
      required this.topic,
      required this.message,
      required this.open,
      this.createdAt});

  factory SupportTicket.fromJson(Map<String, dynamic> j) => SupportTicket(
        id: _str(j, 'id'),
        code: _str(j, 'code'),
        topic: SupportTopic.parse(_strOrNull(j, 'topic')),
        message: _str(j, 'message'),
        open: _str(j, 'status') != 'closed',
        createdAt: _time(j, 'created_at'),
      );

  final String id;
  final String code;
  final SupportTopic topic;
  final String message;
  final bool open;
  final DateTime? createdAt;
}

class SupportReceipt {
  const SupportReceipt({required this.code, required this.diagnosticsSent});

  factory SupportReceipt.fromJson(Map<String, dynamic> j) => SupportReceipt(
      code: _str(j, 'code'), diagnosticsSent: _bool(j, 'diagnostics_sent'));

  final String code;
  final bool diagnosticsSent;
}
