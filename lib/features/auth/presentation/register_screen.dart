import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/brand_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/pill_segmented.dart';
import '../application/register_controller.dart';
import '../application/session_controller.dart';
import 'widgets/auth_ui.dart';

/// Tạo tài khoản CHỦ QUÁN (email + mật khẩu). Tạo xong đi tiếp tới màn Tạo quán.
/// Nhân viên không dùng màn này: họ tạo tài khoản bằng số điện thoại hoặc email ở `StaffRegisterScreen`.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _continued = false;

  /// Đăng ký với vai trò chủ quán (mặc định) hay nhân viên (truyền `false` khi mở màn này).
  bool get _asOwner =>
      (ModalRoute.of(context)?.settings.arguments as bool?) ?? true;

  /// Đăng ký xong và đã có phiên: tải hồ sơ rồi đi tiếp (chưa có quán -> Tạo quán).
  Future<void> _continueSignedIn() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final session = context.read<SessionController>();
    final failure = await session.refreshAfterSignIn();
    if (!mounted) return;
    if (failure != null) {
      _continued = false;
      messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    final next = AppRoutes.routeFor(session.state);
    if (next != null) navigator.pushNamedAndRemoveUntil(next, (_) => false);
  }

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() => context.read<RegisterController>().submit(
        fullName: _name.text,
        email: _email.text,
        password: _password.text,
        confirm: _confirm.text,
      );

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RegisterController>();
    if (c.status == RegisterStatus.success) {
      if (c.signedIn) {
        if (!_continued) {
          _continued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _continueSignedIn();
          });
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return _RegisterSuccessView(email: c.registeredEmail);
    }
    final busy = c.loading;
    return AuthScaffold(
      top: AuthStepHeader(
        title: 'Tạo tài khoản mới',
        steps: ownerSignUpSteps,
        current: 0,
        onBack: busy ? null : () => Navigator.of(context).maybePop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillSegmented<bool>(
            value: _asOwner,
            enabled: !busy,
            items: const [(true, 'Chủ quán'), (false, 'Nhân viên')],
            onChanged: (owner) => owner
                ? Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.register, arguments: true)
                : Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.registerStaff),
          ),
          const SizedBox(height: AppGaps.md),
          Text(
            _asOwner
                ? 'Dùng email của bạn để đăng ký. Sau đó bạn tạo quán và thêm nhân viên.'
                : 'Dùng email của bạn để đăng ký. Chủ quán sẽ mời bạn, lời mời hiện trong hộp thư.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppGaps.xl),
          BrandTextField(
            label: 'Họ và tên',
            leadingAsset: AuthAssets.person,
            controller: _name,
            errorText: c.nameError,
            enabled: !busy,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: AppGaps.md),
          BrandTextField(
            label: 'Email',
            leadingAsset: AuthAssets.mail,
            controller: _email,
            errorText: c.emailError,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
          ),
          const SizedBox(height: AppGaps.md),
          BrandTextField(
            label: 'Mật khẩu',
            hint: 'Mật khẩu (ít nhất ${AppConfig.minPasswordLength} ký tự)',
            leadingAsset: AuthAssets.lock,
            controller: _password,
            errorText: c.passwordError,
            enabled: !busy,
            obscure: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: AppGaps.md),
          BrandTextField(
            label: 'Nhập lại mật khẩu',
            leadingAsset: AuthAssets.lock,
            controller: _confirm,
            errorText: c.confirmError,
            enabled: !busy,
            obscure: true,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
          if (c.formError != null) AuthFormError(c.formError!),
          const SizedBox(height: AppGaps.xl),
          LoadingButton(
            label: 'Đăng ký ngay',
            loadingLabel: 'Đang tạo tài khoản',
            loading: busy,
            onPressed: _submit,
            height: AppSizes.pillButtonHeight,
            textStyle: AppTextStyles.pillButton,
          ),
          const SizedBox(height: AppGaps.md),
          AuthPromptLink(
            prompt: 'Đã có tài khoản? ',
            action: 'Đăng nhập',
            onTap: busy ? null : () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}

/// Các bước đăng ký của chủ quán: tạo tài khoản ở đây, tạo quán ở màn kế, xác nhận email.
const ownerSignUpSteps = [
  AuthStep('Vai trò', AuthAssets.stepRole),
  AuthStep('Cửa hàng', AuthAssets.stepStore),
  AuthStep('Bảo mật', AuthAssets.stepSecurity),
];

/// Màn thành công: không có nút quay lại (form đã gửi rồi).
class _RegisterSuccessView extends StatefulWidget {
  const _RegisterSuccessView({required this.email});

  final String email;

  @override
  State<_RegisterSuccessView> createState() => _RegisterSuccessViewState();
}

class _RegisterSuccessViewState extends State<_RegisterSuccessView> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.email));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.backgroundTint,
                child: Icon(Icons.check, size: 40, color: AppColors.statusOk),
              ),
              const SizedBox(height: 20),
              Text('Kiểm tra email của bạn', style: AppTextStyles.screenTitle),
              const SizedBox(height: 8),
              Text(
                'Bấm vào đường dẫn trong email gửi tới địa chỉ này để xác nhận tài khoản, rồi đăng nhập bằng vai trò Chủ quán.',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                ),
                child: Column(
                  children: [
                    SelectableText(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _copy,
                      icon: Icon(
                        _copied ? Icons.check : Icons.copy_outlined,
                        size: 18,
                      ),
                      label: Text(_copied ? 'Đã sao chép' : 'Sao chép'),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context)
                    .pushNamedAndRemoveUntil(AppRoutes.welcome, (r) => false),
                child: const Text('Về màn đăng nhập'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
