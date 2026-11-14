import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Đường dẫn icon (xuất từ Figma, nét vẽ 22 x 22). Khai báo thư mục `assets/icons/` trong pubspec.yaml.
abstract final class ForeIcons {
  static const home = 'assets/icons/home.svg';
  static const bag = 'assets/icons/bag.svg';
  static const package = 'assets/icons/package.svg';
  static const lock = 'assets/icons/lock.svg';
  static const plus = 'assets/icons/plus.svg';
  static const warning = 'assets/icons/warning.svg';
  static const check = 'assets/icons/check.svg';
  static const calendar = 'assets/icons/calendar.svg';
}

/// Icon SVG đổi được màu (các file gốc dùng màu cứng nên phải tô lại).
class ForeIcon extends StatelessWidget {
  const ForeIcon(this.asset, {super.key, this.size = 22, this.color});

  final String asset;
  final double size;
  final Color? color;

  /// Không truyền `color` thì lấy màu icon của theme hiện tại (vd thanh điều hướng
  /// tự đổi màu tab đang chọn / chưa chọn / bị khóa).
  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color;
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      colorFilter: tint == null ? null : ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}
