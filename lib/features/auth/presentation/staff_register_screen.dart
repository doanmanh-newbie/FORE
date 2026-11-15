import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../core/design/spacing.dart';
import '../../../core/widgets/brand_text_field.dart';
import '../../../core/widgets/loading_button.dart';
import '../../../core/widgets/pill_segmented.dart';
import '../../shift/application/shift_controller.dart';
import '../../shop/application/auto_join.dart';
import '../../shop/domain/shop_repository.dart';
import '../application/session_controller.dart';
import '../application/staff_register_controller.dart';
import '../domain/staff_contact.dart';
import 'contact_kind_toggle.dart';
import 'widgets/auth_ui.dart';

/// Tạo tài khoản nhân viên: số điện thoại hoặc email, tên hiển thị, ngày sinh.
/// Tạo xong là đăng nhập luôn và vào thẳng giao diện nhân viên (chưa có quán thì vào không gian
/// nhân viên, lời mời của chủ quán hiện trong hộp thư).
class StaffRegisterScreen extends StatefulWidget {
  const StaffRegisterScreen({super.key});

  @override
  State<StaffRegisterScreen> createState() => _StaffRegisterScreenState();
}

class _StaffRegisterScreenState extends State<StaffRegisterScreen> {
  final _contact = TextEditingController();
  final _name = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  DateTime? _birthDate;

  /// Tài khoản đã tạo nhưng chưa tải được hồ sơ (mất mạng...): nút chính đổi thành "Thử lại".
  bool _needsRetry = false;
  String? _sessionError;

  @override
  void dispose() {
    _contact.dispose();
    _name.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_needsRetry) return _enterApp();
    final ok = await context.read<StaffRegisterController>().submit(
          contactText: _contact.text,
          fullName: _name.text,
          birthDate: _birthDate,
          password: _password.text,
          confirm: _confirm.text,
        );
    if (ok && mounted) await _enterApp();
  }

  /// Đã có phiên: tải hồ sơ rồi đi tới màn của nhân viên.
  Future<void> _enterApp() async {
    final navigator = Navigator.of(context);
    final session = context.read<SessionController>();
    final shops = context.read<ShopRepository>();
    final shift = context.read<ShiftController>();
    var failure = await session.refreshAfterSignIn();
    if (!mounted) return;
    // Chủ đã mời số này từ trước: vào quán luôn (chế độ thử nghiệm).
    if (failure == null &&
        session.state is SessionAwaitingInvite &&
        await autoJoinSingleInvite(shops)) {
      failure = await session.refreshAfterSignIn();
      if (!mounted) return;
      if (failure == null) shift.load();
    }
    if (failure != null) {
      final message = failure.userMessage;
      setState(() {
        _needsRetry = true;
        _sessionError = 'Đã tạo tài khoản nhưng chưa vào được: $message';
      });
      return;
    }
    final next = AppRoutes.routeFor(session.state);
    if (next != null) navigator.pushNamedAndRemoveUntil(next, (_) => false);
  }

  Future<void> _pickBirthDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(today.year - 18, today.month, today.day),
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'Chọn ngày sinh',
    );
    if (picked == null || !mounted) return;
    setState(() => _birthDate = picked);
    context.read<StaffRegisterController>().clearBirthDateError();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<StaffRegisterController>();
    final phone = c.kind == ContactKind.phone;
    final busy = c.loading;
    return AuthScaffold(
      top: AuthStepHeader(
        title: 'Tạo tài khoản mới',
        steps: _staffSteps,
        current: 0,
        onBack: busy ? null : () => Navigator.of(context).maybePop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PillSegmented<bool>(
            value: false,
            enabled: !busy,
            items: const [(true, 'Chủ quán'), (false, 'Nhân viên')],
            onChanged: (owner) {
              if (owner) {
                Navigator.of(context)
                    .pushReplacementNamed(AppRoutes.register, arguments: true);
              }
            },
          ),
          const SizedBox(height: AppGaps.md),
          Text(
            'Chỉ cần số điện thoại hoặc email và một mật khẩu. Chủ quán mời bạn bằng đúng '
            'số/email này, lời mời sẽ hiện trong hộp thư của bạn.',
            style: AppTextStyles.caption.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppGaps.xl),
          ContactKindToggle(
            kind: c.kind,
            onChanged: c.setKind,
            enabled: !busy,
          ),
          const SizedBox(height: AppGaps.md),
          BrandTextField(
            label: phone ? 'Số điện thoại' : 'Email',
            hint: phone
                ? 'Số điện thoại (vd 0901 234 567)'
                : 'Địa chỉ email của bạn',
            leadingAsset: phone ? null : AuthAssets.mail,
            leadingIcon: phone ? Icons.phone_outlined : null,
            controller: _contact,
            errorText: c.contactError,
            enabled: !busy,
            onChanged: (_) => c.clearContactError(),
            keyboardType:
                phone ? TextInputType.phone : TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: [
              phone ? AutofillHints.telephoneNumber : AutofillHints.email,
            ],
          ),
          const SizedBox(height: AppGaps.md),
          BrandTextField(
            label: 'Tên hiển thị',
            hint: 'Tên hiển thị (vd: Lan)',
            leadingAsset: AuthAssets.person,
            controller: _name,
            errorText: c.nameError,
            enabled: !busy,
            onChanged: (_) => c.clearNameError(),
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: AppGaps.md),
          _BirthDateField(
            value: _birthDate,
            errorText: c.birthDateError,
            onTap: busy ? null : _pickBirthDate,
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
            hint: 'Nhập lại mật khẩu',
            leadingAsset: AuthAssets.lock,
            controller: _confirm,
            errorText: c.confirmError,
            enabled: !busy,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            onSubmitted: _submit,
          ),
          if (c.formError != null || _sessionError != null)
            AuthFormError(c.formError ?? _sessionError!),
          const SizedBox(height: AppGaps.xl),
          LoadingButton(
            label: _needsRetry ? 'Thử lại' : 'Tạo tài khoản',
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
            onTap: busy ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// Bước đăng ký của nhân viên: chọn vai trò + điền thông tin, đặt mật khẩu, vào quán.
const _staffSteps = [
  AuthStep('Vai trò', AuthAssets.stepRole),
  AuthStep('Mật khẩu', AuthAssets.stepSecurity),
  AuthStep('Vào quán', AuthAssets.stepStore),
];

/// Ô chọn ngày sinh, cùng dáng với ô nhập: bấm mở lịch.
class _BirthDateField extends StatelessWidget {
  const _BirthDateField({
    required this.value,
    required this.errorText,
    required this.onTap,
  });

  final DateTime? value;
  final String? errorText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          label: 'Ngày sinh',
          value: value == null ? 'Chưa chọn' : formatDmy(value!),
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.field),
              side: BorderSide(
                color: hasError ? AppColors.statusCritical : AppColors.border,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(AppRadius.field),
              child: SizedBox(
                height: AppSizes.fieldHeight,
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.calendar_month_outlined,
                        size: 20, color: AppColors.textHint),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ExcludeSemantics(
                        child: Text(
                          value == null
                              ? 'Ngày sinh (bấm để chọn)'
                              : formatDmy(value!),
                          style: value == null
                              ? AppTextStyles.inputHint
                              : AppTextStyles.input,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.textHint),
                    const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 6),
            child: Text(
              errorText!,
              style: TextStyle(
                color: AppColors.statusCritical,
                fontSize: AppFontSizes.s12,
              ),
            ),
          ),
      ],
    );
  }
}
