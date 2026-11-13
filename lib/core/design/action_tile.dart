import 'package:flutter/material.dart';

import '../widgets/fore_card.dart' show ForeCard;
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final Widget icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: onTap != null,
        label: title,
        hint: subtitle,
        child: ExcludeSemantics(
          child: ForeCard(
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            radius: AppSizes.radiusTile,
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.tint,
                    borderRadius: BorderRadius.circular(AppSizes.radiusTile),
                  ),
                  child: SizedBox(
                      width: 48, height: 48, child: Center(child: icon)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTextStyles.cardTitle),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.statusAttentionTint,
                      borderRadius: BorderRadius.circular(AppSizes.radiusChip),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      child: Text(badge!, style: AppTextStyles.micro),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      );
}
