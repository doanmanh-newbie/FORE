import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/pulse_dot.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../shift/application/shift_controller.dart';
import 'invite_list.dart';

/// Không gian nhân viên khi CHƯA thuộc quán nào: không có dữ liệu, chỉ có hộp thư.
/// Khi chủ quán thêm số điện thoại/email của mình, lời mời hiện ở đây (tự làm mới 15 giây/lần);
/// chấp nhận thì tải dữ liệu quán và vào Trang chủ.
class EmptySpaceScreen extends StatelessWidget {
  const EmptySpaceScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final shift = context.read<ShiftController>();
    final failure = await context.read<SessionController>().signOut();
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    shift.reset();
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    final contact = state is SessionAwaitingInvite ? state.user.contact : '';
    final name = state is SessionAwaitingInvite ? state.user.displayName : '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InviteListView(
                emptyText: 'Chưa có lời mời nào.',
                header: _Hero(name: name, contact: contact),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                children: [
                  if (state is SessionAwaitingInvite &&
                      state.context.accountKind == AccountKind.unknown)
                    OutlinedButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed(AppRoutes.createShop),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('Tôi là chủ quán — tạo quán của tôi'),
                    ),
                  TextButton(
                    onPressed: () => _signOut(context),
                    child: const Text('Đăng xuất'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.name, required this.contact});

  final String name;
  final String contact;

  @override
  Widget build(BuildContext context) {
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          children: [
            const SizedBox(height: 12),
            const _BreathingMail(),
            const SizedBox(height: 20),
            Text(
              name.isEmpty ? 'Chào bạn!' : 'Chào $name!',
              textAlign: TextAlign.center,
              style: AppTextStyles.screenTitle,
            ),
            const SizedBox(height: 8),
            Text(
              'Bạn chưa thuộc quán nào, nên chưa có dữ liệu.\n'
              'Nhờ chủ quán thêm ${contact.isEmpty ? 'tài khoản này' : contact} '
              'vào quán. Lời mời sẽ hiện ngay ở đây, bạn chấp nhận là vào quán.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PulseDot(color: AppColors.brandAccent, pulsing: true),
                const SizedBox(width: 8),
                Text('Đang chờ lời mời', style: AppTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Biểu tượng thư nhấp nhô nhẹ. Tắt hoạt ảnh thì đứng yên.
class _BreathingMail extends StatefulWidget {
  const _BreathingMail();

  @override
  State<_BreathingMail> createState() => _BreathingMailState();
}

class _BreathingMailState extends State<_BreathingMail>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, -6 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: DecoratedBox(
        decoration:
            BoxDecoration(color: AppColors.tint, shape: BoxShape.circle),
        child: SizedBox.square(
          dimension: 104,
          child: Icon(Icons.mark_email_unread_outlined,
              size: 48, color: AppColors.brand),
        ),
      ),
    );
  }
}
