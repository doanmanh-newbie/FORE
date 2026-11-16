import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import '../motion.dart';

/// Công tắc viên thuốc hai (hoặc nhiều) lựa chọn: rãnh xanh lá, viên chọn vàng mù tạt
/// trượt sang lựa chọn đang bật.
class PillSegmented<T> extends StatelessWidget {
  const PillSegmented({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.height = AppSizes.segmentedHeight,
  });

  final T value;

  /// Giá trị -> nhãn, theo thứ tự hiển thị.
  final List<(T, String)> items;
  final ValueChanged<T> onChanged;
  final bool enabled;
  final double height;

  @override
  Widget build(BuildContext context) {
    final index = items.indexWhere((e) => e.$1 == value);
    final duration = Motion.of(context, const Duration(milliseconds: 240));
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        height: height,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.leafFixed,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Stack(
          children: [
            if (index >= 0)
              AnimatedAlign(
                duration: duration,
                curve: Curves.easeOutCubic,
                alignment: Alignment(
                  items.length == 1 ? 0 : -1 + 2 * index / (items.length - 1),
                  0,
                ),
                child: FractionallySizedBox(
                  widthFactor: 1 / items.length,
                  heightFactor: 1,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.mustard,
                      borderRadius:
                          BorderRadius.all(Radius.circular(AppRadius.pill)),
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                for (final (v, label) in items)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: v == value,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: enabled && v != value ? () => onChanged(v) : null,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: duration,
                            style: AppTextStyles.segment.copyWith(
                              color: v == value
                                  ? AppColors.moss
                                  : AppColors.white,
                            ),
                            child: Text(label),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
