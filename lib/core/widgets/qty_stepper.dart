import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_colors.dart';
import 'package:fore/core/design/typography.dart';

/// Bộ tăng giảm số lượng tròn trịa: nút "-" chỉ hiện khi đã chọn.
class QtyStepper extends StatelessWidget {
  const QtyStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.max = 99,
    this.compact = false,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int max;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 36.0 : 40.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: Motion.of(context, const Duration(milliseconds: 180)),
          curve: Curves.easeOut,
          alignment: Alignment.centerRight,
          child: value > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _RoundButton(
                      size: size,
                      icon: Icons.remove_rounded,
                      semantics: 'Giảm',
                      onTap: () => onChanged(value - 1),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '$value',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: AppFontSizes.s16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ],
                )
              : const SizedBox.shrink(),
        ),
        _RoundButton(
          size: size,
          icon: Icons.add_rounded,
          filled: true,
          semantics: 'Tăng',
          onTap: value >= max ? null : () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.size,
    required this.icon,
    required this.semantics,
    required this.onTap,
    this.filled = false,
  });

  final double size;
  final IconData icon;
  final String semantics;
  final VoidCallback? onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantics,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 48, // vùng chạm tối thiểu
            height: 48,
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: onTap == null
                      ? AppColors.disabledFill
                      : filled
                          ? AppColors.ink
                          : AppColors.surfaceTint,
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: onTap == null
                      ? AppColors.textMuted
                      : filled
                          ? AppColors.onInk
                          : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      );
}
