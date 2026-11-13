import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'ops_icon.dart';

/// Trạng thái rỗng: icon, tiêu đề chữ có chân, mô tả, và (tùy chọn) một nút.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ForeIcon(icon, size: 34, color: AppColors.ink),
              const SizedBox(height: 18),
              Text(title,
                  style: AppTextStyles.headline, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(message,
                  style: AppTextStyles.body, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: 22),
                FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ],
          ),
        ),
      );
}

/// Thông báo lỗi tải dữ liệu kèm nút "Thử lại".
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ForeIcon(ForeIcons.warning,
                  size: 34, color: AppColors.statusWatchBright),
              const SizedBox(height: 14),
              Text(message,
                  style: AppTextStyles.body, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              OutlinedButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ),
        ),
      );
}
