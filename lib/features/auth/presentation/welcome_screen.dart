import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/loading_button.dart';
import '../../shift/application/shift_controller.dart';
import '../../shop/application/auto_join.dart';
import '../../shop/domain/shop_repository.dart';
import '../application/login_controller.dart';
import '../application/session_controller.dart';
import 'forgot_password_dialog.dart';
import 'staff_login_panel.dart';

enum _Mode { owner, staff }

/// Màn đầu kiêm đăng nhập. Công tắc "Chủ quán | Nhân viên" nằm ngay trên form, đổi là form đổi theo.
/// Chủ quán: email + mật khẩu (phải có tài khoản rõ ràng).
/// Nhân viên xác minh email hoặc số điện thoại bằng OTP.
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      const Center(child: BrandLogo(markSize: 64)),
                      const SizedBox(height: 16),
                      Text(
                        'Đăng nhập',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.screenTitle,
                      ),
                      const SizedBox(height: 20),
                      _RoleSwitch(mode: _mode, onChanged: _pick),
                      const SizedBox(height: 28),
                      AnimatedSwitcher(
                        duration: Motion.of(
                            context, const Duration(milliseconds: 300)),
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
                      const SizedBox(height: 24),
                      if (kDebugMode)
                        TextButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppRoutes.designGallery),
                          icon: const Icon(Icons.palette_outlined),
                          label: const Text('Xem thư viện giao diện'),
                        ),
                    ],
                  ))),
        ),
      ),
    );
  }
}

/// Công tắc chọn vai trò: Chủ quán | Nhân viên. Phần chọn trượt sang bên được chọn.
class _RoleSwitch extends StatelessWidget {
  const _RoleSwitch({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    final owner = mode == _Mode.owner;

    Widget label(_Mode m, IconData icon, String text) {
      final on = mode == m;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(m),
          child: SizedBox(
            height: 46,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon,
                    size: 18, color: on ? AppColors.onInk : AppColors.brand),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: on ? AppColors.onInk : AppColors.brand,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.tint,
        borderRadius: BorderRadius.circular(AppSizes.radius + 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedAlign(
                duration: Motion.of(context, const Duration(milliseconds: 240)),
                curve: Curves.easeOutCubic,
                alignment: owner ? Alignment.centerLeft : Alignment.centerRight,
                child: FractionallySizedBox(
                  widthFactor: 0.5,
                  heightFactor: 1, // không có thì viên chọn cao 0 và không hiện
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.brand,
                      borderRadius: BorderRadius.circular(AppSizes.radius),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                label(_Mode.owner, Icons.storefront_outlined, 'Chủ quán'),
                label(_Mode.staff, Icons.badge_outlined, 'Nhân viên'),
              ],
            ),
          ],
        ),
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
        AppTextField(
          label: 'Email',
          controller: email,
          hint: isOwner ? 'Email tài khoản chủ quán' : 'Email của bạn',
          errorText: c.emailError,
          enabled: !c.loading,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 16),
        AppTextField(
          label: 'Mật khẩu',
          controller: password,
          hint: 'Mật khẩu của bạn',
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
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 36),
            ),
            onPressed: () => showForgotPasswordDialog(context),
            child: const Text('Quên mật khẩu?'),
          ),
        ),
        if (c.formError != null || sessionError != null) ...[
          const SizedBox(height: 12),
          Text(
            c.formError ?? sessionError!,
            style: TextStyle(
                color: AppColors.statusOff, fontSize: AppFontSizes.s13),
          ),
        ],
        const SizedBox(height: 20),
        LoadingButton(
          label: 'Đăng nhập',
          loadingLabel: 'Đang đăng nhập',
          loading: c.loading,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 14),
        if (isOwner)
          OutlinedButton(
            onPressed: () => Navigator.of(context)
                .pushNamed(AppRoutes.register, arguments: true),
            child: const Text('Tạo tài khoản chủ quán'),
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
        if (sessionError != null) ...[
          const SizedBox(height: 12),
          Text(
            sessionError!,
            style: TextStyle(
                color: AppColors.statusOff, fontSize: AppFontSizes.s13),
          ),
        ],
      ],
    );
  }
}
