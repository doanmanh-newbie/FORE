import 'package:flutter/widgets.dart';

/// Như `ListView(children: ...)` nhưng chỉ dựng các dòng đang hiện trên màn hình.
/// Dùng cho mọi danh sách theo dữ liệu (món, nguyên liệu, phiếu, ca...).
class LazyListView extends StatelessWidget {
  const LazyListView({
    super.key,
    required this.children,
    this.padding,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: padding,
        physics: physics,
        scrollDirection: scrollDirection,
        itemCount: children.length,
        itemBuilder: (_, i) => children[i],
      );
}
