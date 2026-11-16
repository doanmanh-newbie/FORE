import 'package:flutter/material.dart';

import 'colors.dart';
import 'spacing.dart';

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppSizes.radius,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Đang tải nội dung',
        child: ExcludeSemantics(
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: AppColors.disabledFill,
              borderRadius: BorderRadius.circular(radius),
            ),
          ),
        ),
      );
}
