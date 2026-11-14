import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../shift/application/shift_controller.dart';

/// Bảng chọn quán: người làm nhiều quán chuyển qua lại; có lối "Tạo quán mới".
Future<void> showShopSwitcher(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SwitcherSheet(),
  );
}

class _SwitcherSheet extends StatefulWidget {
  const _SwitcherSheet();

  @override
  State<_SwitcherSheet> createState() => _SwitcherSheetState();
}

class _SwitcherSheetState extends State<_SwitcherSheet> {
  List<SessionShop>? _shops;
  String? _error;
  String? _switching;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final session = context.read<SessionController>();
      final failure = await session.refreshAfterSignIn();
      if (failure != null) throw failure;
      final state = session.state;
      if (state is SessionReady && mounted) {
        setState(() => _shops = state.shops);
      }
    } on AppFailure catch (f) {
      if (mounted) setState(() => _error = f.userMessage);
    }
  }

  Future<void> _select(SessionShop shop) async {
    if (shop.isCurrent || _switching != null) return;
    final session = context.read<SessionController>();
    final shift = context.read<ShiftController>();
    final navigator = Navigator.of(context);
    setState(() {
      _switching = shop.shopId;
      _error = null;
    });
    try {
      final failure = await session.chooseShop(shop.shopId);
      if (failure != null) throw failure;
      shift.load();
      HapticFeedback.selectionClick();
      if (!mounted) return;
      navigator.pop();
      // Về Trang chủ của quán mới (làm mới toàn bộ màn hình theo quán).
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on AppFailure catch (f) {
      if (mounted) {
        setState(() {
          _error = f.userMessage;
          _switching = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final shops = _shops;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Quán của tôi', style: AppTextStyles.heading),
            const SizedBox(height: 12),
            if (shops == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (shops != null)
              for (final s in shops)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.tint,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 42,
                      child: Icon(
                        s.role.isOwner
                            ? Icons.storefront_outlined
                            : Icons.badge_outlined,
                        color: AppColors.brand,
                        size: 22,
                      ),
                    ),
                  ),
                  title: Text(s.shopName,
                      style: AppTextStyles.label
                          .copyWith(fontSize: AppFontSizes.s16)),
                  subtitle: Text(
                    '${s.role.isOwner ? 'Chủ quán' : 'Nhân viên'} · ${s.fullName}',
                    style: AppTextStyles.caption,
                  ),
                  trailing: _switching == s.shopId
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : s.isCurrent
                          ? Icon(Icons.check_circle,
                              color: AppColors.statusOk)
                          : Icon(Icons.chevron_right,
                              color: AppColors.inkMuted),
                  onTap: () => _select(s),
                ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style: TextStyle(
                        color: AppColors.statusOff,
                        fontSize: AppFontSizes.s13)),
              ),
            const Divider(height: 24),
            TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(AppRoutes.createShop);
              },
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Tạo quán mới'),
            ),
          ],
        ),
      ),
    );
  }
}
