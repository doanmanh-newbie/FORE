import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/phone.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/empty_state.dart' show ErrorRetry;
import '../../auth/application/session_controller.dart';
import '../application/team_controller.dart';
import '../domain/shop_models.dart';
import 'invite_list.dart' show timeAgo;
import '../../../core/widgets/lazy_list_view.dart';

/// Chủ quán: nhân viên của quán và nút "Thêm nhân viên" bằng số điện thoại.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  bool _checkingAccess = true;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepareScreen());
  }

  Future<void> _prepareScreen() async {
    if (!mounted) return;
    final controller = context.read<TeamController>();

    // Some widget tests mount this screen without the app-level session provider.
    // Production always has it, so revalidate the server role before reading team data.
    final session = context.read<SessionController?>();
    if (session == null) {
      await controller.load();
      if (mounted) setState(() => _checkingAccess = false);
      return;
    }

    final failure = await session.refreshAfterSignIn();
    if (!mounted) return;
    if (failure != null) {
      setState(() {
        _accessError = failure.userMessage;
        _checkingAccess = false;
      });
      return;
    }

    final state = session.state;
    if (state is SessionSignedIn && state.profile.role.isOwner) {
      await controller.load();
      if (mounted) setState(() => _checkingAccess = false);
      return;
    }

    final route = AppRoutes.routeFor(state);
    if (route == null) {
      setState(() {
        _accessError = 'Chưa xác định được quyền của phiên. Hãy thử tải lại.';
        _checkingAccess = false;
      });
      return;
    }

    setState(() => _checkingAccess = false);
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  Future<void> _openInvite(BuildContext context) async {
    // Auth state is shared by browser windows on the same origin. If another
    // window signed in as a staff member, the cached owner profile can be stale.
    // Recheck the server profile before showing an owner-only action.
    final session = context.read<SessionController>();
    final sessionFailure = await session.refreshAfterSignIn();
    if (!context.mounted) return;

    if (sessionFailure != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(sessionFailure.userMessage),
      ));
      return;
    }

    final state = session.state;
    if (state is! SessionSignedIn || !state.profile.role.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Phiên hiện tại không phải chủ quán. Hãy đăng nhập lại đúng tài khoản chủ.',
        ),
      ));
      final route = AppRoutes.routeFor(state);
      if (route != null) {
        Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
      }
      return;
    }

    final controller = context.read<TeamController>();
    controller.clearFormErrors();
    final messenger = ScaffoldMessenger.of(context);
    final sent = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: const _InviteSheet(),
      ),
    );
    if (sent != null) {
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Đã gửi lời mời $sent. Nhân viên đăng nhập bằng đúng số điện thoại hoặc email để xem trong Hộp thư.',
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TeamController>();
    if (_checkingAccess) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_accessError != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Nhân viên', style: AppTextStyles.heading),
        ),
        body: ErrorRetry(
          message: _accessError!,
          onRetry: () {
            setState(() {
              _checkingAccess = true;
              _accessError = null;
            });
            _prepareScreen();
          },
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Nhân viên', style: AppTextStyles.heading),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onInk,
        onPressed: () => _openInvite(context),
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Thêm nhân viên'),
      ),
      body: RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () => c.load(quiet: true),
        child: LazyListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          children: [
            if (c.loading && c.members.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (c.error != null && c.members.isEmpty)
              ErrorRetry(
                message: c.error!,
                onRetry: () {
                  setState(() {
                    _checkingAccess = true;
                    _accessError = null;
                  });
                  _prepareScreen();
                },
              )
            else ...[
              if (c.inviteHistory.isNotEmpty) ...[
                const _SectionTitle('Lời mời nhân viên'),
                for (final p in c.inviteHistory)
                  FadeSlideIn(
                    key: ValueKey(p.id),
                    child: _PendingTile(invite: p),
                  ),
                const SizedBox(height: 16),
              ],
              const _SectionTitle('Thành viên'),
              for (var i = 0; i < c.members.length; i++)
                FadeSlideIn(
                  key: ValueKey(c.members[i].staffId),
                  delay: Duration(milliseconds: 50 * i),
                  child: _MemberTile(member: c.members[i]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(text.toUpperCase(),
            style: AppTextStyles.caption
                .copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.8)),
      );
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.name, {this.muted = false});

  final String name;
  final bool muted;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: muted ? AppColors.disabledFill : AppColors.tint,
          shape: BoxShape.circle,
        ),
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: Text(
              name.isEmpty
                  ? '?'
                  : String.fromCharCode(name.runes.first).toUpperCase(),
              style: AppTextStyles.heading.copyWith(fontSize: AppFontSizes.s18),
            ),
          ),
        ),
      );
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.member});

  final TeamMember member;

  @override
  Widget build(BuildContext context) {
    final contact =
        member.phone.isNotEmpty ? Phone.pretty(member.phone) : member.email;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ForeCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _Avatar(member.fullName, muted: !member.active),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: AppTextStyles.label.copyWith(
                      fontSize: AppFontSizes.s15,
                      color: member.active
                          ? AppColors.textPrimary
                          : AppColors.inkMuted,
                    ),
                  ),
                  if (contact.isNotEmpty)
                    Text(contact, style: AppTextStyles.caption),
                ],
              ),
            ),
            if (member.isOwner)
              const _Chip('Chủ quán')
            else if (!member.active)
              const _Chip('Đã nghỉ'),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.tint,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(text, style: AppTextStyles.caption),
        ),
      );
}

class _PendingTile extends StatelessWidget {
  const _PendingTile({required this.invite});

  final PendingInvite invite;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ForeCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: invite.status == 'accepted'
                    ? AppColors.statusHealthyTint
                    : invite.status == 'declined'
                        ? AppColors.statusCriticalTint
                        : invite.status == 'expired'
                            ? AppColors.statusAttentionTint
                            : AppColors.warningSoft,
                shape: BoxShape.circle,
              ),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(
                  invite.status == 'accepted'
                      ? Icons.check_circle_outline
                      : invite.status == 'declined'
                          ? Icons.do_not_disturb_on_outlined
                          : invite.status == 'expired'
                              ? Icons.hourglass_disabled_rounded
                              : Icons.hourglass_top_rounded,
                  color: invite.status == 'accepted'
                      ? AppColors.statusHealthy
                      : invite.status == 'declined'
                          ? AppColors.statusCritical
                          : invite.status == 'expired'
                              ? AppColors.statusAttention
                              : AppColors.warningText,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(invite.fullName,
                      style: AppTextStyles.label
                          .copyWith(fontSize: AppFontSizes.s15)),
                  Text(
                    invite.statusLabel,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: invite.status == 'accepted'
                          ? AppColors.statusHealthy
                          : invite.status == 'declined'
                              ? AppColors.statusCritical
                              : invite.status == 'expired'
                                  ? AppColors.statusAttention
                                  : AppColors.warningText,
                    ),
                  ),
                  Text(
                    [
                      if (invite.phone != null)
                        Phone.pretty('+${invite.phone}'),
                      if (invite.email != null) invite.email,
                      timeAgo(invite.respondedAt ?? invite.createdAt)
                    ].join(' · '),
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            if (invite.status == 'pending')
              IconButton(
                tooltip: 'Hủy lời mời',
                icon: const Icon(Icons.close_rounded),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final err =
                      await context.read<TeamController>().cancel(invite);
                  if (err != null) {
                    messenger.showSnackBar(SnackBar(content: Text(err)));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  const _InviteSheet();

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _phone = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final c = context.read<TeamController>();
    final navigator = Navigator.of(context);
    final ok = await c.invite(
      phone: _phone.text,
      fullName: _name.text,
      email: _email.text,
    );
    if (ok && mounted) navigator.pop(_name.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<TeamController>();
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Thêm nhân viên', style: AppTextStyles.heading),
            const SizedBox(height: 4),
            Text(
              'Điền số điện thoại, email hoặc cả hai. Nhân viên cần xác minh thông tin tương ứng để nhận lời mời trong hộp thư.',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 18),
            AppTextField(
              label: 'Số điện thoại (không bắt buộc)',
              controller: _phone,
              hint: '0901 234 567',
              errorText: c.phoneError,
              enabled: !c.inviting,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Email (không bắt buộc)',
              controller: _email,
              hint: 'name@example.com',
              errorText: c.emailError,
              enabled: !c.inviting,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Tên hiển thị',
              controller: _name,
              hint: 'Ví dụ: Lan',
              errorText: c.nameError,
              enabled: !c.inviting,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            if (c.formError != null) ...[
              const SizedBox(height: 8),
              Text(c.formError!,
                  style: TextStyle(
                      color: AppColors.statusOff, fontSize: AppFontSizes.s13)),
            ],
            const SizedBox(height: 16),
            LoadingButton(
              label: 'Gửi lời mời',
              loadingLabel: 'Đang gửi',
              loading: c.inviting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
