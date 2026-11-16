import 'package:flutter/material.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/errors/failure_messages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'splash_strings.dart';
import 'splash_timeline.dart';

/// Khung ở cuối màn: lúc chờ là thanh tiến trình chạy qua lại kèm dòng
/// "Đang kiểm tra đăng nhập."; khi mất mạng đổi thành thông báo và nút "Thử lại".
class ProgressPanel extends StatelessWidget {
  const ProgressPanel({
    super.key,
    required this.loop,
    required this.offline,
    required this.onRetry,
  });

  final Animation<double> loop;
  final bool offline;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: SizedBox(
          width: double.infinity,
          child: offline ? _Offline(onRetry: onRetry) : _Checking(loop: loop),
        ),
      ),
    );
  }
}

class _Checking extends StatelessWidget {
  const _Checking({required this.loop});

  final Animation<double> loop;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SweepProgress(loop: loop),
          const SizedBox(height: 14),
          Text(SplashStrings.checking, style: AppTextStyles.body),
        ],
      );
}

class _Offline extends StatelessWidget {
  const _Offline({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, color: AppColors.textSecondary),
          const SizedBox(height: 8),
          Text(
            const NoNetworkFailure().userMessage,
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onRetry,
            child: const Text(SplashStrings.retry),
          ),
        ],
      );
}

/// Thanh tiến trình mảnh (152 x 4): vệt đậm chiếm 40% bề rộng, chạy qua lại.
class SweepProgress extends StatelessWidget {
  const SweepProgress({super.key, required this.loop});

  final Animation<double> loop;

  static const _width = 152.0;
  static const _height = 4.0;
  static const _highlightFraction = 60.65 / 152;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: _height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(_height / 2),
        ),
        child: AnimatedBuilder(
          animation: loop,
          builder: (context, child) => Align(
            alignment: Alignment(2 * SplashTimeline.sweep(loop.value) - 1, 0),
            child: child,
          ),
          child: FractionallySizedBox(
            widthFactor: _highlightFraction,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(_height / 2),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }
}
