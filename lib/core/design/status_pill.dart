import 'package:flutter/material.dart';

import '../widgets/status_chip.dart';

/// Trạng thái luôn có biểu tượng, chữ và màu cùng thể hiện một ý nghĩa.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.severity,
    this.compact = false,
  });

  final String label;
  final StatusSeverity severity;
  final bool compact;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: label,
        severity: severity,
        compact: compact,
      );
}
