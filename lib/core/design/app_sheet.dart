import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';
import 'typography.dart';

class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.footer,
  });

  final String title;
  final Widget child;
  final Widget? footer;

  static Future<T?> show<T>(BuildContext context,
          {required WidgetBuilder builder}) =>
      showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: builder,
      );

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppSizes.radiusCard),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            20,
            AppSizes.pagePadding,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(title, style: AppTextStyles.sectionTitle),
              const SizedBox(height: 16),
              child,
              if (footer != null) ...[
                const SizedBox(height: 16),
                footer!,
              ],
            ],
          ),
        ),
      );
}
