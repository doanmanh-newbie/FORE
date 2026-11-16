import 'package:flutter/material.dart';

import '../../../app/app_routes.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/brand_logo.dart';
import 'widgets/auth_ui.dart';

/// Màn chào mừng: thương hiệu + minh họa quầy cà phê, panel xanh với nút "Bắt đầu ngay"
/// dẫn tới màn Đăng nhập. Chỉ là giao diện: không gọi API, không giữ trạng thái.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _start(BuildContext context) =>
      Navigator.of(context).pushNamed(AppRoutes.welcome);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final padding = MediaQuery.paddingOf(context);
          // Màn thấp (máy nhỏ, xoay ngang): cho cuộn thay vì ép nhỏ minh họa đến mất.
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    SizedBox(height: padding.top + AppGaps.xl),
                    const BrandLogo(markSize: 54),
                    const SizedBox(height: AppGaps.xs),
                    Text(
                      'Fore - Quản lý thông minh',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body.copyWith(
                        fontSize: 13,
                        color: AppColors.brandAccent,
                      ),
                    ),
                    const SizedBox(height: AppGaps.lg),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.screenGutter),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              minHeight: 200, maxHeight: 320, maxWidth: 380),
                          child: Image.asset(
                            AuthAssets.counter,
                            fit: BoxFit.contain,
                            semanticLabel:
                                'Minh họa quầy cà phê với nhân viên đang pha chế',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppGaps.lg),
                    _WelcomePanel(
                      bottomInset: padding.bottom,
                      onStart: () => _start(context),
                      onExplore: () => _showHighlights(context),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Panel xanh chuyển màu, bo hai góc trên 28: tiêu đề, mô tả, nút chính, liên kết phụ.
class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel({
    required this.bottomInset,
    required this.onStart,
    required this.onExplore,
  });

  final double bottomInset;
  final VoidCallback onStart;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.moss, AppColors.leafFixed],
        ),
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSizes.screenGutter,
        AppGaps.xxl + 4,
        AppSizes.screenGutter,
        AppGaps.lg + bottomInset,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            children: [
              const Text(
                'Quản lý thông minh,\nVận hành dễ dàng',
                textAlign: TextAlign.center,
                style: AppTextStyles.panelTitle,
              ),
              const SizedBox(height: AppGaps.md),
              Text(
                'Giải pháp tối ưu cho chủ quán\nvà nhân viên',
                textAlign: TextAlign.center,
                style: AppTextStyles.body.copyWith(
                  fontSize: 15,
                  color: AppColors.onDarkMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: AppGaps.xxl),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    // Panel luôn tối: dùng màu cố định để không đảo theo chế độ tối.
                    backgroundColor: AppColors.mustard,
                    foregroundColor: AppColors.moss,
                    minimumSize:
                        const Size.fromHeight(AppSizes.pillButtonHeight),
                    textStyle: AppTextStyles.pillButton,
                  ),
                  onPressed: onStart,
                  child: const Text('Bắt đầu ngay  >>>'),
                ),
              ),
              const SizedBox(height: AppGaps.sm),
              TextButton(
                onPressed: onExplore,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.white,
                  minimumSize: const Size(0, AppSizes.touchTarget),
                ),
                child: const Text(
                  'Khám phá thêm',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.onDarkMuted,
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

/// "Khám phá thêm": tóm tắt ba việc Fore làm, rồi mời bắt đầu.
void _showHighlights(BuildContext context) {
  const items = [
    (Icons.point_of_sale_outlined, 'Bán hàng theo ca',
        'Mở ca, gọi món theo bàn hoặc mang đi, chốt tiền cuối ca.'),
    (Icons.inventory_2_outlined, 'Kho và nguyên liệu',
        'Nhập hàng, kiểm kho, ghi hao hụt ngay tại quầy.'),
    (Icons.fact_check_outlined, 'Đối soát thất thoát',
        'So doanh thu với nguyên liệu đã dùng để thấy ngay ca lệch.'),
  ];
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.panel)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSizes.screenGutter, 0,
            AppSizes.screenGutter, AppSizes.screenGutter),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Fore giúp quán bạn',
                style: AppTextStyles.appBarTitle
                    .copyWith(color: AppColors.brand, fontSize: 20)),
            const SizedBox(height: AppGaps.lg),
            for (final (icon, title, body) in items)
              Padding(
                padding: const EdgeInsets.only(bottom: AppGaps.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentTint,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                      ),
                      child: Icon(icon, color: AppColors.brand, size: 22),
                    ),
                    const SizedBox(width: AppGaps.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTextStyles.bodyStrong),
                          const SizedBox(height: 2),
                          Text(body, style: AppTextStyles.body),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppGaps.sm),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.pillButtonHeight),
                textStyle: AppTextStyles.pillButton,
              ),
              onPressed: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed(AppRoutes.welcome);
              },
              child: const Text('Bắt đầu ngay'),
            ),
          ],
        ),
      ),
    ),
  );
}
