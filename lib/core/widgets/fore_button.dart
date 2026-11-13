import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'loading_button.dart';
import 'package:fore/core/design/colors.dart';

/// Nút chính của các màn nhân viên: cao 56, có bóng mực nhạt bên dưới
/// như bản thiết kế. Bên trong là [LoadingButton] nên cũng chặn bấm hai lần.
class ForeButton extends StatelessWidget {
  const ForeButton({
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowRaised,
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SizedBox(
        height: 56,
        child: LoadingButton(
          label: label,
          loadingLabel: loadingLabel,
          loading: loading,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
