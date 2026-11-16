import 'package:flutter/material.dart';

import 'empty_state.dart';

class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_outlined,
        title: 'Chưa tải được dữ liệu',
        message: message,
        actionLabel: 'Thử lại',
        onAction: onRetry,
      );
}
