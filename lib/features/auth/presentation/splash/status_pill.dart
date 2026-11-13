import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'splash_timeline.dart';
import 'package:fore/core/design/typography.dart';

/// Viên thuốc nhỏ dưới logo: "ĐANG KẾT NỐI" (nhấp nháy nhẹ) hoặc "MẤT KẾT NỐI" (đứng yên).
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.loop,
    required this.active,
  });

  final String label;
  final Animation<double> loop;

  /// `true` khi đang chờ (nhấp nháy). `false` khi mất mạng (đứng yên, chấm đỏ).
  final bool active;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.brandAccent : AppColors.statusOff,
              ),
              child: const SizedBox.square(dimension: 6),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: loop,
              builder: (context, child) => Opacity(
                opacity: active ? SplashTimeline.pillOpacity(loop.value) : 1,
                child: child,
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSizes.s12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
