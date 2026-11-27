import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/forgot_password_controller.dart';
import '../domain/auth_repository.dart';

Future<void> showForgotPasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => ForgotPasswordController(context.read<AuthRepository>()),
      child: const _ForgotPasswordDialog(),
    ),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ForgotPasswordController>();
    return AlertDialog(
      title: const Text('Quên mật khẩu'),
      // Column co theo nội dung: không có nó hộp thoại kéo dài gần hết màn hình.
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.sent)
            const Text(
                'Đã gửi. Mở email trên điện thoại này và bấm liên kết để đặt mật khẩu mới.')
          else
            AppTextField(
              label: 'Email',
              controller: _email,
              errorText: c.error,
              enabled: !c.loading,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: () => c.submit(_email.text),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(c.sent ? 'Đóng' : 'Hủy'),
        ),
        if (!c.sent)
          SizedBox(
            width: 140,
            child: LoadingButton(
              label: 'Gửi liên kết',
              loading: c.loading,
              onPressed: () => c.submit(_email.text),
            ),
          ),
      ],
    );
  }
}
