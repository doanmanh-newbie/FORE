import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_config.dart';
import '../../../core/design/spacing.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/brand_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/notify.dart';
import '../domain/auth_repository.dart';
import 'widgets/auth_ui.dart';

/// Nghe sự kiện "mở app từ link đặt lại mật khẩu" và hiện hộp thoại đặt mật khẩu mới.
/// Đặt trong `MaterialApp.builder` (phía trên Navigator) nên cần [navigatorKey] để mở hộp thoại.
class PasswordRecoveryListener extends StatefulWidget {
  const PasswordRecoveryListener({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<PasswordRecoveryListener> createState() =>
      _PasswordRecoveryListenerState();
}

class _PasswordRecoveryListenerState extends State<PasswordRecoveryListener> {
  StreamSubscription<void>? _sub;
  AuthRepository? _source;
  bool _showing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = context.read<AuthRepository?>();
    if (identical(source, _source)) return;
    _sub?.cancel();
    _source = source;
    _sub = source?.passwordRecoveries.listen((_) => _open());
  }

  Future<void> _open() async {
    if (_showing) return;
    _showing = true;
    // Phiên tạm vừa có có thể làm app đổi màn (splash → trang chủ); chờ điều hướng xong
    // để hộp thoại không bị đóng theo màn cũ.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final nav = widget.navigatorKey.currentState;
    final repo = _source;
    if (!mounted || nav == null || repo == null) {
      _showing = false;
      return;
    }
    final done = await showDialog<bool>(
      context: nav.context,
      barrierDismissible: false,
      builder: (_) => NewPasswordDialog(repository: repo),
    );
    _showing = false;
    final ctx = widget.navigatorKey.currentContext;
    if (done == true && ctx != null && ctx.mounted) {
      showNotice(ctx, 'Đã đổi mật khẩu. Lần sau đăng nhập bằng mật khẩu mới.',
          kind: NoticeKind.success);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Hộp thoại nhập mật khẩu mới hai lần. Trả `true` khi đổi xong, `false` nếu bỏ qua.
class NewPasswordDialog extends StatefulWidget {
  const NewPasswordDialog({super.key, required this.repository});

  final AuthRepository repository;

  @override
  State<NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<NewPasswordDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _passwordError;
  String? _confirmError;
  String? _formError;
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final p = _password.text;
    setState(() {
      _passwordError = p.length < AppConfig.minPasswordLength
          ? 'Mật khẩu cần ít nhất ${AppConfig.minPasswordLength} ký tự.'
          : null;
      _confirmError = _confirm.text != p ? 'Hai mật khẩu chưa khớp.' : null;
      _formError = null;
    });
    if (_passwordError != null || _confirmError != null) return;
    setState(() => _loading = true);
    try {
      await widget.repository.updatePassword(p);
      if (mounted) Navigator.of(context).pop(true);
    } on AppFailure catch (f) {
      if (mounted) setState(() => _formError = f.userMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Đặt mật khẩu mới'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Nhập mật khẩu mới cho tài khoản của bạn.'),
            const SizedBox(height: AppGaps.lg),
            BrandTextField(
              label: 'Mật khẩu mới',
              controller: _password,
              obscure: true,
              enabled: !_loading,
              errorText: _passwordError,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: AppGaps.md),
            BrandTextField(
              label: 'Nhập lại mật khẩu',
              controller: _confirm,
              obscure: true,
              enabled: !_loading,
              errorText: _confirmError,
              textInputAction: TextInputAction.done,
              onSubmitted: _submit,
            ),
            if (_formError != null) AuthFormError(_formError!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Để sau'),
        ),
        LoadingButton(
          label: 'Lưu mật khẩu',
          loadingLabel: 'Đang lưu',
          loading: _loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
