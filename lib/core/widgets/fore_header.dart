import 'package:flutter/material.dart';

import 'fore_app_bar.dart';
import 'status_chip.dart';

/// Đầu trang chung của mọi màn trong ca (màn vận hành): tên quán, "Nhân viên · tên",
/// logo và (tùy chọn) nhãn trạng thái ca.
///
/// Giao diện là header rêu [ForeAppBar] như không gian chủ quán; giữ nguyên tham số cũ
/// nên các nơi gọi không phải đổi.
class ForeHeader extends StatelessWidget {
  const ForeHeader({
    super.key,
    required this.shopName,
    required this.subtitle,
    this.pill,
    this.onBack,
    this.onChooseShop,
  });

  final String shopName;
  final String subtitle;
  final Widget? pill;
  final VoidCallback? onBack;
  final VoidCallback? onChooseShop;

  @override
  Widget build(BuildContext context) => ForeAppBar(
        shopName: shopName,
        subtitle: subtitle.isEmpty ? null : subtitle,
        onChooseShop: onChooseShop,
        onBack: onBack,
        backTooltip: 'Về màn quản lý',
        bottom: pill == null
            ? null
            : Align(alignment: Alignment.centerLeft, child: pill),
      );
}

/// Nhãn nhỏ có chấm màu: "Chưa mở ca" / "Ca của An, mở lúc 8:02".
class ShiftPill extends StatelessWidget {
  const ShiftPill({super.key, required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: label,
        severity: active ? StatusSeverity.healthy : StatusSeverity.neutral,
      );
}
