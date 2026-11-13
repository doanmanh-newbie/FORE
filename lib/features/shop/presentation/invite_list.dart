import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/fore_button.dart';
import '../../../core/widgets/empty_state.dart' show ErrorRetry;
import '../../auth/application/session_controller.dart';
import '../../shift/application/shift_controller.dart';
import '../application/inbox_controller.dart';
import '../domain/shop_models.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// "5 phút trước", "hôm qua"...
String timeAgo(DateTime at, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return 'vừa xong';
  if (d.inMinutes < 60) return '${d.inMinutes} phút trước';
  if (d.inHours < 24) return '${d.inHours} giờ trước';
  if (d.inDays == 1) return 'hôm qua';
  return '${d.inDays} ngày trước';
}

/// Chấp nhận lời mời rồi vào quán: tải lại hồ sơ + ca của quán mới, chào mừng, sang Trang chủ.
Future<void> acceptAndEnter(BuildContext context, Invite invite) async {
  final inbox = context.read<InboxController>();
  final session = context.read<SessionController>();
  final shift = context.read<ShiftController>();
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  final error = await inbox.accept(invite);
  if (error != null) {
    messenger.showSnackBar(SnackBar(content: Text(error)));
    return;
  }
  final failure = await session.refreshAfterSignIn();
  if (failure != null) {
    messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
    return;
  }
  shift.load(); // tải ca của quán vừa vào (không chờ)
  HapticFeedback.mediumImpact();
  if (navigator.mounted) {
    await showGeneralDialog<void>(
      context: navigator.context,
      barrierDismissible: false,
      barrierColor: AppColors.shadowStrong,
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, __, ___) => _JoinedDialog(shopName: invite.shopName),
    );
  }
  final next = AppRoutes.routeFor(session.state);
  if (next != null) navigator.pushNamedAndRemoveUntil(next, (_) => false);
}

class _JoinedDialog extends StatefulWidget {
  const _JoinedDialog({required this.shopName});

  final String shopName;

  @override
  State<_JoinedDialog> createState() => _JoinedDialogState();
}

class _JoinedDialogState extends State<_JoinedDialog> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 520),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.brandAccent,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(
                  dimension: 88,
                  child:
                      Icon(Icons.check_rounded, color: AppColors.onLime, size: 52),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Chào mừng đến',
                style: AppTextStyles.body.copyWith(color: AppColors.onDarkMuted),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  widget.shopName,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.display.copyWith(
                      color: AppColors.white, fontSize: AppFontSizes.s34),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đang tải dữ liệu quán…',
                style: AppTextStyles.caption.copyWith(color: AppColors.onDarkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Danh sách lời mời trong hộp thư. Kéo xuống để làm mới; có lời mới thì rung nhẹ và báo.
class InviteListView extends StatefulWidget {
  const InviteListView({super.key, this.header, this.emptyText});

  /// Khối đặt phía trên danh sách (ví dụ lời chào ở không gian trống).
  final Widget? header;
  final String? emptyText;

  @override
  State<InviteListView> createState() => _InviteListViewState();
}

class _InviteListViewState extends State<InviteListView> {
  int _seenArrivals = 0;
  late final InboxController _inbox;

  @override
  void initState() {
    super.initState();
    _inbox = context.read<InboxController>();
    _inbox.addListener(_onChange);
  }

  void _onChange() {
    if (_inbox.newArrivals > _seenArrivals && mounted) {
      _seenArrivals = _inbox.newArrivals;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Có lời mời mới từ chủ quán.'),
        ));
    }
  }

  @override
  void dispose() {
    _inbox.removeListener(_onChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<InboxController>();
    return RefreshIndicator(
      color: AppColors.brand,
      onRefresh: () => c.load(quiet: true),
      child: LazyListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          if (widget.header != null) widget.header!,
          if (c.loading && c.invites.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (c.error != null && c.invites.isEmpty)
            ErrorRetry(message: c.error!, onRetry: () => c.load())
          else if (c.invites.isEmpty)
            _Note(
              icon: Icons.mail_outline_rounded,
              text: widget.emptyText ?? 'Chưa có thông báo nào.',
            )
          else
            for (var i = 0; i < c.invites.length; i++)
              FadeSlideIn(
                key: ValueKey(c.invites[i].id),
                delay: Duration(milliseconds: 80 * i),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _InviteCard(invite: c.invites[i]),
                ),
              ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.inkMuted),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.body),
          ],
        ),
      );
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.invite});

  final Invite invite;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<InboxController>();
    final busy = c.busyId == invite.id;
    final anyBusy = c.busyId != null;
    return ForeCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.tint,
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(Icons.storefront_outlined,
                      size: 20, color: AppColors.brand),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  invite.shopName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.heading,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${invite.invitedByName} mời bạn làm nhân viên với tên “${invite.invitedName}”.',
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(timeAgo(invite.createdAt), style: AppTextStyles.caption),
          const SizedBox(height: 16),
          ForeButton(
            label: 'Chấp nhận và vào quán',
            loadingLabel: 'Đang vào quán',
            loading: busy,
            onPressed: anyBusy ? null : () => acceptAndEnter(context, invite),
          ),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              onPressed: anyBusy
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final err = await c.decline(invite);
                      if (err != null) {
                        messenger.showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
              child: const Text('Từ chối'),
            ),
          ),
        ],
      ),
    );
  }
}
