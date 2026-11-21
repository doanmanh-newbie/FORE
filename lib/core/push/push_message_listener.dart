import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'push_notification_service.dart';
import 'push_registration_controller.dart';

/// Thông báo đến khi app đang mở: hiện thanh báo ở dưới màn hình
/// (khi app ở nền, hệ điều hành tự hiển thị nên không cần làm gì).
class PushMessageListener extends StatefulWidget {
  const PushMessageListener({super.key, required this.child});

  final Widget child;

  @override
  State<PushMessageListener> createState() => _PushMessageListenerState();
}

class _PushMessageListenerState extends State<PushMessageListener> {
  StreamSubscription<PushMessage>? _sub;
  PushRegistrationController? _source;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final source = context.read<PushRegistrationController?>();
    if (identical(source, _source)) return;
    _sub?.cancel();
    _source = source;
    _sub = source?.messages.listen(_show);
  }

  void _show(PushMessage m) {
    if (!mounted) return;
    final text = [m.title, m.body].whereType<String>().join(': ');
    if (text.isEmpty) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
