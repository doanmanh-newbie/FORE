import '../config/app_version.dart';

/// App nên làm gì với cấu hình từ xa hiện tại.
enum RemoteConfigVerdict {
  /// Vào app bình thường.
  ok,

  /// Đang bảo trì: chặn toàn bộ app.
  maintenance,

  /// Phiên bản thấp hơn `min_version` và `force_update` bật: chặn, bắt cập nhật.
  updateRequired,

  /// Phiên bản thấp hơn `min_version` nhưng `force_update` tắt: nhắc, cho bỏ qua.
  updateSuggested,
}

/// Cấu hình từ xa đọc từ `get_app_config()` (bảng `app_config`, sửa qua admin web).
///
/// Khóa dùng:
/// - `maintenance_mode` (bool), `maintenance_message` (chuỗi)
/// - `min_version` (chuỗi `1.2.0`), `force_update` (bool, mặc định `true`)
///
/// Thiếu khóa hoặc sai kiểu thì dùng giá trị an toàn: KHÔNG chặn người dùng.
class RemoteAppConfig {
  const RemoteAppConfig({
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.minVersion,
    this.forceUpdate = true,
  });

  /// Bảng trống, chưa tải được hoặc lỗi mạng: vào app bình thường.
  static const fallback = RemoteAppConfig();

  factory RemoteAppConfig.fromJson(Map<String, dynamic> json) {
    String? text(String key) {
      final v = json[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    return RemoteAppConfig(
      maintenanceMode: json['maintenance_mode'] == true,
      maintenanceMessage: text('maintenance_message'),
      minVersion: text('min_version'),
      forceUpdate:
          json['force_update'] is bool ? json['force_update'] as bool : true,
    );
  }

  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? minVersion;
  final bool forceUpdate;

  /// Bảo trì được ưu tiên trước kiểm tra phiên bản.
  /// Phiên bản không đọc được (ví dụ `dev`) thì không chặn.
  RemoteConfigVerdict verdictFor(String currentVersion) {
    if (maintenanceMode) return RemoteConfigVerdict.maintenance;
    final min = minVersion;
    if (min == null) return RemoteConfigVerdict.ok;
    final cmp = compareVersions(currentVersion, min);
    if (cmp == null || cmp >= 0) return RemoteConfigVerdict.ok;
    return forceUpdate
        ? RemoteConfigVerdict.updateRequired
        : RemoteConfigVerdict.updateSuggested;
  }
}
