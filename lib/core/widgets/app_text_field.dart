import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/spacing.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'brand_text_field.dart' show TintedSvg;

/// Ô nhập có nhãn phía trên và lỗi ngay dưới ô. Với `obscure: true` có nút hiện/ẩn.
/// Cùng dáng với [ForeTextField] (bộ "Rêu & Mù tạt"): nhãn 13/600, chữ 15/500, cao tối thiểu 52.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.enabled = true,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final bool enabled;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final int maxLines;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: AppGaps.sm),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: _hidden,
          maxLines: widget.obscure ? 1 : widget.maxLines,
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
            hintText: widget.hint,
            hintStyle: AppTextStyles.inputHint,
            errorText: widget.errorText,
            errorMaxLines: 3,
            constraints: widget.maxLines == 1 || widget.obscure
                ? const BoxConstraints(minHeight: AppSizes.fieldHeight)
                : null,
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                    // Cùng icon với ô mật khẩu màn Đăng nhập.
                    icon: _hidden
                        ? TintedSvg('assets/auth/ic_eye_off.svg',
                            color: AppColors.textHint, size: 22)
                        : Icon(Icons.visibility_outlined,
                            color: AppColors.textHint, size: 22),
                    onPressed: widget.enabled
                        ? () => setState(() => _hidden = !_hidden)
                        : null,
                  )
                : null,
          ),
        ),
      ],
    );
  }
}
