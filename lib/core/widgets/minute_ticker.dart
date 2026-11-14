import 'dart:async';

import 'package:flutter/widgets.dart';

/// Gọi lại `builder` với giờ hiện tại và vẽ lại mỗi `every`. Dùng cho đồng hồ
/// ("Ca mở 3 giờ 20 phút") để số tự nhảy mà không cần người dùng làm mới.
class MinuteTicker extends StatefulWidget {
  const MinuteTicker({
    super.key,
    required this.builder,
    this.every = const Duration(seconds: 20),
  });

  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration every;

  @override
  State<MinuteTicker> createState() => _MinuteTickerState();
}

class _MinuteTickerState extends State<MinuteTicker> {
  late DateTime _now = DateTime.now();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}
