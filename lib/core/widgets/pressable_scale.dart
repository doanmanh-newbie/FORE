import 'package:flutter/material.dart';

import '../motion.dart';

/// Bọc một thẻ để khi nhấn thì co nhẹ lại: cảm giác chạm rõ ràng mà không cần thư viện nào.
/// Không có `onTap` thì không phản hồi gì (thẻ chỉ để xem).
class PressableScale extends StatefulWidget {
  const PressableScale(
      {super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: Motion.of(context, const Duration(milliseconds: 110)),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}
