import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Bộ icon của app (file SVG ở `assets/icons`, lấy từ thiết kế). Tô màu bằng
/// `color`, nên cùng một icon dùng được cho trạng thái thường, khóa và đang chọn.
enum ForeIcon {
  bag('assets/icons/bag.svg'),
  package('assets/icons/package.svg'),
  home('assets/icons/home.svg'),
  lock('assets/icons/lock.svg'),
  lockOpen('assets/icons/lock-open.svg'),
  plus('assets/icons/plus.svg'),
  calendar('assets/icons/calendar.svg'),
  warning('assets/icons/warning.svg'),
  chevronDown('assets/icons/chevron-down.svg');

  const ForeIcon(this.asset);

  final String asset;
}

class ForeIconView extends StatelessWidget {
  const ForeIconView(
    this.icon, {
    super.key,
    this.size = 22,
    required this.color,
  });

  final ForeIcon icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        icon.asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}
