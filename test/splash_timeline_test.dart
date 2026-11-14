import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/presentation/splash/splash_timeline.dart';

void main() {
  test('thời lượng mở đầu 3,5 giây, vòng lặp 2,4 giây', () {
    expect(SplashTimeline.introDuration, const Duration(milliseconds: 3500));
    expect(SplashTimeline.loopDuration, const Duration(milliseconds: 2400));
  });

  test('sweep: đi sang phải rồi quay về, đầu và cuối vòng cùng ở mép trái', () {
    expect(SplashTimeline.sweep(0), closeTo(0, 1e-9));
    expect(SplashTimeline.sweep(0.5), closeTo(1, 1e-9));
    expect(SplashTimeline.sweep(1), closeTo(0, 1e-9));
    expect(
      SplashTimeline.sweep(0.25),
      closeTo(SplashTimeline.sweep(0.75), 1e-9),
    );
  });

  test('pillOpacity luôn trong khoảng 0,4 đến 1 và liền mạch ở chỗ nối vòng', () {
    for (var i = 0; i <= 100; i++) {
      final v = SplashTimeline.pillOpacity(i / 100);
      expect(v, inInclusiveRange(0.4 - 1e-9, 1.0 + 1e-9));
    }
    expect(
      SplashTimeline.pillOpacity(0),
      closeTo(SplashTimeline.pillOpacity(1), 1e-9),
    );
  });

  test('steamPhase nằm trong [0,1) và các làn khói lệch pha nhau', () {
    for (var strand = 0; strand < 3; strand++) {
      for (var i = 0; i <= 100; i++) {
        final p = SplashTimeline.steamPhase(i / 100, strand);
        expect(p, inInclusiveRange(0, 1));
      }
      // Nối vòng liền mạch: t = 0 và t = 1 cùng một pha.
      expect(
        SplashTimeline.steamPhase(0, strand),
        closeTo(SplashTimeline.steamPhase(1, strand), 1e-9),
      );
    }
    expect(
      SplashTimeline.steamPhase(0.2, 0),
      isNot(closeTo(SplashTimeline.steamPhase(0.2, 1), 1e-6)),
    );
  });

  test('float dao động từ -1 đến 1 và nối vòng liền mạch', () {
    expect(SplashTimeline.float(0), closeTo(0, 1e-9));
    expect(SplashTimeline.float(0.25), closeTo(1, 1e-9));
    expect(SplashTimeline.float(1), closeTo(0, 1e-9));
  });
}
