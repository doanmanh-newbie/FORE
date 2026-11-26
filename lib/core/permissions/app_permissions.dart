import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Các quyền Fore có thể dùng. Mỗi quyền gắn với một chức năng thật (xem [purpose]).
enum AppPermission {
  notification,
  camera,
  photos,
  location;

  String get title => switch (this) {
        AppPermission.notification => 'Thông báo',
        AppPermission.camera => 'Camera',
        AppPermission.photos => 'Thư viện ảnh',
        AppPermission.location => 'Vị trí',
      };

  /// Một câu nói rõ app dùng quyền để làm gì (hiện ở màn giải thích và danh sách quyền).
  String get purpose => switch (this) {
        AppPermission.notification =>
          'Nhận báo ngay khi có ca lệch, lời mời nhân viên và nhắc đối soát.',
        AppPermission.camera => 'Chụp ảnh món để thực đơn rõ ràng, dễ chọn.',
        AppPermission.photos => 'Chọn ảnh món có sẵn trong máy cho thực đơn.',
        AppPermission.location =>
          'Lấy tọa độ quán để điền nhanh vào địa chỉ ở Hồ sơ quán. Chỉ khi đang dùng app.',
      };

  IconData get icon => switch (this) {
        AppPermission.notification => Icons.notifications_active_rounded,
        AppPermission.camera => Icons.photo_camera_rounded,
        AppPermission.photos => Icons.photo_library_rounded,
        AppPermission.location => Icons.location_on_rounded,
      };

  /// Nhãn nút đồng ý ở màn giải thích.
  String get allowLabel => switch (this) {
        AppPermission.notification => 'Bật thông báo',
        AppPermission.location => 'Cho phép',
        _ => 'Cho phép truy cập',
      };

  ph.Permission get _native => switch (this) {
        AppPermission.notification => ph.Permission.notification,
        AppPermission.camera => ph.Permission.camera,
        AppPermission.photos => ph.Permission.photos,
        AppPermission.location => ph.Permission.locationWhenInUse,
      };
}

/// Trạng thái một quyền, đã gộp về những gì giao diện cần phân biệt.
enum PermissionAccess {
  /// Đã cho phép (kể cả "chỉ ảnh đã chọn" / tạm thời).
  granted,

  /// Chưa hỏi hoặc vừa từ chối: hỏi lại được.
  denied,

  /// Từ chối hẳn: chỉ đổi được trong Cài đặt của máy.
  blocked,

  /// Nền tảng không có quyền này (vd thư viện ảnh trên web).
  unsupported;

  bool get isGranted => this == PermissionAccess.granted;
}

/// Đọc/xin quyền. Tách interface để test dùng bản giả.
abstract interface class PermissionGateway {
  Future<PermissionAccess> status(AppPermission permission);
  Future<PermissionAccess> request(AppPermission permission);

  /// Mở trang cài đặt của app trong máy (khi quyền đã bị chặn).
  Future<bool> openSettings();
}

/// Quyền thật qua `permission_handler`. Lỗi nền tảng được quy về [PermissionAccess.unsupported].
class DevicePermissionGateway implements PermissionGateway {
  const DevicePermissionGateway();

  bool _supported(AppPermission p) {
    // Web: trình duyệt không có quyền thư viện ảnh (input file tự hỏi).
    if (kIsWeb && p == AppPermission.photos) return false;
    if (!kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    return true;
  }

  PermissionAccess _map(ph.PermissionStatus s) => switch (s) {
        ph.PermissionStatus.granted ||
        ph.PermissionStatus.limited ||
        ph.PermissionStatus.provisional =>
          PermissionAccess.granted,
        ph.PermissionStatus.permanentlyDenied ||
        ph.PermissionStatus.restricted =>
          PermissionAccess.blocked,
        ph.PermissionStatus.denied => PermissionAccess.denied,
      };

  @override
  Future<PermissionAccess> status(AppPermission permission) async {
    if (!_supported(permission)) return PermissionAccess.unsupported;
    try {
      return _map(await permission._native.status);
    } catch (e) {
      debugPrint('Fore: không đọc được quyền ${permission.name}: $e');
      return PermissionAccess.unsupported;
    }
  }

  @override
  Future<PermissionAccess> request(AppPermission permission) async {
    if (!_supported(permission)) return PermissionAccess.unsupported;
    try {
      return _map(await permission._native.request());
    } catch (e) {
      debugPrint('Fore: không xin được quyền ${permission.name}: $e');
      return PermissionAccess.unsupported;
    }
  }

  @override
  Future<bool> openSettings() async {
    try {
      return await ph.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}

/// Quyền trong bộ nhớ: dùng cho test và bản xem trước giao diện.
class MemoryPermissionGateway implements PermissionGateway {
  MemoryPermissionGateway([Map<AppPermission, PermissionAccess>? initial])
      : states = {...?initial};

  final Map<AppPermission, PermissionAccess> states;

  /// Kết quả khi [request] (mặc định: cho phép).
  PermissionAccess onRequest = PermissionAccess.granted;
  int settingsOpened = 0;

  @override
  Future<PermissionAccess> status(AppPermission p) async =>
      states[p] ?? PermissionAccess.denied;

  @override
  Future<PermissionAccess> request(AppPermission p) async {
    final current = states[p] ?? PermissionAccess.denied;
    if (current == PermissionAccess.blocked ||
        current == PermissionAccess.unsupported) {
      return current;
    }
    return states[p] = onRequest;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
