import '../../core/data/json_row.dart';

/// Thông tin tài khoản super-admin đang đăng nhập.
class AdminIdentity {
  const AdminIdentity({
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;
}

/// Một quán trả về từ `admin_list_shops()`.
class AdminShop {
  const AdminShop({
    required this.id,
    required this.name,
    required this.code,
    required this.createdAt,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerEmail,
    required this.memberCount,
    required this.lastBillAt,
  });

  final String id;
  final String name;
  final String? code;
  final DateTime createdAt;
  final String? ownerUserId;
  final String? ownerName;
  final String? ownerEmail;
  final int memberCount;
  final DateTime? lastBillAt;

  factory AdminShop.fromJson(Map<String, dynamic> row) => AdminShop(
        id: row.str('id'),
        name: row.str('name'),
        code: row.strOrNull('code'),
        createdAt: row.time('created_at'),
        ownerUserId: row.strOrNull('owner_user_id'),
        ownerName: row.strOrNull('owner_name'),
        ownerEmail: row.strOrNull('owner_email'),
        memberCount: row.integer('member_count'),
        lastBillAt: row.timeOrNull('last_bill_at'),
      );
}

/// Một người dùng trả về từ `admin_list_users(...)`.
class AdminUser {
  const AdminUser({
    required this.userId,
    required this.email,
    required this.phone,
    required this.fullName,
    required this.shopCount,
    required this.shopNames,
    required this.lastLoginAt,
    required this.isPlatformAdmin,
    required this.totalCount,
  });

  final String userId;
  final String? email;
  final String? phone;
  final String? fullName;
  final int shopCount;
  final String? shopNames;
  final DateTime? lastLoginAt;
  final bool isPlatformAdmin;
  final int totalCount;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    final tel = phone?.trim();
    if (tel != null && tel.isNotEmpty) return tel;
    return userId;
  }

  factory AdminUser.fromJson(Map<String, dynamic> row) => AdminUser(
        userId: row.str('user_id'),
        email: row.strOrNull('email'),
        phone: row.strOrNull('phone'),
        fullName: row.strOrNull('full_name'),
        shopCount: row.integer('shop_count'),
        shopNames: row.strOrNull('shop_names'),
        lastLoginAt: row.timeOrNull('last_login_at'),
        isPlatformAdmin: row.flag('is_platform_admin'),
        totalCount: row.integer('total_count'),
      );
}

/// Một trang kết quả người dùng kèm tổng số dòng khớp tìm kiếm.
class AdminUserPage {
  const AdminUserPage({
    required this.items,
    required this.totalCount,
    required this.limit,
    required this.offset,
  });

  final List<AdminUser> items;
  final int totalCount;
  final int limit;
  final int offset;

  int get currentPage => limit <= 0 ? 1 : (offset ~/ limit) + 1;

  int get totalPages =>
      totalCount <= 0 || limit <= 0 ? 1 : ((totalCount - 1) ~/ limit) + 1;

  bool get hasPrevious => offset > 0;

  bool get hasNext => offset + items.length < totalCount;
}

/// Một dòng nhật ký lỗi trả về từ `admin_list_errors(...)`.
class AdminErrorLog {
  const AdminErrorLog({
    required this.id,
    required this.createdAt,
    required this.userId,
    required this.userEmail,
    required this.shopId,
    required this.shopName,
    required this.appVersion,
    required this.platform,
    required this.message,
    required this.stack,
    required this.context,
  });

  final int id;
  final DateTime createdAt;
  final String? userId;
  final String? userEmail;
  final String? shopId;
  final String? shopName;
  final String? appVersion;
  final String? platform;
  final String message;
  final String? stack;
  final dynamic context;

  factory AdminErrorLog.fromJson(Map<String, dynamic> row) => AdminErrorLog(
        id: row.integer('id'),
        createdAt: row.time('created_at'),
        userId: row.strOrNull('user_id'),
        userEmail: row.strOrNull('user_email'),
        shopId: row.strOrNull('shop_id'),
        shopName: row.strOrNull('shop_name'),
        appVersion: row.strOrNull('app_version'),
        platform: row.strOrNull('platform'),
        message: row.str('message'),
        stack: row.strOrNull('stack'),
        context: row['context'],
      );
}

/// Một dòng thống kê sự kiện theo ngày (giờ VN) từ `admin_event_counts(...)`.
class AdminEventCount {
  const AdminEventCount({
    required this.day,
    required this.name,
    required this.eventCount,
    required this.userCount,
  });

  final DateTime day;
  final String name;
  final int eventCount;
  final int userCount;

  factory AdminEventCount.fromJson(Map<String, dynamic> row) => AdminEventCount(
        day: row.time('day'),
        name: row.str('name'),
        eventCount: row.integer('event_count'),
        userCount: row.integer('user_count'),
      );
}

/// Một dòng lịch sử IP đăng nhập từ `admin_list_logins(...)`.
class AdminLoginIp {
  const AdminLoginIp({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.ip,
    required this.userAgent,
    required this.createdAt,
  });

  final int id;
  final String userId;
  final String? userEmail;
  final String? ip;
  final String? userAgent;
  final DateTime createdAt;

  factory AdminLoginIp.fromJson(Map<String, dynamic> row) => AdminLoginIp(
        id: row.integer('id'),
        userId: row.str('user_id'),
        userEmail: row.strOrNull('user_email'),
        ip: row.strOrNull('ip'),
        userAgent: row.strOrNull('user_agent'),
        createdAt: row.time('created_at'),
      );
}

/// Một mục cấu hình từ xa trong bảng `app_config`.
class AdminConfigEntry {
  const AdminConfigEntry({
    required this.key,
    required this.value,
    this.updatedAt,
    this.updatedBy,
  });

  final String key;
  final dynamic value;
  final DateTime? updatedAt;
  final String? updatedBy;

  factory AdminConfigEntry.fromJson(Map<String, dynamic> row) =>
      AdminConfigEntry(
        key: row.str('key'),
        value: row['value'],
        updatedAt: row.timeOrNull('updated_at'),
        updatedBy: row.strOrNull('updated_by'),
      );
}
