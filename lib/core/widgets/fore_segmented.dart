import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_colors.dart';
import 'package:fore/core/design/typography.dart';

/// Chọn một trong vài lựa chọn ngắn (Thu vào / Chi ra, Gọi món / Bill).
class ForeSegmented extends StatelessWidget {
  const ForeSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: labels[i],
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: AnimatedContainer(
                          duration: Motion.of(
                              context, const Duration(milliseconds: 200)),
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == selected
                                ? AppColors.ink
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: AppFontSizes.s15,
                              fontWeight: FontWeight.w700,
                              color:
                                  i == selected ? AppColors.onInk : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}
