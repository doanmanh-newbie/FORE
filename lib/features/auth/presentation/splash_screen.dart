import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../application/session_controller.dart';
import 'splash/progress_panel.dart';
import 'splash/shop_stage_card.dart';
import 'splash/splash_backdrop.dart';
import 'splash/splash_footer.dart';
import 'splash/splash_strings.dart';
import 'splash/splash_timeline.dart';
import 'splash/status_pill.dart';

/// Màn mở app / đang kiểm tra đăng nhập, theo thiết kế "Fore — Logo → Loading".
///
/// Hai giai đoạn (chi tiết thời gian xem `SplashTimeline`):
///  1. Mở đầu 1,8 giây, chạy một lần: logo hiện ở giữa màn, rồi trượt lên đầu màn
///     trong lúc phần còn lại (thẻ quầy quán, thanh tiến trình...) hiện dần.
///  2. Lặp trong lúc chờ: thanh tiến trình chạy qua lại, khói bốc từ ly cà phê,
///     chữ "ĐANG KẾT NỐI" nhấp nháy nhẹ. Tất cả theo một nhịp chung.
///
/// Có kết quả kiểm tra thì chuyển trang; `Hero` đưa logo bay sang màn Welcome.
/// Mất mạng: dừng chuyển động, hiện thông báo và nút "Thử lại".
/// Tắt hoạt ảnh trong hệ thống: hiện ngay trạng thái cuối và chuyển ngay khi xong.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  /// Thời gian Splash phải hiện tối thiểu để xem hết phần mở đầu.
  static const introDuration = SplashTimeline.introDuration;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Kích thước dấu hiệu logo ở màn này và chiều cao cả khối logo + chữ
  // (80 + khoảng cách 26,5 + chữ 20,6, tính từ tỉ lệ trong BrandLogo).
  static const _markSize = 80.0;
  static const _logoBlockHeight = 127.0;
  // Khi đã lên đầu màn, logo cách mép trên 10% chiều cao vùng hiển thị
  // (bản thiết kế đặt dấu hiệu ở khoảng 13% chiều cao màn).
  static const _settledTopFraction = 0.10;

  late final SplashTimeline _timeline = SplashTimeline(vsync: this);
  late final SessionController _session = context.read<SessionController>();
  bool _left = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduceMotion = MediaQuery.disableAnimationsOf(context);
      _timeline.start(reduceMotion: _reduceMotion);
      _session.restore(skipMinWait: _reduceMotion);
    });
  }

  void _onSessionChanged() {
    if (_left || !mounted) return;
    final state = _session.state;
    if (state is SessionOffline || state is SessionFailed) {
      _timeline.pauseLoop();
    } else if (state is SessionChecking) {
      _timeline.resumeLoop();
    }
    final next = AppRoutes.routeFor(state);
    if (next == null) return;
    _left = true;
    Navigator.of(context).pushReplacementNamed(next);
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = context.watch<SessionController>().state;
    final offline =
        sessionState is SessionOffline || sessionState is SessionFailed;
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: FadeTransition(
              opacity: _timeline.content,
              child: const SplashBackdrop(),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final settledTop = c.maxHeight * _settledTopFraction;
                return Stack(
                  children: [
                    FadeTransition(
                      opacity: _timeline.content,
                      child: _Content(
                        timeline: _timeline,
                        offline: offline,
                        topReserve: settledTop + _logoBlockHeight + 24,
                        // Thử lại không cần chờ xem lại phần mở đầu.
                        onRetry: () => _session.restore(skipMinWait: true),
                      ),
                    ),
                    _movingLogo(c.maxHeight, settledTop),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Logo: bắt đầu hơi cao hơn tâm màn hình, rồi trượt lên đầu màn.
  Widget _movingLogo(double areaHeight, double settledTop) {
    final startTop = (areaHeight - _logoBlockHeight) / 2 - areaHeight * 0.04;
    return AnimatedBuilder(
      animation: _timeline.lift,
      builder: (context, child) => Positioned(
        top: startTop + (settledTop - startTop) * _timeline.lift.value,
        left: 0,
        right: 0,
        child: child!,
      ),
      child: Center(
        child: BrandLogo(
          markSize: _markSize,
          markOpacity: _timeline.markOpacity,
          wordmarkOpacity: _timeline.wordmarkOpacity,
        ),
      ),
    );
  }
}

/// Phần nội dung bên dưới logo: viên thuốc trạng thái, thẻ quầy quán,
/// khung tiến trình và dòng cuối màn.
class _Content extends StatelessWidget {
  const _Content({
    required this.timeline,
    required this.offline,
    required this.topReserve,
    required this.onRetry,
  });

  final SplashTimeline timeline;
  final bool offline;
  final double topReserve;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.pagePadding + 8),
      child: Column(
        children: [
          SizedBox(height: topReserve),
          StatusPill(
            label:
                offline ? SplashStrings.disconnected : SplashStrings.connecting,
            loop: timeline.loop,
            active: !offline,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ShopStageCard(
              loop: timeline.loop,
              content: timeline.content,
              animateSteam: !offline,
            ),
          ),
          const SizedBox(height: 16),
          ProgressPanel(
            loop: timeline.loop,
            offline: offline,
            onRetry: onRetry,
          ),
          const SizedBox(height: 20),
          const SplashFooter(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
