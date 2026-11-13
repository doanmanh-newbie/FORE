import 'package:flutter/material.dart';

import '../widgets/fore_card.dart';
import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

class KpiCard extends StatelessWidget {
  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    this.comparison,
    this.footer,
    this.chart,
  });

  final String label;
  final String value;
  final String? comparison;
  final String? footer;
  final Widget? chart;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(AppSizes.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.kpi,
                  ),
                ),
                if (chart != null) chart!,
              ],
            ),
            if (comparison != null) ...[
              const SizedBox(height: 4),
              Text(comparison!, style: AppTextStyles.caption),
            ],
            if (footer != null) ...[
              const SizedBox(height: 8),
              Divider(height: 1, color: AppColors.cardBorder),
              const SizedBox(height: 8),
              Text(footer!, style: AppTextStyles.caption),
            ],
          ],
        ),
      );
}
