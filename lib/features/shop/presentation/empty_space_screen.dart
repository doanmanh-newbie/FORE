import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/design/spacing.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/adaptive_nav.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/ops_icon.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../shift/application/shift_controller.dart';
import '../application/inbox_controller.dart';
import 'invite_list.dart';
import 'join_by_code_card.dart';

/// Giao diện nhân viên khi CHƯA thuộc quán nào. Vào thẳng app (không chờ ở màn ngoài):
///   Trang chủ: vào quán bằng mã, hoặc gửi số của mình để chủ quán mời.
///   Hộp thư: thông báo lời mời từ chủ quán (tự làm mới, có số đếm trên thanh điều hướng).
///   Thêm: tài khoản, đăng xuất, tạo quán (nếu thật ra là chủ quán).
/// Vào được quán (bằng mã hoặc nhận lời mời) thì chuyển sang giao diện làm việc của quán.
class EmptySpaceScreen extends StatefulWidget {
  const EmptySpaceScreen({super.key});

  @override
  State<EmptySpaceScreen> createState() => _EmptySpaceScreenState();
}

class _EmptySpaceScreenState extends State<EmptySpaceScreen> {
  int _tab = 0;

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    final shift = context.read<ShiftController>();
    final failure = await context.read<SessionController>().signOut();
    if (failure != null) {
      if (mounted) showNotice(context, failure.userMessage);
      return;
    }
    shift.reset();
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    final user = state is SessionAwaitingInvite ? state.user : null;
    final maybeOwner = state is SessionAwaitingInvite &&
        state.context.accountKind == AccountKind.unknown;
    final inviteCount = context.watch<InboxController>().invites.length;

    Widget icon(Widget child, {int badge = 0}) =>
        badge == 0 ? child : Badge(label: Text('$badge'), child: child);

    return AdaptiveNavScaffold(
      selected: _tab,
      onSelect: (i) => setState(() => _tab = i),
      items: [
        AdaptiveNavItem(
          label: 'Trang chủ',
          icon: ForeIcon(ForeIcons.home, size: 22, color: AppColors.brand),
        ),
        AdaptiveNavItem(
          label: 'Hộp thư',
          icon: icon(Icon(Icons.mail_outline_rounded, color: AppColors.brand),
              badge: inviteCount),
        ),
        AdaptiveNavItem(
          label: 'Thêm',
          icon: Icon(Icons.more_horiz_rounded, color: AppColors.brand),
        ),
      ],
      body: switch (_tab) {
        0 => _HomeTab(
            name: user?.displayName ?? '',
            contact: user?.contact ?? '',
            inviteCount: inviteCount,
            onOpenInbox: () => setState(() => _tab = 1),
          ),
        1 => const _InboxTab(),
        _ => _MoreTab(
            name: user?.displayName ?? '',
            contact: user?.contact ?? '',
            maybeOwner: maybeOwner,
            onSignOut: _signOut,
          ),
      },
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({
    required this.name,
    required this.contact,
    required this.inviteCount,
    required this.onOpenInbox,
  });

  final String name;
  final String contact;
  final int inviteCount;
  final VoidCallback onOpenInbox;

  @override
  Widget build(BuildContext context) => PageScaffold(
        children: [
          Text(name.isEmpty ? 'Chào bạn!' : 'Chào $name!',
              style: AppTextStyles.display),
          const SizedBox(height: 6),
          Text('Bạn chưa thuộc quán nào. Vào quán bằng một trong hai cách:',
              style: AppTextStyles.body),
          const SizedBox(height: AppGaps.lg),
          const JoinByCodeCard(),
          const SizedBox(height: AppGaps.md),
          ForeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Hoặc nhờ chủ quán mời', style: AppTextStyles.title),
                const SizedBox(height: 4),
                Text(
                  'Gửi số/email này cho chủ quán. Lời mời sẽ hiện trong Hộp thư.',
                  style: AppTextStyles.caption,
                ),
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: AppGaps.md),
                  Row(
                    children: [
                      Expanded(
                        child: SelectableText(contact,
                            style: AppTextStyles.headline),
                      ),
                      IconButton(
                        tooltip: 'Sao chép',
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: contact));
                          if (context.mounted) {
                            showNotice(context, 'Đã sao chép $contact');
                          }
                        },
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppGaps.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenInbox,
                    icon: const Icon(Icons.mail_outline_rounded),
                    label: Text(inviteCount == 0
                        ? 'Mở hộp thư'
                        : 'Mở hộp thư ($inviteCount lời mời)'),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}

class _InboxTab extends StatelessWidget {
  const _InboxTab();

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text('Hộp thư', style: AppTextStyles.display),
            ),
            const Expanded(
              child: InviteListView(
                emptyText:
                    'Chưa có thông báo nào.\nKhi chủ quán mời bạn, lời mời hiện ở đây.',
              ),
            ),
          ],
        ),
      );
}

class _MoreTab extends StatelessWidget {
  const _MoreTab({
    required this.name,
    required this.contact,
    required this.maybeOwner,
    required this.onSignOut,
  });

  final String name;
  final String contact;
  final bool maybeOwner;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) => PageScaffold(
        children: [
          Text('Thêm', style: AppTextStyles.display),
          const SizedBox(height: AppGaps.lg),
          ForeCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name.isEmpty ? 'Tài khoản' : name,
                    style: AppTextStyles.title),
                if (contact.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text('Nhân viên · $contact', style: AppTextStyles.caption),
                ],
                const SizedBox(height: AppGaps.md),
                OutlinedButton(
                    onPressed: onSignOut, child: const Text('Đăng xuất')),
              ],
            ),
          ),
          if (maybeOwner) ...[
            const SizedBox(height: AppGaps.md),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.createShop),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Tôi là chủ quán — tạo quán của tôi'),
            ),
          ],
        ],
      );
}
