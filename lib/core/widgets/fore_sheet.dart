import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import 'package:fore/core/design/colors.dart';

/// Mở một bottom sheet bo góc, tự nâng lên khi bàn phím hiện, có tiêu đề kiểu thiết kế.
Future<T?> showForeSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Widget Function(BuildContext sheetContext) builder,
}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.headline),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle, style: AppTextStyles.body),
              ],
              const SizedBox(height: 16),
              builder(sheetContext),
            ],
          ),
        ),
      ),
    );

/// Hỏi lý do (bắt buộc). Nút xác nhận bị khóa cho tới khi đủ `minLength` ký tự.
/// Trả về lý do đã cắt khoảng trắng, hoặc `null` nếu người dùng đóng.
Future<String?> askReason(
  BuildContext context, {
  required String title,
  String? subtitle,
  String hint = 'Ví dụ: khách đổi ý',
  String confirmLabel = 'Xác nhận',
  int minLength = 1,
  bool destructive = false,
}) =>
    showForeSheet<String>(
      context,
      title: title,
      subtitle: subtitle,
      builder: (_) => _ReasonForm(
        hint: hint,
        confirmLabel: confirmLabel,
        minLength: minLength,
        destructive: destructive,
      ),
    );

class _ReasonForm extends StatefulWidget {
  const _ReasonForm({
    required this.hint,
    required this.confirmLabel,
    required this.minLength,
    required this.destructive,
  });

  final String hint;
  final String confirmLabel;
  final int minLength;
  final bool destructive;

  @override
  State<_ReasonForm> createState() => _ReasonFormState();
}

class _ReasonFormState extends State<_ReasonForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _valid => _controller.text.trim().length >= widget.minLength;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            maxLength: 200,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Lý do (bắt buộc)',
              hintText: widget.hint,
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            style: widget.destructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: AppColors.white,
                  )
                : null,
            onPressed: _valid
                ? () => Navigator.of(context).pop(_controller.text.trim())
                : null,
            child: Text(widget.confirmLabel),
          ),
        ],
      );
}
