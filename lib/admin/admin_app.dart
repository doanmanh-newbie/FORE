import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/data/rpc_client.dart';
import '../core/design/colors.dart';
import '../core/design/palette_sync.dart';
import '../core/theme/theme_mode_toggle.dart';
import 'admin_theme.dart';
import 'data/fake_admin_repositories.dart';
import 'data/supabase_admin_auth_repository.dart';
import 'data/supabase_admin_repositories.dart';
import 'domain/admin_models.dart';
import 'domain/admin_repositories.dart';
import 'presentation/admin_login_screen.dart';
import 'presentation/admin_shell.dart';

/// Gom các repository của Admin Web để dễ truyền bản Supabase hoặc bản Fake.
class AdminDependencies {
  const AdminDependencies({
    required this.authRepository,
    required this.shopsRepository,
    required this.usersRepository,
    required this.errorsRepository,
    required this.eventsRepository,
    required this.loginsRepository,
    required this.configRepository,
    this.isDemoMode = false,
  });

  factory AdminDependencies.supabase(SupabaseClient client) {
    final rpc = SupabaseRpcClient(client);
    return AdminDependencies(
      authRepository: SupabaseAdminAuthRepository(client, rpc),
      shopsRepository: SupabaseAdminShopsRepository(rpc),
      usersRepository: SupabaseAdminUsersRepository(rpc),
      errorsRepository: SupabaseAdminErrorsRepository(rpc),
      eventsRepository: SupabaseAdminEventsRepository(rpc),
      loginsRepository: SupabaseAdminLoginsRepository(rpc),
      configRepository: SupabaseAdminConfigRepository(rpc, client),
    );
  }

  factory AdminDependencies.fake({AdminIdentity? initialSession}) =>
      AdminDependencies(
        authRepository: FakeAdminAuthRepository(initialSession: initialSession),
        shopsRepository: FakeAdminShopsRepository(),
        usersRepository: FakeAdminUsersRepository(),
        errorsRepository: FakeAdminErrorsRepository(),
        eventsRepository: FakeAdminEventsRepository(),
        loginsRepository: FakeAdminLoginsRepository(),
        configRepository: FakeAdminConfigRepository(),
        isDemoMode: true,
      );

  final AdminAuthRepository authRepository;
  final AdminShopsRepository shopsRepository;
  final AdminUsersRepository usersRepository;
  final AdminErrorsRepository errorsRepository;
  final AdminEventsRepository eventsRepository;
  final AdminLoginsRepository loginsRepository;
  final AdminConfigRepository configRepository;
  final bool isDemoMode;
}

/// Ứng dụng gốc của Fore Admin Web.
class ForeAdminApp extends StatelessWidget {
  const ForeAdminApp({
    super.key,
    required this.dependencies,
  });

  final AdminDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeModeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'Fore Admin',
        debugShowCheckedModeBanner: false,
        theme: AdminTheme.light(),
        darkTheme: AdminTheme.dark(),
        themeMode: mode,
        builder: (context, child) => AppPaletteSync(child: child!),
        home: _AdminGate(dependencies: dependencies),
      ),
    );
  }
}

class _AdminGate extends StatefulWidget {
  const _AdminGate({required this.dependencies});

  final AdminDependencies dependencies;

  @override
  State<_AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<_AdminGate> {
  bool _checking = true;
  AdminIdentity? _identity;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final session = await widget.dependencies.authRepository.restoreSession();
      if (!mounted) return;
      setState(() {
        _identity = session;
        _checking = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _identity = null;
        _checking = false;
      });
    }
  }

  Future<void> _signOut() async {
    await widget.dependencies.authRepository.signOut();
    if (!mounted) return;
    setState(() => _identity = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang kiểm tra phiên quản trị...'),
            ],
          ),
        ),
      );
    }

    final identity = _identity;
    if (identity == null) {
      return AdminLoginScreen(
        authRepository: widget.dependencies.authRepository,
        onSignedIn: (signedIn) => setState(() => _identity = signedIn),
      );
    }

    return AdminShell(
      identity: identity,
      dependencies: widget.dependencies,
      onSignOut: _signOut,
      isDemoMode: widget.dependencies.isDemoMode,
    );
  }
}
