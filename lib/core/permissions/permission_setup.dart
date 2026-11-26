import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firebase_services.dart';
import '../push/push_registration_controller.dart';
import 'app_permissions.dart';
import 'permission_primer.dart';

/// Cổng quyền của app: lấy từ Provider (test thay bằng [MemoryPermissionGateway]),
/// không có thì dùng quyền thật của máy.
PermissionGateway permissionGatewayOf(BuildContext context) =>
    context.read<PermissionGateway?>() ?? const DevicePermissionGateway();

/// Xin một quyền tại chỗ: màn giải thích của app trước, rồi hộp thoại hệ thống.
/// Thông báo đi qua Firebase Messaging để vừa xin quyền vừa đăng ký máy nhận push.
Future<PermissionAccess?> askPermission(
  BuildContext context,
  AppPermission permission, {
  int? step,
  int? total,
}) {
  final gateway = permissionGatewayOf(context);
  final push = context.read<PushRegistrationController?>();
  final firebase = context.read<FirebaseServices?>();
  Future<PermissionAccess> Function()? onAllow;
  if (permission == AppPermission.notification && push != null) {
    onAllow = () async {
      final enabled = await push.enable();
      if (!enabled) return gateway.request(permission);
      return gateway.status(permission);
    };
  }
  return showPermissionPrimer(
    context,
    permission: permission,
    gateway: gateway,
    onAllow: onAllow,
    step: step,
    total: total,
  ).then((result) {
    firebase?.logEvent('permission_prompt', {
      'permission': permission.name,
      'result': result?.name ?? 'later',
    });
    return result;
  });
}

/// Đảm bảo có quyền trước một thao tác (vd mở camera). Trả `true` nếu được dùng.
Future<bool> ensurePermission(
    BuildContext context, AppPermission permission) async {
  final result = await askPermission(context, permission);
  // Nền tảng không có khái niệm quyền này (web/desktop): để thao tác tự xử lý.
  return result == PermissionAccess.granted ||
      result == PermissionAccess.unsupported;
}

/// Chuỗi xin quyền lần đầu của chủ quán (thông báo → camera → vị trí), mỗi quyền bỏ qua được,
/// chỉ chạy một lần trên mỗi máy. Quyền đã có hoặc nền tảng không hỗ trợ thì không hỏi.
class PermissionOnboarding {
  static const _key = 'permissions.onboarding.v1';
  static const order = [
    AppPermission.notification,
    AppPermission.camera,
    AppPermission.location,
  ];

  static bool _running = false;

  static Future<void> runOnce(BuildContext context) async {
    // Chỉ chạy trong app thật (ForeApp luôn cung cấp cổng quyền); test dựng màn lẻ thì bỏ qua.
    if (_running || context.read<PermissionGateway?>() == null) return;
    _running = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_key) ?? false) return;
      if (!context.mounted) return;
      final gateway = permissionGatewayOf(context);
      final pending = <AppPermission>[];
      for (final p in order) {
        final s = await gateway.status(p);
        if (!s.isGranted && s != PermissionAccess.unsupported) pending.add(p);
      }
      await prefs.setBool(_key, true);
      for (var i = 0; i < pending.length; i++) {
        if (!context.mounted) return;
        await askPermission(context, pending[i],
            step: i + 1, total: pending.length);
      }
    } catch (e) {
      // Chuỗi xin quyền không bao giờ được làm hỏng trang chủ.
      debugPrint('Fore: bỏ qua chuỗi xin quyền: $e');
    } finally {
      _running = false;
    }
  }
}
