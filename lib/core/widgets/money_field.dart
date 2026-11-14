import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../theme/app_text_styles.dart';

/// Tự thêm dấu chấm ngăn cách hàng nghìn khi gõ: 1250000 -> 1.250.000. Chỉ nhận chữ số.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final capped = digits.length > 12 ? digits.substring(0, 12) : digits;
    final text = formatVnd(int.parse(capped)).replaceAll('đ', '');
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Ô nhập số tiền (đồng, số nguyên). `large` cho ô to ở màn đóng ca.
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    this.label,
    this.hint = '0',
    this.helper,
    this.errorText,
    this.large = false,
    this.autofocus = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;
  final String? helper;
  final String? errorText;
  final bool large;
  final bool autofocus;
  final ValueChanged<int?>? onChanged;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        autofocus: autofocus,
        keyboardType: TextInputType.number,
        inputFormatters: const [MoneyInputFormatter()],
        style: large ? AppTextStyles.numberXL : AppTextStyles.number,
        textAlign: large ? TextAlign.start : TextAlign.end,
        onChanged:
            onChanged == null ? null : (text) => onChanged!(parseVnd(text)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          errorText: errorText,
          suffixText: 'đ',
          suffixStyle: large ? AppTextStyles.numberXL : AppTextStyles.number,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 18,
            vertical: large ? 20 : 15,
          ),
        ),
      );
}
