import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/brand_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/staff_login_controller.dart';
import '../domain/staff_contact.dart';
import 'contact_kind_toggle.dart';
import 'widgets/auth_ui.dart';

/// Đăng nhập của nhân viên: chọn số điện thoại hoặc email, nhập cùng mật khẩu, bấm "Đăng nhập".
/// Chưa có tài khoản thì bấm "Tạo tài khoản". Đăng nhập xong gọi `onSignedIn` để màn cha chuyển trang.
class StaffLoginPanel extends StatefulWidget {
  const StaffLoginPanel({super.key, required this.onSignedIn});

  final Future<void> Function() onSignedIn;

  @override
  State<StaffLoginPanel> createState() => _StaffLoginPanelState();
}

class _StaffLoginPanelState extends State<StaffLoginPanel> {
  final _contact = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await context
        .read<StaffLoginController>()
        .submit(_contact.text, _password.text);
    if (ok) await widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffLoginController>();
    final phone = c.kind == ContactKind.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ContactKindToggle(
          kind: c.kind,
          onChanged: c.setKind,
          enabled: !c.loading,
        ),
        const SizedBox(height: AppGaps.lg),
        BrandTextField(
          label: phone ? 'Số điện thoại' : 'Email',
          controller: _contact,
          hint: phone ? '0901 234 567' : 'Địa chỉ email của bạn',
          errorText: c.contactError,
          enabled: !c.loading,
          keyboardType:
              phone ? TextInputType.phone : TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: [
            phone ? AutofillHints.telephoneNumber : AutofillHints.email,
          ],
        ),
        const SizedBox(height: AppGaps.md),
        BrandTextField(
          label: 'Mật khẩu',
          controller: _password,
          hint: 'Mật khẩu của bạn',
          errorText: c.passwordError,
          enabled: !c.loading,
          obscure: true,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: _submit,
        ),
        if (c.formError != null) AuthFormError(c.formError!),
        const SizedBox(height: AppGaps.xl),
        LoadingButton(
          label: 'Đăng nhập',
          loadingLabel: 'Đang đăng nhập',
          loading: c.loading,
          onPressed: _submit,
          height: AppSizes.pillButtonHeight,
          textStyle: AppTextStyles.pillButton,
        ),
        const SizedBox(height: AppGaps.md),
        AuthPromptLink(
          prompt: 'Chưa có tài khoản? ',
          action: 'Tạo tài khoản',
          onTap: c.loading
              ? null
              : () => Navigator.of(context).pushNamed(AppRoutes.registerStaff),
        ),
      ],
    );
  }
}
