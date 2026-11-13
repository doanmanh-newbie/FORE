import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'splash_strings.dart';
import 'package:fore/core/design/typography.dart';

/// Dòng nhỏ cuối màn hình.
///
/// Lưu ý nội dung: hai dòng chữ này là lời cam kết với người dùng. Chỉ giữ khi
/// app thật sự làm được (phiên đăng nhập an toàn, đồng bộ dữ liệu). Sửa ở `SplashStrings`.
class SplashFooter extends StatelessWidget {
  const SplashFooter({super.key});

  static TextStyle get _style => TextStyle(
    fontSize: AppFontSizes.s12,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.textSecondary,
  );

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              SplashStrings.footerLeft,
              style: _style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandAccent,
            ),
            child: const SizedBox.square(dimension: 4),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              SplashStrings.footerRight,
              style: _style,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
}
