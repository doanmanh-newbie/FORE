import 'package:flutter/material.dart';

import 'pill_segmented.dart';

/// Chọn một trong vài lựa chọn ngắn (Thu vào / Chi ra, Gọi món / Bill).
/// Giao diện là công tắc viên thuốc [PillSegmented] của bộ "Rêu & Mù tạt";
/// giữ tham số cũ (danh sách nhãn + chỉ số) để nơi gọi không phải đổi.
class ForeSegmented extends StatelessWidget {
  const ForeSegmented({
    super.key,
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => PillSegmented<int>(
        value: selected,
        items: [for (var i = 0; i < labels.length; i++) (i, labels[i])],
        onChanged: onChanged,
      );
}
