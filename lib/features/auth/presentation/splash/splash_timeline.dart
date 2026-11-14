import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// "Nhạc trưởng" của màn Loading: giữ MỘT nhịp cho cả màn hình.
///
/// Số liệu lấy từ file thiết kế "Fore — Logo → Loading" (60 fps, giây):
///
/// Phần mở đầu chạy một lần ([intro], 1,8 giây)
///   0,0 đến 0,4   dấu hiệu logo hiện từ 20% lên 100%
///   0,2 đến 0,6   chữ "Fore" hiện dần
///   0,9 đến 1,45  khối logo trượt từ giữa màn lên đầu màn
///   1,25 đến 1,8  mọi thứ còn lại hiện dần (nền, thẻ quầy, thanh tiến trình, chân trang)
///
/// Phần lặp ([loop], 2,4 giây, chạy mãi trong lúc chờ)
///   thanh tiến trình chạy qua lại, chữ "ĐANG KẾT NỐI" nhấp nháy nhẹ,
///   ba làn khói bốc lên so le nhau, các hình trang trí nổi lên xuống.
/// Mọi chuyển động lặp đều được tính từ một giá trị `t` (0 đến 1) của [loop]
/// và có chu kỳ chia đều 2,4 giây, nên không bị giật khi vòng lặp quay về đầu.
class SplashTimeline {
  SplashTimeline({required TickerProvider vsync})
      : intro = AnimationController(vsync: vsync, duration: introDuration),
        loop = AnimationController(vsync: vsync, duration: loopDuration) {
    // 1. LOGO HIỆN RA TỪ TỪ (từ giây 0.0 đến 1.0)
    markOpacity = Tween<double>(begin: 0.2, end: 1).animate(
      CurvedAnimation(parent: intro, curve: _span(0, 1, Curves.easeOut)),
    );
    // 2. CHỮ "FORE" HIỆN RA TỪ TỪ (từ giây 0.5 đến 1.5)
    wordmarkOpacity = CurvedAnimation(
      parent: intro,
      curve: _span(0.8, 1.5, Curves.easeOut),
    );
    // 3. LOGO BAY LÊN ĐẦU MÀN HÌNH (từ giây 1.8 đến 2.8)
    lift = CurvedAnimation(
      parent: intro,
      curve: _span(1.8, 2.8, Curves.easeInOutCubic),
    );
    // 4. CÁC THÀNH PHẦN KHÁC HIỆN RA (từ giây 2.5 đến 3.5)
    content = CurvedAnimation(
      parent: intro,
      curve: _span(2.8, 4, Curves.easeOut),
    );
  }

  /// Thời lượng phần mở đầu. Splash phải hiện ít nhất bấy lâu để xem hết.
  static const introDuration = Duration(milliseconds: 3500);
  static const loopDuration = Duration(milliseconds: 2400);

  static const _introSeconds = 4;

  final AnimationController intro;
  final AnimationController loop;

  /// Dấu hiệu logo (20% đến 100%).
  late final Animation<double> markOpacity;

  /// Chữ "Fore".
  late final Animation<double> wordmarkOpacity;

  /// 0 = logo đang ở giữa màn, 1 = logo đã lên đầu màn.
  late final Animation<double> lift;

  /// Độ hiện của mọi thứ còn lại (nền, thẻ quầy, tiến trình, chân trang).
  late final Animation<double> content;

  bool _reduceMotion = false;

  static Interval _span(double fromSec, double toSec, Curve curve) => Interval(
        fromSec / _introSeconds,
        toSec / _introSeconds,
        curve: curve,
      );

  /// Bắt đầu. Khi người dùng tắt hoạt ảnh: hiện ngay trạng thái cuối, không lặp.
  void start({required bool reduceMotion}) {
    _reduceMotion = reduceMotion;
    if (reduceMotion) {
      intro.value = 1;
      return;
    }
    intro.forward();
    loop.repeat();
  }

  /// Dừng phần lặp (khi mất mạng). Phần đã hiện vẫn giữ nguyên.
  void pauseLoop() => loop.stop();

  /// Chạy lại phần lặp (khi bấm "Thử lại").
  void resumeLoop() {
    if (!_reduceMotion && !loop.isAnimating) loop.repeat();
  }

  void dispose() {
    intro.dispose();
    loop.dispose();
  }

  // ---- Các hàm thuần tính từ t (0 đến 1) của [loop]. Dễ test, không phụ thuộc widget. ----

  /// Vị trí vệt sáng trên thanh tiến trình, 0 (trái) đến 1 (phải), đi rồi về.
  static double sweep(double t) {
    final triangle = t < 0.5 ? t * 2 : (1 - t) * 2;
    return Curves.easeInOut.transform(triangle);
  }

  /// Độ sáng của chữ "ĐANG KẾT NỐI": dao động giữa 0,4 và 1,0, hai lần mỗi vòng.
  static double pillOpacity(double t) =>
      0.7 + 0.3 * math.cos(2 * math.pi * 2 * t);

  /// Tiến trình của một làn khói, 0 đến 1, mỗi làn lệch nhau một phần ba vòng.
  /// Hai đợt khói mỗi vòng lặp.
  static double steamPhase(double t, int strand) {
    final v = 2 * t + strand * 0.33;
    return v - v.floorToDouble();
  }

  /// Dao động nổi lên xuống của hình trang trí, từ -1 đến 1, một lần mỗi vòng.
  static double float(double t) => math.sin(2 * math.pi * t);
}
