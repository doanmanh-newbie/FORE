import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';

/// Logo Fore (bộ "Rêu & Mù tạt", 11/2026): dấu hiệu chữ F hai lớp lá xanh
/// (`assets/brand/fore_f.png`, nền trong suốt) + chữ "FORE" Inter 700.
///
/// Tỉ lệ theo Figma màn Chào mừng: dấu hiệu cao 54, cách chữ 5, chữ 32/700.
/// Mọi kích thước khác chỉ là tỉ lệ của các số đó.
abstract final class _Design {
  static const asset = 'assets/brand/fore_f.png';

  /// Ảnh gốc 116 x 223.
  static const markAspect = 116 / 223;

  /// Khoảng cách dấu hiệu -> chữ, theo chiều cao dấu hiệu (5 / 54).
  static const gapRatio = 5 / 54;

  /// Cỡ chữ "FORE" theo chiều cao dấu hiệu (32 / 54).
  static const wordRatio = 32 / 54;
  static const wordLineHeight = 1.13;
}

/// Dấu hiệu chữ F. `size` là chiều cao; bề ngang tự theo tỉ lệ ảnh (~0,52).
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size * _Design.markAspect,
        height: size,
        child: Image.asset(
          _Design.asset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.medium,
          excludeFromSemantics: true,
        ),
      );
}

/// Chữ "FORE". `scale` = 1 là cỡ gốc của thiết kế (32 px).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) => Text(
        'FORE',
        semanticsLabel: 'Fore',
        textScaler: TextScaler.noScaling,
        style: AppTextStyles.brandName.copyWith(
          fontSize: 32 * scale,
          height: _Design.wordLineHeight,
          color: AppColors.brand,
        ),
      );
}

/// Dấu hiệu + chữ "FORE" xếp dọc. Dùng ở Splash và màn Chào mừng.
/// Có `Hero` để logo bay mượt từ Splash sang màn Chào mừng.
///
/// `markOpacity` và `wordmarkOpacity` (tùy chọn) cho dấu hiệu và chữ mờ dần
/// RIÊNG. Không truyền thì hiện đầy đủ ngay.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.markSize = 64,
    this.markOpacity,
    this.wordmarkOpacity,
  });

  static const heroTag = 'brand-logo';

  /// Chiều cao cả khối logo + chữ ứng với `markSize` (để Splash canh giữa).
  static double blockHeight(double markSize) =>
      markSize +
      markSize * _Design.gapRatio +
      markSize * _Design.wordRatio * _Design.wordLineHeight;

  /// Chiều cao dấu hiệu; chữ và khoảng cách tự co giãn theo tỉ lệ thiết kế.
  final double markSize;
  final Animation<double>? markOpacity;
  final Animation<double>? wordmarkOpacity;

  static Widget _fade(Animation<double>? opacity, Widget child) =>
      opacity == null ? child : FadeTransition(opacity: opacity, child: child);

  @override
  Widget build(BuildContext context) {
    final scale = markSize * _Design.wordRatio / 32;
    return Hero(
      tag: heroTag,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fade(markOpacity, BrandMark(size: markSize)),
            SizedBox(height: markSize * _Design.gapRatio),
            _fade(wordmarkOpacity, BrandWordmark(scale: scale)),
          ],
        ),
      ),
    );
  }
}
