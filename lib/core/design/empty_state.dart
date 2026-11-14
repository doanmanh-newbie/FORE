import 'package:flutter/material.dart';

import 'colors.dart';
import 'primary_button.dart';
import 'spacing.dart';
import 'typography.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: AppColors.brandAccent),
              const SizedBox(height: 12),
              Text(title,
                  style: AppTextStyles.cardTitle, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(message,
                  style: AppTextStyles.body, textAlign: TextAlign.center),
              if (actionLabel != null) ...[
                const SizedBox(height: 16),
                PrimaryButton(label: actionLabel!, onPressed: onAction),
              ],
            ],
          ),
        ),
      );
}
