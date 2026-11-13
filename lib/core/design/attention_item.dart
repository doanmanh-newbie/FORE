import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

class AttentionItem extends StatelessWidget {
  const AttentionItem({
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppSizes.radiusCard),
          border: Border.fromBorderSide(
              BorderSide(color: AppColors.cardBorder)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.statusAttention),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 4),
                  Text(message, style: AppTextStyles.caption),
                  if (actionLabel != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: onAction,
                        child: Text(actionLabel!),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
}
