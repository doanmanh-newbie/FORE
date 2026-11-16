import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../design/colors.dart';
import '../design/spacing.dart';
import '../design/typography.dart';

/// Icon nét đơn từ SVG, tô lại màu theo theme (SVG gốc vẽ một màu).
class TintedSvg extends StatelessWidget {
  const TintedSvg(this.asset, {super.key, required this.color, this.size = 20});

  final String asset;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        asset,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
}

/// Ô nhập bộ "Rêu & Mù tạt": nền trắng, viền mảnh, bo 12, icon đầu ô tùy chọn,
/// nhãn phía trên tùy chọn, nút hiện/ẩn khi `obscure`. Lỗi hiện ngay dưới ô.
class BrandTextField extends StatefulWidget {
  const BrandTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.leadingAsset,
    this.leadingIcon,
    this.errorText,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;

  /// Đường dẫn SVG icon đầu ô (vd `AuthAssets.lock`).
  final String? leadingAsset;

  /// Icon Material đầu ô khi không có SVG phù hợp (vd điện thoại, lịch).
  final IconData? leadingIcon;
  final String? errorText;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;

  static const _eyeOff = 'assets/auth/ic_eye_off.svg';

  @override
  State<BrandTextField> createState() => _BrandTextFieldState();
}

class _BrandTextFieldState extends State<BrandTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final iconColor = AppColors.textHint;
    final hasLeading = widget.leadingAsset != null || widget.leadingIcon != null;
    final field = TextField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      autocorrect: false,
      enableSuggestions: !widget.obscure,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      style: AppTextStyles.input,
      cursorColor: AppColors.brand,
      decoration: InputDecoration(
        // Không đặt label trong ô: đọc màn hình vẫn có nhãn nhờ hint/label ngoài.
        hintText: widget.hint ?? widget.label,
        hintStyle: AppTextStyles.inputHint,
        errorText: widget.errorText,
        errorMaxLines: 3,
        constraints: const BoxConstraints(minHeight: AppSizes.fieldHeight),
        prefixIcon: !hasLeading
            ? null
            : Padding(
                padding: const EdgeInsets.only(left: 16, right: 10),
                child: widget.leadingAsset != null
                    ? TintedSvg(widget.leadingAsset!, color: iconColor)
                    : Icon(widget.leadingIcon, color: iconColor, size: 20),
              ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 46, minHeight: 20),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                icon: _hidden
                    ? TintedSvg(BrandTextField._eyeOff,
                        color: iconColor, size: 22)
                    : Icon(Icons.visibility_outlined,
                        color: iconColor, size: 22),
                onPressed: widget.enabled
                    ? () => setState(() => _hidden = !_hidden)
                    : null,
              )
            : null,
      ),
    );
    // Ô có icon đầu ô theo mẫu Đăng ký: nhãn nằm trong ô (gợi ý), không có nhãn rời.
    if (widget.label == null || hasLeading) {
      return Semantics(label: widget.label, child: field);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label!, style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppGaps.sm),
        field,
      ],
    );
  }
}
