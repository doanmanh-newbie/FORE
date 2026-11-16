import 'settings_models.dart';

/// Hợp đồng dữ liệu của tab "Thêm". Bản thật gọi RPC Supabase, bản giả dùng trong test.
abstract interface class SettingsRepository {
  Future<MyPermissions> myPermissions();

  // Nhân sự
  Future<TeamOverview> team();

  /// Mời một người. Gọi `invite_staff` (kiểm tra số điện thoại/email, trùng người) rồi gán vai trò cho lời mời.
  Future<String> invite({
    required String fullName,
    required JobRole role,
    String? phone,
    String? email,
  });
  Future<DateTime> resendInvite(String inviteId);
  Future<void> cancelInvite(String inviteId);
  Future<void> setMemberRole(String staffId, JobRole role);
  Future<void> revokeMember(String staffId);

  // Vai trò và quyền
  Future<RoleConfig> roleConfig(JobRole role);
  Future<int> saveRole(JobRole role, Map<String, bool> permissions,
      {List<String>? shopIds});

  // Hồ sơ quán
  Future<ShopProfile> shopProfile();
  Future<ShopProfile> saveShopProfile(ShopProfileDraft draft);
  Future<List<Branch>> branches();

  // Khu vực và bàn
  Future<List<FloorArea>> floor();
  Future<String> saveArea(String? id, String name);
  Future<void> setAreaActive(String id, bool active);
  Future<String> saveTable(
      {String? id,
      required String areaId,
      required String name,
      required int seats});
  Future<void> setTableActive(String id, bool active);

  // Nhật ký
  Future<AuditFeed> auditFeed(DateTime from, DateTime to, {String? actorId});

  // Hỗ trợ
  Future<SupportReceipt> createSupport({
    required SupportTopic topic,
    required String message,
    required bool callback,
    required bool shareDiagnostics,
    Map<String, dynamic>? diagnostics,
  });
  Future<List<SupportTicket>> supportTickets();
}
