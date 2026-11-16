import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
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
  final client = Supabase.instance.client;
  runApp(ForeApp(
    authRepository: SupabaseAuthRepository(client),
    shiftRepository: SupabaseShiftRepository(client),
    shopRepository: SupabaseShopRepository(client),
  ));
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
