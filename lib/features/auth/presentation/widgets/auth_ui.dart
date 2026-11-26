import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/spacing.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/motion.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/brand_text_field.dart';

/// Đường dẫn ảnh/icon của 3 màn Chào mừng, Đăng nhập, Đăng ký.
abstract final class AuthAssets {
  static const _dir = 'assets/auth';
  static const counter = '$_dir/onboarding_counter.png';
  static const roleOwner = '$_dir/role_owner.png';
  static const roleStaff = '$_dir/role_staff.png';
  static const roleSelected = '$_dir/role_selected.svg';
  static const roleUnselected = '$_dir/role_unselected.svg';
  static const person = '$_dir/ic_person.svg';
  static const mail = '$_dir/ic_mail.svg';
  static const lock = '$_dir/ic_lock.svg';
  static const back = '$_dir/ic_back.svg';
  static const stepRole = '$_dir/step_role.svg';
  static const stepStore = '$_dir/step_store.svg';
  static const stepSecurity = '$_dir/step_security.svg';
}

/// Logo F + chữ "FORE" nằm ngang (đầu màn Đăng nhập).
class AuthBrandRow extends StatelessWidget {
  const AuthBrandRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'FORE',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandMark(size: 26),
            const SizedBox(width: 10),
            Text(
              'FORE',
              style: AppTextStyles.brandName.copyWith(
                fontSize: 18,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung chung cho màn auth: nền kem, lề 20, nội dung không quá 480 trên tablet.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child, this.top});

  final Widget child;

  /// Phần cố định trên đầu (vd header Đăng ký), không cuộn theo form.
  final Widget? top;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            if (top != null) top!,
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.screenGutter,
                  AppGaps.lg,
                  AppSizes.screenGutter,
                  AppSizes.pageBottomPadding,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: child,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Thẻ chọn vai trò (Chủ quán / Nhân viên) ở màn Đăng nhập.
/// Đang chọn: nền navy, nội dung trắng, dấu tích; chưa chọn: thẻ trắng viền mảnh, hình và
/// chữ navy, vòng tròn rỗng. Thẻ đang chọn luôn là thẻ nổi nhất (bộ Navy).
class RoleCard extends StatelessWidget {
  const RoleCard({
    super.key,
    required this.label,
    required this.imageAsset,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String imageAsset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, const Duration(milliseconds: 220));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.roleCard),
          child: AnimatedContainer(
            duration: duration,
            curve: Curves.easeOutCubic,
            height: AppSizes.roleCardHeight,
            decoration: BoxDecoration(
              color: selected ? AppColors.moss : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.roleCard),
              border: Border.all(
                color: selected ? AppColors.moss : AppColors.border,
                width: 1.5,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.moss.withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                Positioned(
                  top: 13,
                  right: 13,
                  // SVG "đã chọn" vẽ hai màu (nền trắng, tích rêu) nên giữ nguyên màu gốc.
                  child: selected
                      ? SvgPicture.asset(AuthAssets.roleSelected,
                          width: 22, height: 22)
                      : TintedSvg(AuthAssets.roleUnselected,
                          color: AppColors.textHint, size: 22),
                ),
                Center(
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Hình nét trắng: chưa chọn thì tô navy để hiện trên nền trắng.
                        ColorFiltered(
                          colorFilter: ColorFilter.mode(
                            selected ? AppColors.white : AppColors.brand,
                            BlendMode.srcIn,
                          ),
                          child: Image.asset(imageAsset, width: 68, height: 68),
                        ),
                        const SizedBox(height: AppGaps.md),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: AppFonts.body,
                            color: selected ? AppColors.white : AppColors.brand,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Một bước trong thanh tiến trình đăng ký.
class AuthStep {
  const AuthStep(this.label, this.iconAsset);
  final String label;
  final String iconAsset;
}

/// Thanh các bước: vòng 44 có icon, nối bằng đường mảnh. Bước <= [current] tô mù tạt.
class AuthStepper extends StatelessWidget {
  const AuthStepper({super.key, required this.steps, required this.current});

  final List<AuthStep> steps;
  final int current;

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, const Duration(milliseconds: 220));
    final children = <Widget>[];
    for (var i = 0; i < steps.length; i++) {
      final reached = i <= current;
      if (i > 0) {
        children.add(Expanded(
          child: Padding(
            // Canh đường nối vào giữa vòng tròn (bỏ qua phần nhãn bên dưới).
            padding: const EdgeInsets.only(bottom: 26),
            child: AnimatedContainer(
              duration: duration,
              height: 1,
              color: reached ? AppColors.mustard : AppColors.leafFixed,
            ),
          ),
        ));
      }
      children.add(SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: duration,
              width: AppSizes.stepCircle,
              height: AppSizes.stepCircle,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: reached ? AppColors.mustard : AppColors.leafFixed,
                shape: BoxShape.circle,
              ),
              child: TintedSvg(steps[i].iconAsset,
                  color: AppColors.white, size: 22),
            ),
            const SizedBox(height: AppGaps.sm),
            Text(
              '${i + 1}. ${steps[i].label}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.stepLabel.copyWith(
                color: reached ? AppColors.brand : AppColors.brandAccent,
              ),
            ),
          ],
        ),
      ));
    }
    return Semantics(
      label: 'Bước ${current + 1} trên ${steps.length}: ${steps[current].label}',
      child: ExcludeSemantics(child: Row(children: children)),
    );
  }
}

/// Header màn Đăng ký: nút quay lại, tiêu đề mù tạt, thanh bước. Đáy bo 28.
class AuthStepHeader extends StatelessWidget {
  const AuthStepHeader({
    super.key,
    required this.title,
    required this.steps,
    required this.current,
    this.onBack,
  });

  final String title;
  final List<AuthStep> steps;
  final int current;

  /// `null` = nút quay lại bị khóa (đang gửi yêu cầu).
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppGaps.sm, AppGaps.sm, AppGaps.sm, AppGaps.sm),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              SizedBox(
                height: AppSizes.touchTarget,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: 'Quay lại',
                        onPressed: onBack,
                        icon: TintedSvg(AuthAssets.back,
                            color: AppColors.brand, size: 22),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.appBarTitle,
                          textAlign: TextAlign.center),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppGaps.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppGaps.md),
                child: AuthStepper(steps: steps, current: current),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dòng lỗi chung của form (dưới các ô nhập).
class AuthFormError extends StatelessWidget {
  const AuthFormError(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppGaps.md),
      child: Text(
        message,
        style: TextStyle(
          fontFamily: AppFonts.body,
          color: AppColors.statusCritical,
          fontSize: AppFontSizes.s13,
          height: 1.4,
        ),
      ),
    );
  }
}

/// "Câu hỏi? Liên kết" ở cuối form, liên kết đậm gạch chân.
class AuthPromptLink extends StatelessWidget {
  const AuthPromptLink({
    super.key,
    required this.prompt,
    required this.action,
    required this.onTap,
  });

  final String prompt;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(prompt,
            style: AppTextStyles.body
                .copyWith(fontSize: 13, color: AppColors.textPrimary)),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            minimumSize: const Size(0, AppSizes.touchTarget),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(action, style: AppTextStyles.link),
        ),
      ],
    );
  }
}
