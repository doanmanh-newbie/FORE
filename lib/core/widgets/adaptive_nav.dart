import 'package:flutter/material.dart';

import '../motion.dart';
import '../theme/app_colors.dart';

class AdaptiveNavItem {
  const AdaptiveNavItem({
    required this.label,
    required this.icon,
    this.enabled = true,
  });

  final String label;
  final Widget icon;

  /// Tab bị khóa (vd cần có ca đang mở): hiện mờ và không chọn được.
  final bool enabled;
}

/// Khung màn chính có điều hướng: điện thoại dùng thanh dưới (`NavigationBar`),
/// màn rộng (máy tính bảng ở quầy) dùng `NavigationRail` bên trái và giới hạn bề
/// rộng nội dung để danh sách không bị kéo giãn.
class AdaptiveNavScaffold extends StatelessWidget {
  const AdaptiveNavScaffold({
    super.key,
    required this.body,
    required this.items,
    required this.selected,
    required this.onSelect,
  });

  /// Từ bề rộng này trở lên coi là máy tính bảng (Material "medium").
  static const railBreakpoint = 600.0;

  /// Bề rộng tối đa của nội dung khi có rail.
  static const maxContentWidth = 960.0;

  final Widget body;
  final List<AdaptiveNavItem> items;
  final int selected;
  final ValueChanged<int> onSelect;

  void _select(int i) {
    if (items[i].enabled) onSelect(i);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= railBreakpoint;
    if (!wide) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: body,
        bottomNavigationBar: NavigationBar(
          selectedIndex: selected,
          animationDuration:
              Motion.of(context, const Duration(milliseconds: 400)),
          onDestinationSelected: _select,
          destinations: [
            for (final item in items)
              NavigationDestination(
                enabled: item.enabled,
                label: item.label,
                icon: item.icon,
              ),
          ],
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: selected,
              onDestinationSelected: _select,
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    disabled: !item.enabled,
                    label: Text(item.label),
                    icon: item.icon,
                  ),
              ],
            ),
          ),
          VerticalDivider(width: 1, color: AppColors.cardBorder),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: maxContentWidth),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
