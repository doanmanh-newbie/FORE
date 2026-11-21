import 'admin_models.dart';

/// Giao diện xác thực super-admin cho Admin Web.
abstract interface class AdminAuthRepository {
  /// Kiểm tra phiên đang đăng nhập hiện tại.
  /// Nếu chưa đăng nhập hoặc không phải super-admin (tự đăng xuất), trả về `null`.
  Future<AdminIdentity?> restoreSession();

  /// Đăng nhập bằng email + mật khẩu và kiểm tra `is_platform_admin()`.
  /// Nếu không phải super-admin, tự đăng xuất và ném `DatabaseFailure('FORBIDDEN')`.
  Future<AdminIdentity> signIn({
    required String email,
    required String password,
  });

  Future<void> signOut();
}

/// Giao diện dữ liệu màn hình Danh sách quán (`admin_list_shops`).
abstract interface class AdminShopsRepository {
  Future<List<AdminShop>> listShops();
}

/// Giao diện dữ liệu màn hình Người dùng (`admin_list_users`).
abstract interface class AdminUsersRepository {
  Future<AdminUserPage> listUsers({
    String? search,
    int limit = 20,
    int offset = 0,
  });
}

/// Giao diện dữ liệu màn hình Nhật ký lỗi (`admin_list_errors`).
abstract interface class AdminErrorsRepository {
  Future<List<AdminErrorLog>> listErrors({
    int limit = 50,
    DateTime? before,
  });
}

/// Giao diện dữ liệu màn hình Thống kê sự kiện (`admin_event_counts`).
abstract interface class AdminEventsRepository {
  Future<List<AdminEventCount>> fetchEventCounts({
    required DateTime from,
    required DateTime to,
  });
}

/// Giao diện dữ liệu màn hình IP đăng nhập (`admin_list_logins`).
abstract interface class AdminLoginsRepository {
  Future<List<AdminLoginIp>> listLogins({
    String? userId,
    int limit = 100,
  });
}

/// Giao diện dữ liệu màn hình Cấu hình từ xa (`app_config` / `admin_set_config`).
abstract interface class AdminConfigRepository {
  Future<List<AdminConfigEntry>> listConfigs();

  Future<AdminConfigEntry> setConfig({
    required String key,
    required dynamic value,
  });
}
