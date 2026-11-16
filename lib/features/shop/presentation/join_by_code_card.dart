import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/brand_text_field.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/loading_button.dart';
import '../../auth/application/session_controller.dart';
import '../../shift/application/shift_controller.dart';
import '../domain/shop_repository.dart';

/// Nhân viên nhập mã quán chủ quán đưa (6 ký tự) là vào quán luôn, không cần chờ lời mời.
class JoinByCodeCard extends StatefulWidget {
  const JoinByCodeCard({super.key});

  @override
  State<JoinByCodeCard> createState() => _JoinByCodeCardState();
}

class _JoinByCodeCardState extends State<JoinByCodeCard> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Mã quán gồm 6 ký tự.');
      return;
    }
    final repo = context.read<ShopRepository>();
    final session = context.read<SessionController>();
    final shift = context.read<ShiftController>();
    final navigator = Navigator.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await repo.joinShopByCode(code);
      final failure = await session.refreshAfterSignIn();
      if (failure != null) throw failure;
      shift.load();
      final next = AppRoutes.routeFor(session.state);
      if (next != null) navigator.pushNamedAndRemoveUntil(next, (_) => false);
    } on AppFailure catch (f) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = f.userMessage;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => ForeCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Vào quán bằng mã', style: AppTextStyles.title),
            const SizedBox(height: 4),
            Text('Nhập mã 6 ký tự chủ quán đưa cho bạn.',
                style: AppTextStyles.caption),
            const SizedBox(height: AppGaps.md),
            BrandTextField(
              label: 'Mã quán',
              hint: 'Ví dụ: K7M2QX',
              controller: _code,
              errorText: _error,
              enabled: !_loading,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(6),
                TextInputFormatter.withFunction(
                    (_, v) => v.copyWith(text: v.text.toUpperCase())),
              ],
              onSubmitted: _join,
            ),
            const SizedBox(height: AppGaps.md),
            LoadingButton(
              label: 'Vào quán',
              loadingLabel: 'Đang vào quán',
              loading: _loading,
              onPressed: _join,
            ),
          ],
        ),
      );
}
