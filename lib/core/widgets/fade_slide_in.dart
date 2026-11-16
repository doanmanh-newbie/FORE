import 'dart:async';

import 'package:flutter/material.dart';

import '../motion.dart';

/// Hiện dần và trượt nhẹ từ dưới lên sau `delay`. Dùng để các khối trên màn hình
/// lần lượt xuất hiện thay vì bật ra cùng lúc. Tắt hoạt ảnh thì hiện ngay.
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 480),
    this.offsetY = 0.08,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;

  /// Độ trượt ban đầu, tính theo chiều cao của `child` (0,08 = 8%).
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> {
  Timer? _timer;
  bool _visible = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (Motion.reduced(context) || widget.delay == Duration.zero) {
      _visible = true;
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) setState(() => _visible = true);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final duration = Motion.of(context, widget.duration);
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: duration,
      curve: Curves.easeOut,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : Offset(0, widget.offsetY),
        duration: duration,
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
