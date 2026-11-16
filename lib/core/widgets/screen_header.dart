import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_theme.dart';
import '../theme/theme_mode_toggle.dart';

/// Đầu trang của màn phụ (đẩy lên từ tab): nền rêu bo góc dưới, nút quay lại,
/// tiêu đề trắng, dòng mô tả trắng mờ. Màu cố định ở cả hai chế độ.
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
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.moss,
          borderRadius:
              BorderRadius.vertical(bottom: Radius.circular(AppRadius.panel)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 12, 18),
            child: _Constrain(
                maxWidth: maxContentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Quay lại',
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.white),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: AppTextStyles.panelTitle
                                    .copyWith(fontSize: 22, height: 1.2)),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(subtitle!,
                                  style: const TextStyle(
                                    fontFamily: AppFonts.body,
                                    fontSize: 13,
                                    color: AppColors.onDarkMuted,
                                    height: 1.4,
                                  )),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const ThemeModeToggle(color: AppColors.white),
                  ],
                )),
          ),
        ),
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
