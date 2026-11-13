import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_theme.dart';
import '../core/design/palette_sync.dart';
import '../core/data/rpc_client.dart';
import '../features/auth/application/session_controller.dart';
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
class ForeApp extends StatelessWidget {
  const ForeApp({
    super.key,
    required this.authRepository,
    required this.shiftRepository,
    required this.shopRepository,
  });

  final AuthRepository authRepository;
  final ShiftRepository shiftRepository;
  final ShopRepository shopRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthRepository>.value(value: authRepository),
        ChangeNotifierProvider<SessionController>(
          create: (_) => SessionController(
            authRepository,
            minVisible: SplashScreen.introDuration,
          ),
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
          create: (_) => ShiftController(shiftRepository),
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
      child: MaterialApp(
        title: 'Fore',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        builder: (context, child) => AppPaletteSync(child: child!),
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generate,
      ),
    );
  }
}
