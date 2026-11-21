import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/design/colors.dart';
import '../../core/design/spacing.dart';
import '../../core/design/typography.dart';
import '../../core/errors/app_failure.dart';
import '../../core/theme/theme_mode_toggle.dart';
import '../../core/widgets/brand_text_field.dart';
import '../../core/widgets/loading_button.dart';
import '../admin_errors.dart';
import '../admin_theme.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';

/// Màn hình đăng nhập Super-Admin theo đúng tone màu Xanh rừng (#0D3B2E) +
/// Xanh ngọc (#1F6E58 / #51A19B) + nền kem (#F8F7F2) và logo biểu trưng Fore
/// (Figma `418:1031` / `418:1055` / `418:1167`), dùng lại `BrandTextField`,
/// `LoadingButton` và `ThemeModeToggle` từ `lib/core/`.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    super.key,
    required this.authRepository,
    required this.onSignedIn,
    this.initialError,
  });

  final AdminAuthRepository authRepository;
  final ValueChanged<AdminIdentity> onSignedIn;
  final String? initialError;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _emailError;
  String? _passwordError;
  String? _errorMessage;
  bool _wasForbidden = false;

  @override
  void initState() {
    super.initState();
    _errorMessage = widget.initialError;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    String? emailError;
    if (email.isEmpty) {
      emailError = 'Hãy nhập email.';
    } else if (!email.contains('@') || !email.contains('.')) {
      emailError = 'Email chưa đúng định dạng.';
    }

    String? passwordError;
    if (password.isEmpty) {
      passwordError = 'Hãy nhập mật khẩu.';
    }

    setState(() {
      _emailError = emailError;
      _passwordError = passwordError;
    });
    return emailError == null && passwordError == null;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _wasForbidden = false;
    });

    try {
      final identity = await widget.authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      widget.onSignedIn(identity);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _wasForbidden = isAdminForbidden(failure);
        _errorMessage = adminFailureMessage(failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể đăng nhập lúc này. Hãy thử lại sau ít phút.';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header cong nền xanh rừng đậm (#0D3B2E) đồng bộ Figma 418:1167 + 418:1055.
              Container(
                decoration: const BoxDecoration(
                  color: AdminPalette.forestDark,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.panel),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenGutter,
                  AppGaps.lg,
                  AppSizes.screenGutter,
                  52,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AdminLogoBadge(size: 42),
                            SizedBox(width: AppGaps.md),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fore',
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    color: AdminPalette.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Fore - Quản lý thông minh',
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    color: AdminPalette.mintMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Spacer(),
                            ThemeModeToggle(color: AdminPalette.white),
                          ],
                        ),
                        SizedBox(height: AppGaps.xl),
                        Text(
                          'Đăng nhập Admin',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            color: AdminPalette.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            height: 1.15,
                          ),
                        ),
                        SizedBox(height: AppGaps.xs),
                        Text(
                          'Quản trị nền tảng, giám sát lỗi, sự kiện và cấu hình từ xa.',
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            color: AdminPalette.mintSoft,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Thẻ vai trò Super-admin giao nhẹ với đáy header (phong cách Figma 418:1167).
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.screenGutter,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: AdminPalette.forestTeal,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.roleCard),
                              border: Border.all(
                                color: AdminPalette.mintSoft
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  top: 13,
                                  right: 13,
                                  child: SvgPicture.asset(
                                    'assets/auth/role_selected.svg',
                                    width: 22,
                                    height: 22,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    18,
                                    18,
                                    46,
                                    18,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AdminPalette.mintSoft
                                              .withValues(alpha: 0.18),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.admin_panel_settings_outlined,
                                          color: AdminPalette.white,
                                          size: 26,
                                        ),
                                      ),
                                      const SizedBox(width: AppGaps.md),
                                      const Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Quản trị nền tảng (Super-admin)',
                                              style: TextStyle(
                                                fontFamily: AppFonts.body,
                                                color: AdminPalette.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              'Dành riêng cho tài khoản trong bảng platform_admins',
                                              style: TextStyle(
                                                fontFamily: AppFonts.body,
                                                color: AdminPalette.mintSoft,
                                                fontSize: 12,
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppGaps.xl),
                          BrandTextField(
                            key: const Key('admin_email_field'),
                            label: 'Email',
                            controller: _emailController,
                            hint: 'Email tài khoản super-admin',
                            errorText: _emailError,
                            enabled: !_submitting,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            onChanged: (_) {
                              if (_emailError != null) {
                                setState(() => _emailError = null);
                              }
                            },
                          ),
                          const SizedBox(height: AppGaps.lg),
                          BrandTextField(
                            key: const Key('admin_password_field'),
                            label: 'Mật khẩu',
                            leadingAsset: 'assets/auth/ic_lock.svg',
                            controller: _passwordController,
                            errorText: _passwordError,
                            enabled: !_submitting,
                            obscure: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onChanged: (_) {
                              if (_passwordError != null) {
                                setState(() => _passwordError = null);
                              }
                            },
                            onSubmitted: _submit,
                          ),
                          if (_errorMessage != null) ...[
                            const SizedBox(height: AppGaps.lg),
                            Container(
                              key: const Key('admin_login_error_banner'),
                              padding: const EdgeInsets.all(AppGaps.md),
                              decoration: BoxDecoration(
                                color: AppColors.statusCriticalTint,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.field),
                                border: Border.all(
                                  color: AppColors.statusCritical
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _wasForbidden
                                        ? Icons.gpp_bad_outlined
                                        : Icons.error_outline_rounded,
                                    color: AppColors.statusCritical,
                                    size: 20,
                                  ),
                                  const SizedBox(width: AppGaps.sm),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: AppTextStyles.bodyStrong.copyWith(
                                        color: AppColors.statusCritical,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: AppGaps.xl),
                          LoadingButton(
                            key: const Key('admin_login_submit'),
                            label: 'Đăng nhập  →',
                            loadingLabel: 'Đang đăng nhập',
                            loading: _submitting,
                            onPressed: _submit,
                            height: AppSizes.pillButtonHeight,
                            textStyle: AppTextStyles.pillButton,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
