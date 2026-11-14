import 'package:flutter/material.dart';

import '../design/colors.dart';

/// Nút chính: khi `loading` hiện vòng quay và không bấm được nữa
/// (chặn bấm hai lần gửi hai yêu cầu).
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
  });

  final String label;
  final String? loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      child: loading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.onInk,
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
