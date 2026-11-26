import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_version.dart';
import 'core/data/rpc_client.dart';
import 'core/firebase/firebase_services.dart';
import 'core/permissions/app_permissions.dart';
import 'core/push/push_notification_service.dart';
import 'core/push/push_registration_controller.dart';
import 'core/realtime/live_feed.dart';
import 'core/remote_config/app_config_repository.dart';
import 'core/telemetry/error_reporter.dart';
import 'core/telemetry/telemetry_repository.dart';
import 'core/theme/theme_mode_toggle.dart';
import 'core/config/app_config.dart';
import 'features/auth/data/supabase_auth_repository.dart';
import 'features/shift/data/supabase_shift_repository.dart';
import 'features/shop/data/supabase_shop_repository.dart';
import 'package:fore/core/design/typography.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  if (!config.isComplete) {
    const message =
        'Chưa nạp cấu hình Supabase. Hãy chạy app với --dart-define-from-file=env.json.';
    debugPrint(message);
    runApp(const StartupErrorApp(message: message));
    return;
  }
  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  } catch (error, stackTrace) {
    debugPrint('Fore startup failed: $error\n$stackTrace');
    runApp(const StartupErrorApp(
      message:
          'Không thể khởi tạo Supabase. Hãy kiểm tra SUPABASE_URL và SUPABASE_ANON_KEY trong env.json, sau đó khởi động lại app.',
    ));
    return;
  }

  await loadThemeMode();
  // Firebase (Analytics, Crashlytics; push dùng chung app Firebase). Lỗi / chậm không chặn app.
  final firebase = DeviceFirebaseServices();
  await firebase.init().timeout(const Duration(seconds: 6), onTimeout: () {});
  final client = Supabase.instance.client;
  final rpc = SupabaseRpcClient(client);
  final telemetry = RpcTelemetryRepository(rpc);
  _installErrorReporting(telemetry, client, firebase);
  const permissions = DevicePermissionGateway();
  runApp(ForeApp(
    authRepository: SupabaseAuthRepository(client),
    shiftRepository: SupabaseShiftRepository(client),
    shopRepository: SupabaseShopRepository(client),
    telemetryRepository: telemetry,
    appConfigRepository: RpcAppConfigRepository(rpc),
    liveFeed: SupabaseLiveFeed(client),
    // Firebase lỗi / chưa cấu hình (thiếu google-services.json) thì push tự tắt, app vẫn chạy.
    // Không tự bật hộp thoại quyền khi đăng nhập: chủ quán bấm "Bật thông báo" ở màn giải thích.
    pushController: PushRegistrationController(
      FirebasePushNotificationService(),
      RpcPushTokenRepository(rpc),
      isPermissionGranted: () async =>
          (await permissions.status(AppPermission.notification)).isGranted,
    ),
    firebaseServices: firebase,
    permissionGateway: permissions,
  ));
}

/// Gửi mọi lỗi chưa bắt lên `log_error` (chỉ khi đã đăng nhập, xem [ErrorReporter]).
void _installErrorReporting(TelemetryRepository telemetry,
    SupabaseClient client, FirebaseServices firebase) {
  final reporter = ErrorReporter(
    telemetry: telemetry,
    appVersion: appVersion,
    platform: currentPlatformName(),
    isLoggedIn: () => client.auth.currentSession != null,
  );
  // Ghi lỗi lên cả server (log_error) và Firebase Crashlytics.
  FlutterError.onError = (details) {
    reporter.handleFlutterError(details);
    firebase.recordError(details.exception, details.stack,
        reason: details.context?.toDescription());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    firebase.recordError(error, stack, fatal: true);
    return reporter.handlePlatformError(error, stack);
  };
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Fore chưa thể khởi động',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppFontSizes.s22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(message, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
