import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../application/session_controller.dart';

/// Thông báo rõ quyền thành viên đã bị thu hồi, kèm thao tác kiểm tra lại/đăng xuất.
class MembershipRevokedScreen extends StatefulWidget {
  const MembershipRevokedScreen({super.key});

  @override
  State<MembershipRevokedScreen> createState() =>
      _MembershipRevokedScreenState();
}

class _MembershipRevokedScreenState extends State<MembershipRevokedScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = context.read<SessionController>();
    final failure = await session.refreshAfterSignIn();
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) {
      setState(() => _error = failure.userMessage);
      return;
    }
    final route = AppRoutes.routeFor(session.state);
    if (route != null && route != AppRoutes.membershipRevoked) {
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final failure = await context.read<SessionController>().signOut();
    if (!mounted) return;
    setState(() => _loading = false);
    if (failure != null) {
      setState(() => _error = failure.userMessage);
      return;
    }
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    final contact = state is SessionMembershipRevoked
        ? state.user.contact
        : 'tài khoản này';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.storefront_outlined,
                      size: 48, color: AppColors.statusAttention),
                  const SizedBox(height: 16),
                  Text('Quyền vào quán đã thay đổi',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.screenTitle),
                  const SizedBox(height: 8),
                  Text(
                    'Tài khoản $contact hiện không còn là thành viên của quán đã mở gần nhất. '
                    'Nếu chủ quán vừa mời bạn vào quán khác, hãy kiểm tra hộp thư lời mời.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.statusOff)),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _loading ? null : _refresh,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(_loading ? 'Đang kiểm tra' : 'Kiểm tra lại'),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading ? null : _signOut,
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
