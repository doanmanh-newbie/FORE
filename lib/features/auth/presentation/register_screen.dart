import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/config/app_config.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/register_controller.dart';
import '../application/session_controller.dart';

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
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          _asOwner
                              ? 'Tạo tài khoản chủ quán'
                              : 'Tạo tài khoản nhân viên',
                          style: AppTextStyles.screenTitle),
                      const SizedBox(height: 6),
                      Text(
                        _asOwner
                            ? 'Dùng email của bạn để đăng ký. Sau đó bạn tạo quán và thêm nhân viên.'
                            : 'Dùng email của bạn để đăng ký. Chủ quán sẽ mời bạn, lời mời hiện trong hộp thư.',
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        label: 'Họ tên',
                        controller: _name,
                        hint: 'Họ tên của bạn',
                        errorText: c.nameError,
                        enabled: !c.loading,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Email',
                        controller: _email,
                        hint: 'Địa chỉ email cá nhân',
                        errorText: c.emailError,
                        enabled: !c.loading,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Mật khẩu',
                        controller: _password,
                        hint: 'Ít nhất ${AppConfig.minPasswordLength} ký tự',
                        errorText: c.passwordError,
                        enabled: !c.loading,
                        obscure: true,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        label: 'Nhập lại mật khẩu',
                        controller: _confirm,
                        hint: 'Nhập lại mật khẩu của bạn',
                        errorText: c.confirmError,
                        enabled: !c.loading,
                        obscure: true,
                        textInputAction: TextInputAction.done,
                        onSubmitted: _submit,
                      ),
                      if (c.formError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          c.formError!,
                          style: TextStyle(
                            color: AppColors.statusOff,
                            fontSize: AppFontSizes.s13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      LoadingButton(
                        label: 'Tạo tài khoản',
                        loadingLabel: 'Đang tạo tài khoản',
                        loading: c.loading,
                        onPressed: _submit,
                      ),
                    ],
                  ))),
        ),
      ),
    );
  }
}

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
