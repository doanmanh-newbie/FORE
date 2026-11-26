import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/theme_mode_toggle.dart';

/// Đầu trang của màn phụ (đẩy lên từ tab), bộ Navy: nền sáng liền thân trang, nút quay
/// lại tròn trắng, tiêu đề mực đậm, dòng mô tả chữ phụ.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader(
      {super.key,
      required this.title,
      this.subtitle,
      this.onBack,
      this.maxContentWidth});

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;

  /// Có giá trị thì phần chữ và nút Back căn vào cùng khung với nội dung bên dưới (tablet).
  final double? maxContentWidth;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: AppColors.background,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: _Constrain(
                maxWidth: maxContentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Circle(
                      child: IconButton(
                        tooltip: 'Quay lại',
                        color: AppColors.textPrimary,
                        onPressed:
                            onBack ?? () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: TextStyle(
                                  fontFamily: AppFonts.body,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                )),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(subtitle!,
                                  style: TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _Circle(
                        child: ThemeModeToggle(color: AppColors.textPrimary)),
                  ],
                )),
          ),
        ),
      );
}

/// Nút tròn nền trắng viền mảnh, cùng kiểu với đầu trang các tab chính.
class _Circle extends StatelessWidget {
  const _Circle({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.surface,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Center(child: child),
      );
}

class _Constrain extends StatelessWidget {
  const _Constrain({required this.maxWidth, required this.child});

  final double? maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => maxWidth == null
      ? child
      : Align(
          alignment: Alignment.topCenter,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth!),
            child: child,
          ),
        );
}
