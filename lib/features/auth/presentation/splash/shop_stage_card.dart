import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/theme/app_colors.dart';
import 'splash_strings.dart';
import 'splash_timeline.dart';
import 'package:fore/core/design/typography.dart';

/// Thẻ "Không gian quán đã sẵn sàng": hình quầy quán ở giữa, khói bốc từ ly,
/// lá và hạt cà phê trang trí nổi nhẹ ở hai bên.
class ShopStageCard extends StatelessWidget {
  const ShopStageCard({
    super.key,
    required this.loop,
    required this.content,
    required this.animateSteam,
  });

  final Animation<double> loop;

  /// Tiến trình hiện ra (0 đến 1): hình quầy trượt lên 12 px khi hiện.
  final Animation<double> content;

  /// `false` khi mất mạng: khói dừng và ẩn.
  final bool animateSteam;

  static const _illustrationSize = Size(142, 72);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Stack(
          children: [
            // Lá (trái, dưới) và hạt cà phê (phải, dưới): rất nhạt.
            const Positioned(left: -14, bottom: -18, child: _Leaf()),
            Positioned(
              right: 20,
              bottom: 26,
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 3 * SplashTimeline.float(loop.value)),
                  child: child,
                ),
                child: Opacity(
                  opacity: 0.55,
                  child: SvgPicture.asset('assets/splash/beans.svg'),
                ),
              ),
            ),
            const Positioned(left: 16, top: 16, child: _Title()),
            Center(
              child: AnimatedBuilder(
                animation: content,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, 12 * (1 - content.value)),
                  child: child,
                ),
                child: SizedBox.fromSize(
                  size: _illustrationSize,
                  child: Stack(
                    children: [
                      SvgPicture.asset('assets/splash/cafe_illustration.svg'),
                      if (animateSteam)
                        Positioned.fill(
                          child: CustomPaint(painter: _SteamPainter(loop)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandAccent,
            ),
            child: const SizedBox.square(dimension: 6),
          ),
          const SizedBox(width: 8),
          Text(
            SplashStrings.stageTitle,
            style: TextStyle(
              fontSize: AppFontSizes.s12,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
        ],
      );
}

class _Leaf extends StatelessWidget {
  const _Leaf();

  @override
  Widget build(BuildContext context) => Opacity(
        opacity: 0.3,
        child: Stack(
          children: [
            SvgPicture.asset('assets/splash/leaf.svg'),
            Positioned(
              left: 10,
              top: 10,
              child: SvgPicture.asset('assets/splash/leaf_veins.svg'),
            ),
          ],
        ),
      );
}

/// Ba làn khói trên ly cà phê. Hình dạng lấy từ SteamAnimation.svg của thiết kế
/// (hệ tọa độ 142 x 72). Mỗi làn bốc lên 8 px, sáng dần rồi mờ, các làn lệch nhau.
class _SteamPainter extends CustomPainter {
  _SteamPainter(this.loop) : super(repaint: loop);

  final Animation<double> loop;

  // (x, y đáy, độ đậm tối đa)
  static const _strands = [
    (99.6231, 33.9326, 0.545),
    (107.238, 32.8461, 0.411),
    (111.873, 39.1809, 0.483),
  ];

  static Path _strand(double x, double y) => Path()
    ..moveTo(x, y)
    ..cubicTo(x - 2.666, y - 2.666, x - 2.666, y - 5.332, x, y - 7.998)
    ..cubicTo(x + 2.666, y - 10.664, x + 2.666, y - 13.33, x, y - 15.997);

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < _strands.length; i++) {
      final (x, y, peak) = _strands[i];
      final phase = SplashTimeline.steamPhase(loop.value, i);
      // Sáng dần tới giữa đợt rồi mờ đi: từ 10% lên tối đa rồi về 10%.
      final fade = (1 - (2 * phase - 1).abs());
      final opacity = 0.1 + (peak - 0.1) * fade;
      canvas
        ..save()
        ..translate(0, -8 * phase)
        ..drawPath(
          _strand(x, y),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..color = AppColors.brandAccent.withValues(alpha: opacity),
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _SteamPainter oldDelegate) =>
      oldDelegate.loop != loop;
}
