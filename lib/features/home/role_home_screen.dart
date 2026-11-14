import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../auth/domain/auth_models.dart';
import '../auth/application/session_controller.dart';
import '../home/home_screen.dart';
import '../owner/presentation/owner_home_screen.dart';

/// Chọn giao diện theo vai trò thật trong hồ sơ quán; không dựa vào lựa chọn ở màn đăng nhập.
///
/// Chưa thuộc quán nào thì không có gì để hiện ở đây: chuyển sang màn chờ lời mời
/// (nhân viên) hoặc màn tạo quán (chủ). Trước đây nhánh này mở nhầm giao diện nhân viên
/// với dữ liệu trống và báo "Cần đăng nhập lại".
class RoleHomeScreen extends StatefulWidget {
  const RoleHomeScreen({super.key, this.staffHomeBuilder});

  /// Lets widget tests verify role routing without opening Supabase screens.
  final WidgetBuilder? staffHomeBuilder;

  static bool isOwnerRole(StaffRole role) => role == StaffRole.owner;

  @override
  State<RoleHomeScreen> createState() => _RoleHomeScreenState();
}

class _RoleHomeScreenState extends State<RoleHomeScreen> {
  @override
  void initState() {
    super.initState();
    // Flutter web may open /#/home directly and skip SplashScreen. Never leave
    // that deep link in SessionChecking forever.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = context.read<SessionController>();
      if (session.state is SessionChecking) {
        session.restore(skipMinWait: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final state = session.state;
    if (state is SessionSignedOut ||
        state is SessionNeedsShop ||
        state is SessionAwaitingInvite ||
        state is SessionMembershipRevoked) {
      final route = AppRoutes.routeFor(state);
      if (route != null) return _RedirectTo(route: route);
    }
    if (state is! SessionSignedIn) {
      if (state is SessionOffline || state is SessionFailed) {
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 42),
                    const SizedBox(height: 12),
                    Text(state is SessionFailed
                        ? 'Chưa tải được thông tin tài khoản'
                        : 'Chưa kết nối được với Fore'),
                    const SizedBox(height: 8),
                    Text(state is SessionFailed
                        ? 'Bạn vẫn đang đăng nhập. Hãy thử tải lại.'
                        : 'Kiểm tra mạng rồi thử tải lại.'),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => context
                          .read<SessionController>()
                          .restore(skipMinWait: true),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }
      return Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (RoleHomeScreen.isOwnerRole(state.profile.role)) {
      return OwnerHomeScreen(profile: state.profile);
    }
    return widget.staffHomeBuilder?.call(context) ?? const OpsHomeScreen();
  }
}

/// Màn trống chỉ để chuyển trang ngay sau khung hình đầu.
class _RedirectTo extends StatefulWidget {
  const _RedirectTo({required this.route});

  final String route;

  @override
  State<_RedirectTo> createState() => _RedirectToState();
}

class _RedirectToState extends State<_RedirectTo> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(widget.route, (_) => false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: const Center(child: CircularProgressIndicator()),
      );
}
