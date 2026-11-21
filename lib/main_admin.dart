import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'admin/admin_app.dart';
import 'admin/admin_theme.dart';
import 'core/config/app_config.dart';
import 'core/design/colors.dart';
import 'core/design/palette_sync.dart';
import 'core/design/typography.dart';
import 'core/theme/theme_mode_toggle.dart';

/// Điểm khởi chạy của Fore Admin Web.
///
/// Chạy cục bộ với dữ liệu Supabase thật:
/// `flutter run -d chrome -t lib/main_admin.dart --dart-define-from-file=env.json`
///
/// Hoặc xem nhanh giao diện bằng dữ liệu giả (không cần Supabase):
/// `flutter run -d chrome -t lib/main_admin.dart --dart-define=ADMIN_USE_FAKE=true`
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadThemeMode();
  if (themeModeNotifier.value == ThemeMode.system) {
    themeModeNotifier.value = ThemeMode.light;
  }

  const useFake = bool.fromEnvironment('ADMIN_USE_FAKE', defaultValue: false);
  if (useFake) {
    runApp(ForeAdminApp(dependencies: AdminDependencies.fake()));
    return;
  }

  final config = AppConfig.fromEnvironment();
  if (!config.isComplete) {
    const message =
        'Chưa nạp cấu hình Supabase. Hãy chạy bằng:\n'
        'flutter run -d chrome -t lib/main_admin.dart --dart-define-from-file=env.json';
    debugPrint(message);
    runApp(const _AdminStartupErrorApp(message: message));
    return;
  }

  try {
    await Supabase.initialize(
      url: config.supabaseUrl,
      publishableKey: config.supabaseAnonKey,
    );
  } catch (error, stackTrace) {
    debugPrint('Fore Admin startup failed: $error\n$stackTrace');
    runApp(
      const _AdminStartupErrorApp(
        message:
            'Không thể khởi tạo Supabase. Hãy kiểm tra SUPABASE_URL và SUPABASE_ANON_KEY trong env.json rồi tải lại trang.',
      ),
    );
    return;
  }

  runApp(
    ForeAdminApp(
      dependencies: AdminDependencies.supabase(Supabase.instance.client),
    ),
  );
}

class _AdminStartupErrorApp extends StatelessWidget {
  const _AdminStartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fore Admin',
      debugShowCheckedModeBanner: false,
      theme: AdminTheme.light(),
      darkTheme: AdminTheme.dark(),
      themeMode: ThemeMode.light,
      builder: (context, child) => AppPaletteSync(child: child!),
      home: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 48,
                      color: AppColors.brand,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Fore Admin chưa thể khởi động',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headline,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      message,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
