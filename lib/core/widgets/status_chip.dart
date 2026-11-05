import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum StatusSeverity { healthy, attention, critical, neutral }

/// Nhãn trạng thái thống nhất: luôn có chữ và màu ngữ nghĩa đi cùng nhau.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.severity,
    this.compact = false,
  });

  final String label;
  final StatusSeverity severity;
  final bool compact;

  Color get _foreground => switch (severity) {
        StatusSeverity.healthy => AppColors.statusHealthy,
        StatusSeverity.attention => AppColors.statusAttention,
        StatusSeverity.critical => AppColors.statusCritical,
        StatusSeverity.neutral => AppColors.textSecondary,
      };

  Color get _background => switch (severity) {
        StatusSeverity.healthy => AppColors.statusHealthyTint,
        StatusSeverity.attention => AppColors.statusAttentionTint,
        StatusSeverity.critical => AppColors.statusCriticalTint,
        StatusSeverity.neutral => AppColors.tint,
      };

  IconData get _icon => switch (severity) {
        StatusSeverity.healthy => Icons.check_circle_outline_rounded,
        StatusSeverity.attention => Icons.warning_amber_rounded,
        StatusSeverity.critical => Icons.error_outline_rounded,
        StatusSeverity.neutral => Icons.info_outline_rounded,
      };

  @override
  Widget build(BuildContext context) => Semantics(
        label: label,
        child: ExcludeSemantics(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 9 : 11,
                vertical: compact ? 5 : 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_icon, size: compact ? 14 : 16, color: _foreground),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _foreground,
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
