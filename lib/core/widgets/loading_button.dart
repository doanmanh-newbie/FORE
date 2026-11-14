import 'package:flutter/material.dart';

import '../design/colors.dart';

/// Nút chính (viên thuốc vàng mù tạt theo theme): khi `loading` hiện vòng quay
/// và không bấm được nữa (chặn bấm hai lần gửi hai yêu cầu).
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.height,
    this.textStyle,
  });

  final String label;
  final String? loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;

  /// Cao hơn mặc định của theme, vd `AppSizes.pillButtonHeight` ở các màn đăng nhập.
  final double? height;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: height == null && textStyle == null
          ? null
          : FilledButton.styleFrom(
              minimumSize: height == null ? null : Size.fromHeight(height!),
              textStyle: textStyle,
            ),
      child: loading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(loadingLabel ?? label),
              ],
            )
          : Text(label),
    );
  }
}
