import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_routes.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/format.dart';
import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/brand_logo.dart';
import '../../core/widgets/fade_slide_in.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/fore_button.dart';
import '../../core/widgets/fore_icon.dart';
import '../../core/widgets/minute_ticker.dart';
import '../../core/widgets/pulse_dot.dart';
import '../auth/application/session_controller.dart';
import '../shift/application/shift_controller.dart';
import '../shift/domain/shift_models.dart';
import '../../core/widgets/lazy_list_view.dart';

/// Tab Trang chủ của nhân viên: tình trạng ca và lối vào các việc chính.
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>().state;
    final name = session is SessionSignedIn ? session.profile.fullName : '';
    final shop = session is SessionSignedIn ? session.profile.shopName : '';
    final isOwner = session is SessionSignedIn && session.profile.role.isOwner;
    final shift = context.watch<ShiftController>().state;

    return Column(
      children: [
        _Header(name: name, shop: shop, isOwner: isOwner, shift: shift),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.brand,
            onRefresh: () => context.read<ShiftController>().load(quiet: true),
            child: LazyListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(
                    context,
                    const Duration(milliseconds: 420),
                  ),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: switch (shift) {
                    ShiftLoading() => const _LoadingCard(key: ValueKey('l')),
                    ShiftNone() => const _NoShiftCard(key: ValueKey('n')),
                    ShiftOpen(shift: final open) => _OpenShiftCard(
                        key: const ValueKey('o'),
                        shift: open,
                      ),
                    ShiftLoadFailed(:final failure) => _FailedCard(
                        key: const ValueKey('f'),
                        message: failure.userMessage,
                      ),
                  },
                ),
                const SizedBox(height: 16),
                FadeSlideIn(
                  delay: const Duration(milliseconds: 500),
                  child: _FootNote(shift: shift),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Dải trắng đầu màn: tên app, người dùng, logo và viên thuốc trạng thái ca.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.shop,
    required this.isOwner,
    required this.shift,
  });

  final String name;
  final String shop;
  final bool isOwner;
  final ShiftState shift;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final open = shift is ShiftOpen;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowSubtle,
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, top + 14, 20, 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Fore',
                        style: AppTextStyles.display
                            .copyWith(fontSize: AppFontSizes.s32),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (shop.isNotEmpty) shop,
                          if (name.isNotEmpty)
                            '${isOwner ? 'Chủ quán' : 'Nhân viên'} $name',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.label.copyWith(
                          fontSize: AppFontSizes.s14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const _FloatingMark(),
              ],
            ),
            const SizedBox(height: 14),
            _StatusPill(open: open, loading: shift is ShiftLoading),
          ],
        ),
      ),
    );
  }
}

/// Logo ở góc phải, nhấp nhô rất nhẹ như đang thở. Tắt hoạt ảnh thì đứng yên.
class _FloatingMark extends StatefulWidget {
  const _FloatingMark();

  @override
  State<_FloatingMark> createState() => _FloatingMarkState();
}

class _FloatingMarkState extends State<_FloatingMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3200),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -3 + 6 * Curves.easeInOut.transform(_c.value)),
        child: child,
      ),
      child: const BrandMark(size: 44),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.open, required this.loading});

  final bool open;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'Đang kiểm tra ca'
        : open
            ? 'Đang mở ca'
            : 'Chưa mở ca';
    return AnimatedContainer(
      duration: Motion.of(context, const Duration(milliseconds: 300)),
      padding: const EdgeInsets.fromLTRB(8, 2, 16, 2),
      decoration: BoxDecoration(
        color: open ? AppColors.healthyBackground : AppColors.tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseDot(
            color: open ? AppColors.statusOk : AppColors.inkMuted,
            pulsing: open || loading,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: AppFontSizes.s14,
              fontWeight: FontWeight.w600,
              color: AppColors.brand,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({super.key});

  @override
  Widget build(BuildContext context) => ForeCard(
        child: SizedBox(
          height: 240,
          child: Center(
            child: SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppColors.brand,
              ),
            ),
          ),
        ),
      );
}

/// Chưa có ca: mời mở ca. Icon lịch nhịp nhẹ để mắt dừng ở đó trước.
class _NoShiftCard extends StatelessWidget {
  const _NoShiftCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ForeCard(
      child: Column(
        children: [
          const SizedBox(height: 12),
          FadeSlideIn(
            child: _BreathingIcon(
              child: ForeIconView(
                ForeIcon.calendar,
                size: 40,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: Text(
              'Chưa có ca đang mở',
              textAlign: TextAlign.center,
              style: AppTextStyles.heading,
            ),
          ),
          const SizedBox(height: 8),
          FadeSlideIn(
            delay: const Duration(milliseconds: 220),
            child: Text(
              'Mở ca để nhận order và dùng các chức năng bán hàng.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
          ),
          const SizedBox(height: 36),
          FadeSlideIn(
            delay: const Duration(milliseconds: 340),
            child: ForeButton(
              label: 'Mở ca',
              onPressed: () =>
                  Navigator.of(context).pushNamed(AppRoutes.openShift),
            ),
          ),
        ],
      ),
    );
  }
}

class _BreathingIcon extends StatefulWidget {
  const _BreathingIcon({required this.child});

  final Widget child;

  @override
  State<_BreathingIcon> createState() => _BreathingIconState();
}

class _BreathingIconState extends State<_BreathingIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.tint,
            boxShadow: [
              BoxShadow(
                color: AppColors.brandAccent.withValues(alpha: 0.18 * t),
                blurRadius: 10 + 18 * t,
                spreadRadius: 2 * t,
              ),
            ],
          ),
          child: Padding(padding: const EdgeInsets.all(22), child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Có ca: đồng hồ ca chạy, ai mở, mấy bill đang mở, nút vào ca.
class _OpenShiftCard extends StatelessWidget {
  const _OpenShiftCard({super.key, required this.shift});

  final CurrentShift shift;

  @override
  Widget build(BuildContext context) {
    final byLine = shift.openedByMe
        ? 'Bạn mở lúc ${formatHm(shift.openedAt)}'
        : '${shift.openedByName} mở lúc ${formatHm(shift.openedAt)}';
    return ForeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ca đang mở', style: AppTextStyles.heading),
          const SizedBox(height: 6),
          MinuteTicker(
            builder: (context, now) => TweenAnimationBuilder<double>(
              tween: Tween(
                begin: 0,
                end: now.difference(shift.openedAt).inMinutes.toDouble(),
              ),
              duration: Motion.of(
                context,
                const Duration(milliseconds: 900),
              ),
              curve: Curves.easeOutCubic,
              builder: (context, minutes, _) => Text(
                formatElapsed(Duration(minutes: minutes.round())),
                style:
                    AppTextStyles.display.copyWith(fontSize: AppFontSizes.s38),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(byLine, style: AppTextStyles.body),
          const SizedBox(height: 18),
          _BillsChip(count: shift.openBills),
          const SizedBox(height: 28),
          ForeButton(
            label: 'Vào ca',
            onPressed: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Màn bán hàng đang được làm ở bước sau.'),
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class _BillsChip extends StatelessWidget {
  const _BillsChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final has = count > 0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: has ? AppColors.warningSoft : AppColors.tint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (has) ...[
              ForeIconView(
                ForeIcon.warning,
                size: 18,
                color: AppColors.warning,
              ),
              const SizedBox(width: 8),
            ],
            Text(
              has ? '$count bill đang mở' : 'Không có bill đang mở',
              style: TextStyle(
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w600,
                color: has ? AppColors.warningText : AppColors.brand,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ForeCard(
      child: Column(
        children: [
          ForeIconView(
            ForeIcon.warning,
            size: 36,
            color: AppColors.warning,
          ),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge,
          ),
          const SizedBox(height: 24),
          ForeButton(
            label: 'Thử lại',
            onPressed: () => context.read<ShiftController>().load(),
          ),
        ],
      ),
    );
  }
}

/// Dòng nhỏ dưới thẻ.
class _FootNote extends StatelessWidget {
  const _FootNote({required this.shift});

  final ShiftState shift;

  @override
  Widget build(BuildContext context) {
    final text = switch (shift) {
      ShiftNone() => 'Bàn, Mang đi và Kho dùng được sau khi mở ca.',
      ShiftOpen() => 'Kéo xuống để làm mới trạng thái ca.',
      _ => '',
    };
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppTextStyles.body
          .copyWith(color: AppColors.brand, fontSize: AppFontSizes.s14),
    );
  }
}
