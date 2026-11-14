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

/// Đăng nhập của nhân viên: chọn số điện thoại hoặc email, nhập, bấm "Đăng nhập".
/// Fore gửi mã xác nhận (OTP) rồi nhập mã. Chưa có tài khoản thì bấm "Tạo tài khoản".
/// Đăng nhập xong gọi `onSignedIn` để màn cha chuyển trang.
class StaffLoginPanel extends StatefulWidget {
  const StaffLoginPanel({super.key, required this.onSignedIn});

  final Future<void> Function() onSignedIn;

  @override
  State<StaffLoginPanel> createState() => _StaffLoginPanelState();
}

class _StaffLoginPanelState extends State<StaffLoginPanel> {
  final _contact = TextEditingController();
  final _otp = TextEditingController();

  @override
  void dispose() {
    _contact.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = context.read<StaffLoginController>();
    final verifying = controller.otpRequested;
    final ok = verifying
        ? await controller.verifyOtp(_otp.text)
        : await controller.submit(_contact.text);
    if (ok && verifying) await widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffLoginController>();
    final phone = c.kind == ContactKind.phone;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!c.otpRequested) ...[
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
            textInputAction: TextInputAction.done,
            autofillHints: [
              phone ? AutofillHints.telephoneNumber : AutofillHints.email,
            ],
            onSubmitted: _submit,
          ),
          const SizedBox(height: AppGaps.sm),
          Text(
            'Fore sẽ gửi mã xác nhận để bảo vệ tài khoản nhân viên.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
        ] else ...[
          Text(
            'Nếu thông tin có tài khoản, mã xác nhận đã được gửi. Nhập mã 6 chữ số để tiếp tục.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppGaps.lg),
          BrandTextField(
            label: 'Mã xác nhận',
            controller: _otp,
            hint: '000000',
            errorText: c.otpError,
            enabled: !c.loading,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: c.canResend ? c.resendOtp : null,
              child: Text(c.canResend
                  ? 'Gửi lại mã'
                  : 'Gửi lại mã sau ${c.resendSeconds} giây'),
            ),
          ),
        ],
        if (c.formError != null) AuthFormError(c.formError!),
        const SizedBox(height: AppGaps.xl),
        LoadingButton(
          label: c.otpRequested ? 'Xác nhận mã' : 'Gửi mã đăng nhập',
          loadingLabel: c.otpRequested ? 'Đang xác nhận' : 'Đang gửi mã',
          loading: c.loading,
          onPressed: _submit,
          height: AppSizes.pillButtonHeight,
          textStyle: AppTextStyles.pillButton,
        ),
        const SizedBox(height: AppGaps.md),
        AuthPromptLink(
          prompt: 'Chưa có tài khoản? ',
          action: 'Tạo tài khoản',
          onTap: c.loading || c.otpRequested
              ? null
              : () => Navigator.of(context).pushNamed(AppRoutes.registerStaff),
        ),
      ],
    );
  }
}
