import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/theme_mode_toggle.dart';
import '../core/design/palette_sync.dart';
import '../core/data/rpc_client.dart';
import '../core/config/app_version.dart' as version;
import '../core/firebase/firebase_services.dart';
import '../core/permissions/app_permissions.dart';
import '../core/push/push_message_listener.dart';
import '../core/push/push_registration_controller.dart';
import '../core/realtime/live_feed.dart';
import '../core/remote_config/app_config_repository.dart';
import '../core/remote_config/remote_config_controller.dart';
import '../core/remote_config/remote_config_gate.dart';
import '../core/telemetry/telemetry_repository.dart';
import '../features/auth/presentation/password_recovery_listener.dart';
import '../features/auth/application/session_controller.dart';
import '../features/auth/domain/auth_models.dart';
import '../features/auth/domain/auth_repository.dart';
import '../features/auth/presentation/splash_screen.dart';
import '../features/inventory/data/rpc_inventory_repository.dart';
import '../features/inventory/data/rpc_kho_repository.dart';
import '../features/inventory/domain/kho_repository.dart';
import '../features/settings/data/rpc_settings_repository.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/inventory/domain/inventory_repository.dart';
import '../features/owner/data/owner_dashboard_repository.dart';
import '../features/owner/menu/menu_image_service.dart';
import '../features/owner/menu/menu_repository.dart';
import '../features/shift/application/shift_controller.dart';
import '../features/shift/domain/shift_repository.dart';
import '../features/shop/domain/shop_repository.dart';
import 'app_routes.dart';

/// Gốc của app. Nhận các repository từ ngoài vào (dependency injection):
/// `main.dart` truyền bản Supabase, test truyền bản giả.
/// Navigator gốc: để các listener đặt phía trên Navigator (vd link đặt lại mật khẩu) mở được hộp thoại.
final appNavigatorKey = GlobalKey<NavigatorState>();

class ForeApp extends StatelessWidget {
  const ForeApp({
    super.key,
    required this.authRepository,
    required this.shiftRepository,
    required this.shopRepository,
    this.telemetryRepository = const NoopTelemetryRepository(),
    this.appConfigRepository = const StaticAppConfigRepository(),
    this.appVersion = version.appVersion,
    this.liveFeed,
    this.pushController,
    this.firebaseServices,
    this.permissionGateway = const DevicePermissionGateway(),
  });

  final AuthRepository authRepository;
  final ShiftRepository shiftRepository;
  final ShopRepository shopRepository;

  /// Ghi lỗi/sự kiện/đăng nhập (`09_admin.sql`). Test không truyền thì không ghi gì.
  final TelemetryRepository telemetryRepository;

  /// Cấu hình từ xa (`get_app_config`): bảo trì, phiên bản tối thiểu.
  /// Test không truyền thì không chặn gì.
  final AppConfigRepository appConfigRepository;

  /// Phiên bản đang chạy, so với `min_version`.
  final String appVersion;

  /// Supabase Realtime cho ca và bill. `null` (test): màn chính tải lại theo giờ như cũ.
  final LiveFeed? liveFeed;

  /// Push FCM cho chủ quán. `null` (test): không đăng ký push.
  final PushRegistrationController? pushController;

  /// Firebase Analytics + Crashlytics. `null` (test): không ghi gì.
  final FirebaseServices? firebaseServices;

  /// Đọc/xin quyền của máy (test thay bằng bản trong bộ nhớ).
  final PermissionGateway permissionGateway;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        Provider<TelemetryRepository>.value(value: telemetryRepository),
        Provider<PermissionGateway>.value(value: permissionGateway),
        if (firebaseServices != null)
          ChangeNotifierProvider<FirebaseServices>.value(
              value: firebaseServices!),
        if (liveFeed != null) Provider<LiveFeed>.value(value: liveFeed!),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(
            authRepository,
            minVisible: SplashScreen.introDuration,
          ),
        ),
        ChangeNotifierProxyProvider<SessionController, RemoteConfigController>(
          create: (_) => RemoteConfigController(appConfigRepository,
              appVersion: appVersion),
          update: (_, session, remote) {
            // get_app_config cần đăng nhập: chỉ tải khi có tài khoản (kể cả phiên
            // khôi phục lúc mở app), đăng xuất thì bỏ chặn.
            final state = session.state;
            final userId = state is SessionSignedOut
                ? null
                : authRepository.currentUser?.id;
            scheduleMicrotask(() => remote!.bindUser(userId));
            return remote!;
          },
        ),
        // Phải nằm SAU ChangeNotifierProvider<SessionController>: provider proxy đọc phiên ở trên nó.
        if (pushController != null)
          ChangeNotifierProxyProvider<SessionController,
              PushRegistrationController>(
            create: (_) => pushController!,
            update: (_, session, push) {
              // Chỉ CHỦ của quán đang chọn mới cần push (Edge Function chỉ gửi cho chủ),
              // nên nhân viên không bị hỏi quyền thông báo. Đăng xuất -> hủy token.
              final state = session.state;
              final userId =
                  state is SessionReady && state.profile.role == StaffRole.owner
                      ? authRepository.currentUser?.id
                      : null;
              scheduleMicrotask(() => push!.bindUser(userId));
              return push!;
            },
          ),
        Provider<ShiftRepository>.value(value: shiftRepository),
        Provider<ShopRepository>.value(value: shopRepository),
        Provider<RpcClient>(
          create: (_) => SupabaseRpcClient(Supabase.instance.client),
        ),
        Provider<RpcInventoryRepository>(
          create: (context) =>
              RpcInventoryRepository(context.read<RpcClient>()),
        ),
        Provider<InventoryRepository>(
          create: (context) => context.read<RpcInventoryRepository>(),
        ),
        Provider<SettingsRepository>(
          create: (context) => RpcSettingsRepository(context.read<RpcClient>()),
        ),
        Provider<KhoRepository>(
          create: (context) => RpcKhoRepository(context.read<RpcClient>()),
        ),
        Provider<CashRepository>(
          create: (context) => context.read<RpcInventoryRepository>(),
        ),
        Provider<OwnerDashboardDataSource>(
          create: (_) => OwnerDashboardRepository(Supabase.instance.client),
        ),
        Provider<MenuRepository>(
          create: (context) => RpcMenuRepository(context.read<RpcClient>()),
        ),
        Provider<MenuImageService>(
          create: (_) => SupabaseMenuImageService(Supabase.instance.client),
        ),
        ChangeNotifierProxyProvider<SessionController, ShiftController>(
          create: (_) =>
              ShiftController(shiftRepository, telemetry: telemetryRepository),
          update: (_, session, shift) {
            final state = session.state;
            final scope = state is SessionReady
                ? '${state.profile.shopId}|${state.profile.staffId}'
                : null;
            // Đổi quán/tài khoản/đăng xuất: quên ca cũ (hoãn để không báo thay đổi lúc build).
            scheduleMicrotask(() => shift!.bindScope(scope));
            return shift!;
          },
        ),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, mode, _) => MaterialApp(
          title: 'Fore',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          navigatorKey: appNavigatorKey,
          builder: (context, child) => AppPaletteSync(
              child: RemoteConfigGate(
                  child: PasswordRecoveryListener(
                      navigatorKey: appNavigatorKey,
                      child: PushMessageListener(child: child!)))),
          navigatorObservers: firebaseServices?.navigatorObservers ?? const [],
          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.generate,
        ),
      ),
    );
  }
}
