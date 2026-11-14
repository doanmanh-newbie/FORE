import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';

/// Nền trang trí của màn Loading: bốn đốm tròn ở bốn góc và các cung tròn mảnh
/// ở góc phải trên. Rất nhạt, chỉ để màn hình bớt trống, không giành chú ý.
/// Vị trí tính theo tỉ lệ màn hình; chỉnh các hằng số dưới đây nếu muốn dịch chuyển.
class SplashBackdrop extends StatelessWidget {
  const SplashBackdrop({super.key});

  static const _arcOpacity = 0.2;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) => Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          const Positioned.fill(child: CustomPaint(painter: _BlobPainter())),
          Positioned(
            left: c.maxWidth * 0.62,
            top: -c.maxHeight * 0.005,
            child: const _Faint(asset: 'assets/splash/arc_large.svg'),
          ),
          Positioned(
            left: c.maxWidth * 0.66,
            top: c.maxHeight * 0.12,
            child: const _Faint(asset: 'assets/splash/arc_small.svg'),
          ),
        ],
      ),
    );
  }
}

class _Faint extends StatelessWidget {
  const _Faint({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: SplashBackdrop._arcOpacity,
        child: ClipRect(child: SvgPicture.asset(asset)),
      );
}

/// Bốn đốm tròn mờ ở góc (độ đậm 6 đến 12% như bản thiết kế).
class _BlobPainter extends CustomPainter {
  const _BlobPainter();

  @override
  void paint(Canvas canvas, Size size) {
    void blob(Offset center, double radius, double opacity) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = AppColors.brandAccent.withValues(alpha: opacity),
      );
    }

    blob(const Offset(0, 0), 52, 0.12);
    blob(Offset(size.width, 0), 36, 0.08);
    blob(Offset(0, size.height * 0.9), 40, 0.10);
    blob(Offset(size.width, size.height * 0.94), 32, 0.06);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
