import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/greeting.dart';
import '../../../core/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Khoảnh khắc "ca đã mở": vòng tròn tự vẽ, dấu tick hiện ra, vài hạt sáng tỏa
/// ra rồi lời chúc. Tự đóng sau khoảng 2,4 giây. Hoàn thành khi dialog được đóng.
///
/// Tắt hoạt ảnh trong hệ thống: hiện luôn trạng thái cuối, đóng sau 0,9 giây.
Future<void> showShiftOpenedCelebration(
  BuildContext context, {
  required String name,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Ca đã mở',
    barrierColor: Colors.transparent,
    transitionDuration: Motion.of(context, const Duration(milliseconds: 260)),
    pageBuilder: (_, __, ___) => _Celebration(name: name),
    transitionBuilder: (_, animation, __, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({required this.name});

  final String name;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );
  Timer? _closeTimer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduced = Motion.reduced(context);
    if (reduced) {
      _c.value = 1;
    } else {
      _c.forward();
      // Rung một nhịp đúng lúc dấu tick hoàn thành.
      Timer(const Duration(milliseconds: 950), HapticFeedback.mediumImpact);
    }
    _closeTimer = Timer(
      Duration(milliseconds: reduced ? 900 : 2400),
      () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = 'Chúc ${shortName(widget.name)} '
        '${partOfDay(DateTime.now())} làm việc thuận lợi.';
    return Material(
      color: AppColors.brand,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final textT = Curves.easeOut.transform(
              ((t - 0.62) / 0.3).clamp(0.0, 1.0),
            );
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 220,
                  child: CustomPaint(painter: _TickPainter(t)),
                ),
                const SizedBox(height: 12),
                Opacity(
                  opacity: textT,
                  child: Transform.translate(
                    offset: Offset(0, 14 * (1 - textT)),
                    child: Column(
                      children: [
                        Text(
                          'Ca đã mở',
                          style: AppTextStyles.display.copyWith(
                            color: AppColors.onInk,
                            fontSize: AppFontSizes.s38,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 40),
                          child: Text(
                            greeting,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppFontSizes.s16,
                              height: 1.4,
                              color: AppColors.onSurfaceStrong,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Vẽ theo `t` từ 0 đến 1:
///  0,00 đến 0,50  vòng tròn được vẽ dần
///  0,40 đến 0,62  dấu tick được vẽ dần
///  0,55 đến 1,00  các hạt sáng tỏa ra và mờ đi
class _TickPainter extends CustomPainter {
  _TickPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const radius = 56.0;

    // Quầng sáng phía sau.
    final glow = Curves.easeOut.transform((t / 0.5).clamp(0.0, 1.0));
    canvas.drawCircle(
      center,
      radius + 30 * glow,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.brandAccent.withValues(alpha: 0.35 * glow),
            AppColors.brandAccent.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius + 34)),
    );

    final ring = Curves.easeInOutCubic.transform((t / 0.5).clamp(0.0, 1.0));
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * ring,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = AppColors.brandAccent,
    );

    final tick = Curves.easeOut.transform(((t - 0.4) / 0.22).clamp(0.0, 1.0));
    if (tick > 0) {
      final path = Path()
        ..moveTo(center.dx - 22, center.dy + 2)
        ..lineTo(center.dx - 6, center.dy + 18)
        ..lineTo(center.dx + 24, center.dy - 16);
      for (final metric in path.computeMetrics()) {
        canvas.drawPath(
          metric.extractPath(0, metric.length * tick),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = AppColors.onInk,
        );
      }
    }

    final burst = ((t - 0.55) / 0.45).clamp(0.0, 1.0);
    if (burst > 0 && burst < 1) {
      final eased = Curves.easeOutCubic.transform(burst);
      for (var i = 0; i < 14; i++) {
        final angle = 2 * math.pi * i / 14 + (i.isEven ? 0.12 : -0.12);
        final distance = radius + 14 + (i.isEven ? 44 : 30) * eased;
        final dot = Offset(
          center.dx + math.cos(angle) * distance,
          center.dy + math.sin(angle) * distance,
        );
        canvas.drawCircle(
          dot,
          (i.isEven ? 4.0 : 2.6) * (1 - burst * 0.6),
          Paint()
            ..color = (i % 3 == 0 ? AppColors.onInk : AppColors.brandAccent)
                .withValues(alpha: 1 - burst),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TickPainter oldDelegate) => oldDelegate.t != t;
}
