import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/notify.dart';
import '../domain/shop_repository.dart';

/// Chủ quán xem mã quán (6 ký tự) để đưa nhân viên tự vào quán; sao chép hoặc đổi mã khi bị lộ.
class ShopJoinCodeCard extends StatefulWidget {
  const ShopJoinCodeCard({super.key});

  @override
  State<ShopJoinCodeCard> createState() => _ShopJoinCodeCardState();
}

class _ShopJoinCodeCardState extends State<ShopJoinCodeCard> {
  String? _code;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool regenerate = false}) async {
    setState(() => _busy = true);
    try {
      final code = await context
          .read<ShopRepository>()
          .shopJoinCode(regenerate: regenerate);
      if (!mounted) return;
      setState(() {
        _code = code;
        _error = null;
        _busy = false;
      });
      if (regenerate) {
        showNotice(context, 'Đã đổi mã quán. Mã cũ không dùng được nữa.');
      }
    } on AppFailure catch (f) {
      if (mounted) {
        setState(() {
          _error = f.userMessage;
          _busy = false;
        });
      }
    }
  }

  Future<void> _regenerate() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mã quán?'),
        content: const Text(
            'Mã cũ sẽ không dùng được nữa. Nhân viên đã vào quán không bị ảnh hưởng.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Thôi')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Đổi mã')),
        ],
      ),
    );
    if (ok == true && mounted) await _load(regenerate: true);
  }

  @override
  Widget build(BuildContext context) {
    final code = _code;
    return ForeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Mã quán', style: AppTextStyles.title),
          const SizedBox(height: 4),
          Text(
            'Đưa mã này cho nhân viên. Họ nhập mã trong app là vào quán ngay.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Text(_error!, style: AppTextStyles.caption)
          else if (code == null)
            const LinearProgressIndicator()
          else
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    code,
                    style: AppTextStyles.display.copyWith(letterSpacing: 4),
                  ),
                ),
                IconButton(
                  tooltip: 'Sao chép mã',
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (context.mounted) {
                      showNotice(context, 'Đã sao chép mã $code');
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Đổi mã',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: _busy ? null : _regenerate,
                ),
              ],
            ),
        ],
      ),
    );
  }
}
