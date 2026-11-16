import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/motion.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/brand_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../../shift/application/shift_controller.dart';
import '../../shop/application/auto_join.dart';
import '../../shop/domain/shop_repository.dart';
import '../application/login_controller.dart';
import '../application/session_controller.dart';
import 'forgot_password_dialog.dart';
import 'staff_login_panel.dart';
import 'widgets/auth_ui.dart';

enum _Mode { owner, staff }

/// Màn đăng nhập. Hai thẻ vai trò "Chủ quán | Nhân viên" nằm ngay trên form, chọn là form đổi theo.
/// Chủ quán: email + mật khẩu (phải có tài khoản rõ ràng).
/// Nhân viên: số điện thoại hoặc email + mật khẩu (không còn OTP).
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  _Mode _mode = _Mode.staff;

  /// Lỗi sau khi đã đăng nhập đúng nhưng chưa tải được hồ sơ.
  String? _sessionError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _pick(_Mode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _sessionError = null;
    });
  }

  /// Sau khi đăng nhập thành công: tải hồ sơ rồi đi tới màn phù hợp.
  Future<void> _afterSignIn() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();
    final shops = context.read<ShopRepository>();
    final shift = context.read<ShiftController>();
    var failure = await session.refreshAfterSignIn();
    if (!mounted) return;
    if (failure != null) {
      final message = failure.userMessage;
      setState(() => _sessionError = message);
      return;
    }
    // Nhân viên chưa thuộc quán nào mà chủ đã mời: vào quán luôn (chế độ thử nghiệm).
    if (session.state is SessionAwaitingInvite) {
      if (await autoJoinSingleInvite(shops)) {
        failure = await session.refreshAfterSignIn();
        if (!mounted) return;
        if (failure != null) {
          final message = failure.userMessage;
          setState(() => _sessionError = message);
          return;
        }
        shift.load();
      }
    }
    final next = AppRoutes.routeFor(session.state);
    if (next != null) navigator.pushNamedAndRemoveUntil(next, (_) => false);
  }

  Future<void> _submitOwner() async {
    final login = context.read<LoginController>();
    if (_sessionError != null) setState(() => _sessionError = null);
    final ok = await login.submit(email: _email.text, password: _password.text);
    if (ok) await _afterSignIn();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppGaps.sm),
          const Align(alignment: Alignment.centerLeft, child: AuthBrandRow()),
          const SizedBox(height: AppGaps.xl),
          Text('Đăng nhập', style: AppTextStyles.heroTitle),
          const SizedBox(height: AppGaps.xl),
          Row(
            children: [
              Expanded(
                child: RoleCard(
                  label: 'Chủ quán',
                  imageAsset: AuthAssets.roleOwner,
                  selected: _mode == _Mode.owner,
                  onTap: () => _pick(_Mode.owner),
                ),
              ),
              const SizedBox(width: AppGaps.md),
              Expanded(
                child: RoleCard(
                  label: 'Nhân viên',
                  imageAsset: AuthAssets.roleStaff,
                  selected: _mode == _Mode.staff,
                  onTap: () => _pick(_Mode.staff),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppGaps.xxl),
          AnimatedSwitcher(
            duration: Motion.of(context, const Duration(milliseconds: 300)),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            child: switch (_mode) {
              _Mode.owner => _PasswordForm(
                  key: const ValueKey('owner'),
                  isOwner: true,
                  email: _email,
                  password: _password,
                  sessionError: _sessionError,
                  onSubmit: _submitOwner,
                ),
              _Mode.staff => _StaffForm(
                  key: const ValueKey('staff'),
                  sessionError: _sessionError,
                  onSignedIn: _afterSignIn,
                ),
            },
          ),
          if (kDebugMode) ...[
            const SizedBox(height: AppGaps.lg),
            TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.designGallery),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Xem thư viện giao diện'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PasswordForm extends StatelessWidget {
  const _PasswordForm({
    super.key,
    required this.isOwner,
    required this.email,
    required this.password,
    required this.sessionError,
    required this.onSubmit,
  });

  final bool isOwner;
  final TextEditingController email;
  final TextEditingController password;
  final String? sessionError;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<LoginController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrandTextField(
          label: 'Email',
          controller: email,
          hint: isOwner ? 'Email tài khoản chủ quán' : 'Email của bạn',
          errorText: c.emailError,
          enabled: !c.loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: AppGaps.lg),
        BrandTextField(
          label: 'Mật khẩu',
          leadingAsset: AuthAssets.lock,
          controller: password,
          errorText: c.passwordError,
          enabled: !c.loading,
          obscure: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: onSubmit,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, AppSizes.touchTarget),
            ),
            onPressed: () => showForgotPasswordDialog(context),
            child: Text(
              'Quên mật khẩu?',
              style: AppTextStyles.link.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ),
        if (c.formError != null || sessionError != null)
          AuthFormError(c.formError ?? sessionError!),
        const SizedBox(height: AppGaps.lg),
        LoadingButton(
          label: 'Đăng nhập  →',
          loadingLabel: 'Đang đăng nhập',
          loading: c.loading,
          onPressed: onSubmit,
          height: AppSizes.pillButtonHeight,
          textStyle: AppTextStyles.pillButton,
        ),
        const SizedBox(height: AppGaps.md),
        if (isOwner)
          AuthPromptLink(
            prompt: 'Chưa có tài khoản? ',
            action: 'Tạo tài khoản',
            onTap: () => Navigator.of(context)
                .pushNamed(AppRoutes.register, arguments: true),
          ),
      ],
    );
  }
}

class _StaffForm extends StatelessWidget {
  const _StaffForm({
    super.key,
    required this.sessionError,
    required this.onSignedIn,
  });

  final String? sessionError;
  final Future<void> Function() onSignedIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaffLoginPanel(onSignedIn: onSignedIn),
        if (sessionError != null) AuthFormError(sessionError!),
      ],
    );
  }
}
