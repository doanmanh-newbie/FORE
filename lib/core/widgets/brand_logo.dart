import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Logo Fore: hình học, màu và tỉ lệ lấy nguyên từ file Lottie của thiết kế
/// ("Fore — Logo.json"). Vẽ bằng code nên sắc nét ở mọi kích thước, không cần
/// file ảnh, không cần font (thiết kế dùng Arial Bold, Android không có sẵn).
///
/// Số đo gốc của thiết kế (px): dấu hiệu 76 x 79; chữ "Fore" cao 20 (chữ hoa),
/// rộng 58,2, đặt cách đáy dấu hiệu 26,2. Mọi kích thước khác chỉ là tỉ lệ của
/// các số đó, nên logo luôn đúng bố cục dù to hay nhỏ.
///
/// Màu dấu hiệu là màu của logo, KHÔNG phải token giao diện: `AppColors.brandAccent`
/// (0xFF3F9E92) đang là số ước lượng từ ảnh, còn teal của logo là 0xFF51A19B.
/// Khi có bảng màu chính thức của thiết kế, cân nhắc thống nhất hai màu này.

Color get _dark => AppColors.brand;
Color get _teal => AppColors.brandAccent;
Color get _star => AppColors.background;

/// Số đo gốc (px thiết kế) dùng để tính tỉ lệ.
abstract final class _Design {
  static const markWidth = 76.0;
  static const markHeight = 79.0;

  /// Từ đáy dấu hiệu tới đỉnh chữ hoa.
  static const gapToCap = 26.2;

  /// Chữ hoa cao 20,04; chữ tròn (o, e) tràn dưới đường cơ sở thêm 0,33.
  static const capHeight = 20.04;
  static const wordHeight = 20.37;
  static const wordWidth = 58.24;
}

class _MarkLayer {
  const _MarkLayer(this.color, this.paths);

  final Color color;
  final List<Path> paths;
}

/// Các lớp của dấu hiệu, xếp từ DƯỚI lên TRÊN (đúng thứ tự trong file thiết kế).
abstract final class _MarkShapes {
  static final layers = <_MarkLayer>[
    _MarkLayer(_dark, _gem),
    _MarkLayer(_teal, _facets),
    _MarkLayer(_dark, _arms),
    _MarkLayer(_teal, _head),
    _MarkLayer(_star, _sparkle),
  ];

  // gem (Khối kim cương) _dark
  static final _gem = <Path>[
    Path()
      ..moveTo(0.0000, 43.4500)
      ..lineTo(19.0000, 23.7000)
      ..lineTo(38.0000, 37.9200)
      ..lineTo(57.0000, 23.7000)
      ..lineTo(76.0000, 43.4500)
      ..lineTo(38.0000, 79.0000)
      ..close(),
  ];
  // facets (Mặt cắt) _teal
  static final _facets = <Path>[
    Path()
      ..moveTo(0.0000, 43.4500)
      ..lineTo(19.0000, 23.7000)
      ..lineTo(27.3600, 33.9700)
      ..lineTo(17.4800, 43.4500)
      ..close(),
    Path()
      ..moveTo(76.0000, 43.4500)
      ..lineTo(57.0000, 23.7000)
      ..lineTo(48.6400, 33.9700)
      ..lineTo(58.5200, 43.4500)
      ..close(),
    Path()
      ..moveTo(0.0000, 43.4500)
      ..lineTo(17.4800, 43.4500)
      ..lineTo(38.0000, 79.0000)
      ..close(),
    Path()
      ..moveTo(76.0000, 43.4500)
      ..lineTo(58.5200, 43.4500)
      ..lineTo(38.0000, 79.0000)
      ..close(),
  ];
  // arms (Vòng tay) _dark
  static final _arms = <Path>[
    Path()
      ..moveTo(10.6400, 0.0000)
      ..lineTo(15.2000, 0.0000)
      ..cubicTo(18.2400, 14.2200, 26.6000, 22.1200, 38.0000, 22.1200)
      ..cubicTo(49.4000, 22.1200, 57.7600, 14.2200, 60.8000, 0.0000)
      ..lineTo(65.3600, 0.0000)
      ..cubicTo(63.0800, 18.9600, 51.6800, 33.1800, 43.3200, 33.9700)
      ..lineTo(32.6800, 33.9700)
      ..cubicTo(24.3200, 33.1800, 12.9200, 18.9600, 10.6400, 0.0000)
      ..close(),
  ];
  // head (Tâm tròn) _teal
  static final _head = <Path>[
    Path()
      ..moveTo(38.0000, 18.9600)
      ..cubicTo(42.6171, 18.9600, 46.3600, 15.0694, 46.3600, 10.2700)
      ..cubicTo(46.3600, 5.4706, 42.6171, 1.5800, 38.0000, 1.5800)
      ..cubicTo(33.3829, 1.5800, 29.6400, 5.4706, 29.6400, 10.2700)
      ..cubicTo(29.6400, 15.0694, 33.3829, 18.9600, 38.0000, 18.9600)
      ..close(),
  ];
  // star (Ngôi sao) _star
  static final _sparkle = <Path>[
    Path()
      ..moveTo(38.0000, 42.6600)
      ..lineTo(41.0400, 51.3500)
      ..lineTo(49.4000, 54.5100)
      ..lineTo(41.0400, 57.6700)
      ..lineTo(38.0000, 66.3600)
      ..lineTo(34.9600, 57.6700)
      ..lineTo(26.6000, 54.5100)
      ..lineTo(34.9600, 51.3500)
      ..close(),
  ];
}

/// Dấu hiệu (hình người giơ tay trên viên kim cương). `size` là chiều cao.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: _MarkPainter()),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / _Design.markHeight;
    canvas
      ..save()
      ..translate((size.width - _Design.markWidth * scale) / 2, 0)
      ..scale(scale);
    for (final layer in _MarkShapes.layers) {
      final paint = Paint()..color = layer.color;
      for (final path in layer.paths) {
        canvas.drawPath(path, paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Đường viền chữ "Fore" (Arial Bold 28 px, giãn chữ -0,029 em) lấy từ file thiết kế.
/// Gốc tọa độ: đường cơ sở của chữ, trục y hướng xuống (chữ nằm ở y âm).
abstract final class _WordmarkShapes {
  static final glyphs = Path()
    ..fillType = PathFillType.evenOdd
    ..addPath(
      Path()
        ..moveTo(2.064, 0.000)
        ..lineTo(2.064, -20.043)
        ..lineTo(15.805, -20.043)
        ..lineTo(15.805, -16.652)
        ..lineTo(6.111, -16.652)
        ..lineTo(6.111, -11.908)
        ..lineTo(14.479, -11.908)
        ..lineTo(14.479, -8.518)
        ..lineTo(6.111, -8.518)
        ..lineTo(6.111, 0.000)
        ..close(),
      Offset.zero,
    )
    ..addPath(
      Path()
        ..moveTo(17.413, -7.465)
        ..cubicTo(17.413, -8.741, 17.727, -9.976, 18.356, -11.170)
        ..cubicTo(18.985, -12.364, 19.874, -13.275, 21.022, -13.904)
        ..cubicTo(22.180, -14.533, 23.469, -14.848, 24.891, -14.848)
        ..cubicTo(27.088, -14.848, 28.888, -14.132, 30.292, -12.701)
        ..cubicTo(31.695, -11.279, 32.397, -9.479, 32.397, -7.301)
        ..cubicTo(32.397, -5.104, 31.686, -3.281, 30.264, -1.832)
        ..cubicTo(28.851, -0.392, 27.070, 0.328, 24.918, 0.328)
        ..cubicTo(23.588, 0.328, 22.316, 0.027, 21.104, -0.574)
        ..cubicTo(19.901, -1.176, 18.985, -2.055, 18.356, -3.213)
        ..cubicTo(17.727, -4.380, 17.413, -5.797, 17.413, -7.465)
        ..close(),
      Offset.zero,
    )
    ..addPath(
      Path()
        ..moveTo(21.350, -7.260)
        ..cubicTo(21.350, -5.820, 21.692, -4.717, 22.376, -3.951)
        ..cubicTo(23.059, -3.186, 23.902, -2.803, 24.905, -2.803)
        ..cubicTo(25.907, -2.803, 26.746, -3.186, 27.420, -3.951)
        ..cubicTo(28.104, -4.717, 28.446, -5.829, 28.446, -7.287)
        ..cubicTo(28.446, -8.709, 28.104, -9.803, 27.420, -10.568)
        ..cubicTo(26.746, -11.334, 25.907, -11.717, 24.905, -11.717)
        ..cubicTo(23.902, -11.717, 23.059, -11.334, 22.376, -10.568)
        ..cubicTo(21.692, -9.803, 21.350, -8.700, 21.350, -7.260)
        ..close(),
      Offset.zero,
    )
    ..addPath(
      Path()
        ..moveTo(38.271, 0.000)
        ..lineTo(34.429, 0.000)
        ..lineTo(34.429, -14.520)
        ..lineTo(37.997, -14.520)
        ..lineTo(37.997, -12.455)
        ..cubicTo(38.608, -13.430, 39.155, -14.073, 39.638, -14.383)
        ..cubicTo(40.130, -14.693, 40.686, -14.848, 41.306, -14.848)
        ..cubicTo(42.181, -14.848, 43.024, -14.606, 43.835, -14.123)
        ..lineTo(42.646, -10.773)
        ..cubicTo(41.998, -11.193, 41.397, -11.402, 40.841, -11.402)
        ..cubicTo(40.303, -11.402, 39.847, -11.252, 39.474, -10.951)
        ..cubicTo(39.100, -10.660, 38.804, -10.126, 38.585, -9.352)
        ..cubicTo(38.375, -8.577, 38.271, -6.954, 38.271, -4.484)
        ..close(),
      Offset.zero,
    )
    ..addPath(
      Path()
        ..moveTo(53.085, -4.621)
        ..lineTo(56.914, -3.979)
        ..cubicTo(56.421, -2.575, 55.642, -1.504, 54.576, -0.766)
        ..cubicTo(53.518, -0.036, 52.192, 0.328, 50.597, 0.328)
        ..cubicTo(48.072, 0.328, 46.204, -0.497, 44.992, -2.146)
        ..cubicTo(44.035, -3.468, 43.556, -5.136, 43.556, -7.150)
        ..cubicTo(43.556, -9.557, 44.185, -11.439, 45.443, -12.797)
        ..cubicTo(46.701, -14.164, 48.291, -14.848, 50.214, -14.848)
        ..cubicTo(52.375, -14.848, 54.079, -14.132, 55.328, -12.701)
        ..cubicTo(56.576, -11.279, 57.173, -9.096, 57.119, -6.152)
        ..lineTo(47.494, -6.152)
        ..cubicTo(47.521, -5.013, 47.831, -4.124, 48.423, -3.486)
        ..cubicTo(49.016, -2.857, 49.754, -2.543, 50.638, -2.543)
        ..cubicTo(51.240, -2.543, 51.746, -2.707, 52.156, -3.035)
        ..cubicTo(52.566, -3.363, 52.876, -3.892, 53.085, -4.621)
        ..close(),
      Offset.zero,
    )
    ..addPath(
      Path()
        ..moveTo(53.304, -8.504)
        ..cubicTo(53.277, -9.616, 52.990, -10.459, 52.443, -11.033)
        ..cubicTo(51.896, -11.617, 51.231, -11.908, 50.447, -11.908)
        ..cubicTo(49.608, -11.908, 48.916, -11.603, 48.369, -10.992)
        ..cubicTo(47.822, -10.382, 47.553, -9.552, 47.562, -8.504)
        ..close(),
      Offset.zero,
    );
}

/// Chữ "Fore". `scale` = 1 là cỡ gốc của thiết kế (chữ hoa cao 20 px).
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Fore',
        child: SizedBox(
          width: _Design.wordWidth * scale,
          height: _Design.wordHeight * scale,
          child: const CustomPaint(painter: _WordmarkPainter()),
        ),
      );
}

class _WordmarkPainter extends CustomPainter {
  const _WordmarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / _Design.wordWidth;
    canvas
      ..save()
      ..translate(0, _Design.capHeight * scale)
      ..scale(scale);
    canvas.drawPath(_WordmarkShapes.glyphs, Paint()..color = AppColors.brand);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dấu hiệu + chữ "Fore". Dùng ở Splash, Welcome, Đăng nhập.
/// Có `Hero` để logo bay mượt từ Splash sang Welcome.
///
/// `markOpacity` và `wordmarkOpacity` (tùy chọn) cho dấu hiệu và chữ mờ dần
/// RIÊNG, đúng như chuyển động của thiết kế. Không truyền thì hiện đầy đủ ngay.
class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.markSize = 64,
    this.markOpacity,
    this.wordmarkOpacity,
  });

  static const heroTag = 'brand-logo';

  /// Chiều cao dấu hiệu; chữ và khoảng cách tự co giãn theo tỉ lệ thiết kế.
  final double markSize;
  final Animation<double>? markOpacity;
  final Animation<double>? wordmarkOpacity;

  static Widget _fade(Animation<double>? opacity, Widget child) =>
      opacity == null ? child : FadeTransition(opacity: opacity, child: child);

  @override
  Widget build(BuildContext context) {
    final scale = markSize / _Design.markHeight;
    return Hero(
      tag: heroTag,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _fade(markOpacity, BrandMark(size: markSize)),
            SizedBox(height: _Design.gapToCap * scale),
            _fade(wordmarkOpacity, BrandWordmark(scale: scale)),
          ],
        ),
      ),
    );
  }
}
