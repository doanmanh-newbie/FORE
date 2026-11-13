import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/format.dart';
import '../../../core/motion.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/vnd_words.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/fade_slide_in.dart';
import '../../../core/widgets/fore_button.dart';
import '../../../core/widgets/fore_icon.dart';
import '../../../core/widgets/minute_ticker.dart';
import '../../../core/widgets/shake.dart';
import '../../auth/application/session_controller.dart';
import '../application/shift_controller.dart';
import '../domain/shift_models.dart';
import 'shift_opened_celebration.dart';

/// Mở ca: nhập số tiền mặt đếm được trong két.
///
/// Ba trạng thái trên cùng một màn:
///  - nhập tiền (ô để trống, không điền sẵn để người dùng phải đếm thật),
///  - lỗi nhập (ô lắc nhẹ, chữ báo lỗi đổi sang màu cảnh báo),
///  - "Vào ca đang mở": người khác đã mở ca trước, chỉ cần vào ca đó.
/// Nguyên liệu không nhập ở đây: tồn đầu lấy từ số đã đếm lúc đóng ca trước.
class OpenShiftScreen extends StatefulWidget {
  const OpenShiftScreen({super.key});

  @override
  State<OpenShiftScreen> createState() => _OpenShiftScreenState();
}

class _OpenShiftScreenState extends State<OpenShiftScreen> {
  final _cash = TextEditingController();
  final _focus = FocusNode();

  /// Đang trong lượt bấm "Mở ca" (kể cả lúc chiếu hiệu ứng chúc mừng).
  /// Trong lúc đó không chuyển sang màn "Vào ca đang mở" dù trạng thái đã có ca.
  bool _submitting = false;
  int _errorTick = 0;

  @override
  void initState() {
    super.initState();
    // Biết sớm nếu người khác vừa mở ca, khỏi để người dùng nhập xong mới thấy.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShiftController>().load(quiet: true);
    });
  }

  @override
  void dispose() {
    _cash.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _myName {
    final state = context.read<SessionController>().state;
    return state is SessionSignedIn ? state.profile.fullName : '';
  }

  Future<bool> _confirmZero() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tiền đầu ca là 0đ?'),
        content: const Text('Két đang trống. Đúng thì bấm Xác nhận.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Nhập lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _submit() async {
    final navigator = Navigator.of(context);
    final controller = context.read<ShiftController>();
    final name = _myName;
    FocusScope.of(context).unfocus();

    // Gõ 0 thì hỏi lại một lần, vì rất dễ là quên nhập.
    if (parseVnd(_cash.text) == 0 && !await _confirmZero()) return;
    if (!mounted) return;

    setState(() => _submitting = true);
    final result = await controller.openShift(_cash.text);
    if (!mounted) return;

    switch (result) {
      case OpenShiftResult.failed:
        HapticFeedback.heavyImpact();
        setState(() {
          _submitting = false;
          _errorTick++;
        });
      case OpenShiftResult.joinedExisting:
        // Người khác mở trước: hiện màn "Vào ca đang mở".
        HapticFeedback.mediumImpact();
        setState(() => _submitting = false);
      case OpenShiftResult.opened:
        await showShiftOpenedCelebration(context, name: name);
        if (!mounted) return;
        navigator.pop();
        // Tải lại sau khi quay về Trang chủ: thẻ ca và các tab mở khóa lúc đó.
        controller.load(quiet: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ShiftController>();
    final state = c.state;
    // Ca đang mở mà mình không đang trong lượt bấm "Mở ca": hiện "Vào ca đang mở".
    final CurrentShift? existing = state is ShiftOpen ? state.shift : null;
    final joined = !_submitting && existing != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onBack: () => Navigator.of(context).maybePop()),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: AnimatedSwitcher(
                  duration:
                      Motion.of(context, const Duration(milliseconds: 380)),
                  switchInCurve: Curves.easeOutCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.03),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: joined
                      ? _JoinView(
                          key: const ValueKey('join'),
                          shift: existing,
                        )
                      : _FormView(
                          key: const ValueKey('form'),
                          controller: _cash,
                          focus: _focus,
                          name: _myName,
                          error: c.openError,
                          errorTick: _errorTick,
                          enabled: !c.opening,
                          onChanged: () {
                            c.clearOpenError();
                            setState(() {});
                          },
                          onSubmit: _submit,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: joined
                  ? ForeButton(
                      label: 'Vào ca đang mở',
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : ForeButton(
                      label: 'Mở ca',
                      loadingLabel: 'Đang mở ca',
                      loading: c.opening,
                      onPressed: _submit,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 24, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Quay lại',
            onPressed: onBack,
            iconSize: 34,
            constraints: const BoxConstraints.tightFor(width: 52, height: 52),
            icon: const Icon(Icons.chevron_left_rounded),
            color: AppColors.brand,
          ),
          const Spacer(),
          const BrandMark(size: 36),
        ],
      ),
    );
  }
}

/// Dòng ngày và tiêu đề dùng chung cho hai trạng thái.
class _Heading extends StatelessWidget {
  const _Heading({required this.title, required this.subtitle});

  final String title;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MinuteTicker(
          builder: (context, now) => Text(
            'Hôm nay, ${formatDayMonth(now)}',
            style: AppTextStyles.body.copyWith(fontSize: AppFontSizes.s14),
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: AppTextStyles.display),
        const SizedBox(height: 6),
        subtitle,
      ],
    );
  }
}

class _FormView extends StatelessWidget {
  const _FormView({
    super.key,
    required this.controller,
    required this.focus,
    required this.name,
    required this.error,
    required this.errorTick,
    required this.enabled,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final String name;
  final String? error;
  final int errorTick;
  final bool enabled;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final amount = parseVnd(controller.text);
    final hasError = error != null;
    final duration = Motion.of(context, const Duration(milliseconds: 220));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(
          title: 'Mở ca',
          subtitle: MinuteTicker(
            builder: (context, now) => Text(
              name.isEmpty
                  ? formatHm(now)
                  : '${formatHm(now)} · $name đang mở ca',
              style: AppTextStyles.label.copyWith(fontSize: AppFontSizes.s15),
            ),
          ),
        ),
        const SizedBox(height: 32),
        FadeSlideIn(
          delay: const Duration(milliseconds: 100),
          child: Text('Tiền đầu ca', style: AppTextStyles.label),
        ),
        const SizedBox(height: 8),
        FadeSlideIn(
          delay: const Duration(milliseconds: 180),
          child: Shake(
            trigger: errorTick,
            child: AnimatedContainer(
              duration: duration,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: hasError
                      ? AppColors.warning
                      : focus.hasFocus
                          ? AppColors.brand
                          : AppColors.border,
                  width: hasError || focus.hasFocus ? 2 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Focus(
                onFocusChange: (_) => onChanged(),
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  enabled: enabled,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: const [VndInputFormatter()],
                  onChanged: (_) => onChanged(),
                  onSubmitted: (_) => onSubmit(),
                  cursorColor: AppColors.brand,
                  style: TextStyle(
                    fontSize: AppFontSizes.s36,
                    fontWeight: FontWeight.w700,
                    color: AppColors.brand,
                    height: 1.3,
                  ),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: AppFontSizes.s36,
                      fontWeight: FontWeight.w700,
                      color: AppColors.shadowMedium,
                    ),
                    suffixText: 'đ',
                    suffixStyle: TextStyle(
                      fontSize: AppFontSizes.s28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: duration,
          child: hasError
              ? _ErrorLine(key: const ValueKey('e'), message: error!)
              : amount != null && amount > 0
                  ? _WordsLine(key: const ValueKey('w'), amount: amount)
                  : const _HintLine(key: ValueKey('h')),
        ),
      ],
    );
  }
}

/// Gợi ý khi chưa nhập gì.
class _HintLine extends StatelessWidget {
  const _HintLine({super.key});

  @override
  Widget build(BuildContext context) => Text(
        'Nhập số tiền thực tế đang có trong két.',
        style: AppTextStyles.body.copyWith(fontSize: AppFontSizes.s14),
      );
}

/// Số tiền đọc thành chữ: nhìn là biết có gõ thừa hay thiếu số 0.
class _WordsLine extends StatelessWidget {
  const _WordsLine({super.key, required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) => Text(
        vndInWords(amount),
        style: TextStyle(
          fontSize: AppFontSizes.s15,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          ForeIconView(
            ForeIcon.warning,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w600,
                color: AppColors.warningText,
              ),
            ),
          ),
        ],
      );
}

/// Người khác đã mở ca trước: cho vào ca đó, không bắt mở lại.
class _JoinView extends StatelessWidget {
  const _JoinView({super.key, required this.shift});

  final CurrentShift shift;

  @override
  Widget build(BuildContext context) {
    final who =
        shift.openedByMe ? 'Ca của bạn' : 'Ca của ${shift.openedByName}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Heading(
          title: 'Vào ca đang mở',
          subtitle: Text(
            'Mở lúc ${formatHm(shift.openedAt)}',
            style: AppTextStyles.label.copyWith(fontSize: AppFontSizes.s15),
          ),
        ),
        const SizedBox(height: 32),
        FadeSlideIn(
          delay: const Duration(milliseconds: 120),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.warningSoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warningOverlay),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ForeIconView(
                    ForeIcon.warning,
                    size: 24,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$who đang mở',
                          style: TextStyle(
                            fontSize: AppFontSizes.s16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Đang có một ca mở rồi. Hãy vào ca đó để tiếp tục.',
                          style: TextStyle(
                            fontSize: AppFontSizes.s14,
                            height: 1.4,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
