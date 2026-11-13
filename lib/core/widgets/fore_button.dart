import 'package:flutter/material.dart';

import 'loading_button.dart';

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
    return SizedBox(
      height: 56,
      child: LoadingButton(
        label: label,
        loadingLabel: loadingLabel,
        loading: loading,
        onPressed: onPressed,
      ),
    );
  }
}
