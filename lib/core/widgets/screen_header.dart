import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Đầu trang của màn phụ (đẩy lên từ tab): nút quay lại, tiêu đề chữ có chân, dòng mô tả.
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
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 20, 14),
            child: _Constrain(
                maxWidth: maxContentWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      tooltip: 'Quay lại',
                      onPressed:
                          onBack ?? () => Navigator.of(context).maybePop(),
                      icon:
                          Icon(Icons.arrow_back_rounded, color: AppColors.ink),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: AppTextStyles.headline),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(subtitle!, style: AppTextStyles.caption),
                            ],
                          ],
                        ),
                      ),
                    ),
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
