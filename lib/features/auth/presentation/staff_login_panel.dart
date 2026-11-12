import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../application/staff_login_controller.dart';
import '../domain/staff_contact.dart';
import 'contact_kind_toggle.dart';

/// Đăng nhập của nhân viên: chọn số điện thoại hoặc email, nhập, bấm "Đăng nhập".
/// Không mật khẩu, không mã xác nhận. Chưa có tài khoản thì bấm "Tạo tài khoản".
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
          const SizedBox(height: 16),
          AppTextField(
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
          const SizedBox(height: 8),
          const Text(
            'Fore sẽ gửi mã xác nhận để bảo vệ tài khoản nhân viên.',
            style: AppTextStyles.caption,
          ),
        ] else ...[
          const Text(
            'Nếu thông tin có tài khoản, mã xác nhận đã được gửi. Nhập mã 6 chữ số để tiếp tục.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 16),
          AppTextField(
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
        if (c.formError != null) ...[
          const SizedBox(height: 12),
          Text(
            c.formError!,
            style: const TextStyle(
                color: AppColors.statusOff, fontSize: AppFontSizes.s13),
          ),
        ],
        const SizedBox(height: 20),
        LoadingButton(
          label: c.otpRequested ? 'Xác nhận mã' : 'Gửi mã đăng nhập',
          loadingLabel: c.otpRequested ? 'Đang xác nhận' : 'Đang gửi mã',
          loading: c.loading,
          onPressed: _submit,
        ),
        const SizedBox(height: 14),
        OutlinedButton(
          onPressed: c.loading || c.otpRequested
              ? null
              : () => Navigator.of(context).pushNamed(AppRoutes.registerStaff),
          child: const Text('Tạo tài khoản nhân viên'),
        ),
      ],
    );
  }
}
