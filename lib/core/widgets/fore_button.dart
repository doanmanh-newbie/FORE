import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';
import 'loading_button.dart';

/// Kiểu nút của bộ "Rêu & Mù tạt".
enum ForeButtonVariant {
  /// Viên thuốc vàng mù tạt, chữ rêu: hành động chính, mỗi màn chỉ một.
  primary,

  /// Viên thuốc viền rêu, nền trong: hành động phụ.
  secondary,

  /// Viên thuốc nền nhạt (rêu nhạt), chữ rêu: hành động phụ trong thẻ.
  tonal,
}

/// Nút viên thuốc dùng chung. `primary` dựa trên [LoadingButton] nên có vòng quay
/// và chặn bấm hai lần khi `loading`.
class ForeButton extends StatelessWidget {
  const ForeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.loadingLabel,
    this.icon,
    this.variant = ForeButtonVariant.primary,
    this.height = AppSizes.pillButtonHeight,
    this.expand = true,
  });

  final String label;
  final String? loadingLabel;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ForeButtonVariant variant;
  final double height;

  /// Giãn hết bề ngang (mặc định) hay ôm nội dung.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final Widget button = switch (variant) {
      ForeButtonVariant.primary when icon == null => LoadingButton(
          label: label,
          loadingLabel: loadingLabel,
          loading: loading,
          onPressed: onPressed,
          height: height,
          textStyle: AppTextStyles.pillButton,
        ),
      ForeButtonVariant.primary => FilledButton.icon(
          onPressed: loading ? null : onPressed,
          icon: Icon(icon, size: 20),
          label: Text(loading ? (loadingLabel ?? label) : label),
          style: FilledButton.styleFrom(
            minimumSize: Size(0, height),
            textStyle: AppTextStyles.pillButton,
          ),
        ),
      ForeButtonVariant.secondary => OutlinedButton(
          onPressed: loading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size(0, height),
            textStyle: AppTextStyles.pillButton.copyWith(fontSize: 15),
            side: BorderSide(color: AppColors.brand, width: 1.2),
          ),
          child: _content(),
        ),
      ForeButtonVariant.tonal => FilledButton(
          onPressed: loading ? null : onPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size(0, height),
            backgroundColor: AppColors.navIndicator,
            foregroundColor: AppColors.brand,
            textStyle: AppTextStyles.pillButton.copyWith(fontSize: 15),
          ),
          child: _content(),
        ),
    };
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }

  /// Nội dung nút phụ: đang tải thì vòng quay nhỏ thay icon và hiện [loadingLabel].
  Widget _content() {
    final text = loading ? (loadingLabel ?? label) : label;
    final Widget? leading = loading
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : icon == null
            ? null
            : Icon(icon, size: 19);
    if (leading == null) return Text(text);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        leading,
        const SizedBox(width: 8),
        Flexible(child: Text(text, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
