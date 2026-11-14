import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared scrollable page content with consistent gutters and bottom space.
class PageScaffold extends StatelessWidget {
  const PageScaffold({
    super.key,
    required this.children,
    this.header,
    this.physics,
    this.padding,
  });

  final List<Widget> children;
  final Widget? header;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final items = [
      if (header != null) ...[header!, const SizedBox(height: 12)],
      ...children,
    ];
    // Dựng từng dòng khi cuộn tới thay vì dựng hết một lượt.
    return ListView.builder(
      physics: physics,
      padding: padding ??
          const EdgeInsets.fromLTRB(
            AppSizes.pagePadding,
            AppSizes.pageTopPadding,
            AppSizes.pagePadding,
            AppSizes.pageBottomPadding,
          ),
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
    );
  }
}
