import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/fore_action_icons.dart';
import '../../core/widgets/page_scaffold.dart';

/// Tab "Thêm": ghi hao hụt, thu/chi tiền mặt, tài khoản và đăng xuất.
/// Các việc của chủ quán (báo cáo, thực đơn, cài đặt) sẽ thêm ở đây sau; nhân viên không thấy.
class MoreView extends StatelessWidget {
  const MoreView({
    super.key,
    required this.personName,
    this.header,
    required this.roleLabel,
    required this.shopName,
    required this.hasOpenShift,
    required this.isOwner,
    this.onShiftBills,
    required this.onWaste,
    required this.onCash,
    required this.onSwitchShop,
    required this.onInbox,
    required this.onTeam,
    required this.onSignOut,
  });

  final String personName;
  final Widget? header;
  final String roleLabel;
  final String shopName;

  /// Ghi hao hụt, thu/chi và xem hóa đơn trong ca chỉ làm được khi đang có ca.
  final bool hasOpenShift;
  final bool isOwner;
  final VoidCallback? onShiftBills;
  final VoidCallback onWaste;
  final VoidCallback onCash;
  final VoidCallback onSwitchShop;
  final VoidCallback onInbox;
  final VoidCallback onTeam;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) => PageScaffold(
        header: header,
        children: [
          const Text('Thêm', style: AppTextStyles.display),
          const SizedBox(height: 20),
          if (onShiftBills != null) ...[
            ActionTile(
              icon: const Icon(Icons.receipt_long_outlined, color: AppColors.ink),
              title: 'Hóa đơn trong ca',
              subtitle: hasOpenShift
                  ? 'Xem lịch sử, chi tiết và hủy bill đã thu'
                  : 'Mở ca để dùng',
              onTap: hasOpenShift ? onShiftBills : null,
            ),
            const SizedBox(height: 12),
          ],
          ActionTile(
            icon: const Icon(Icons.storefront_outlined, color: AppColors.ink),
            title: shopName.isEmpty ? 'Quán' : shopName,
            subtitle: 'Đổi quán đang sử dụng',
            onTap: onSwitchShop,
          ),
          const SizedBox(height: 12),
          ActionTile(
            icon: const Icon(ForeActionIcons.waste, color: AppColors.ink),
            title: 'Ghi hao hụt',
            subtitle: hasOpenShift
                ? 'Đổ bỏ, làm sai, cho nhân viên, thử vị'
                : 'Mở ca để dùng',
            onTap: hasOpenShift ? onWaste : null,
          ),
          const SizedBox(height: 12),
          ActionTile(
            icon:
                const Icon(ForeActionIcons.cashMovement, color: AppColors.ink),
            title: 'Thu / chi tiền mặt',
            subtitle:
                hasOpenShift ? 'Mua đá, chủ rút tiền...' : 'Mở ca để dùng',
            onTap: hasOpenShift ? onCash : null,
          ),
          const SizedBox(height: 24),
          const Text('Quản lý quán', style: AppTextStyles.headline),
          const SizedBox(height: 12),
          ActionTile(
            icon: const Icon(Icons.mail_outline_rounded, color: AppColors.ink),
            title: 'Hộp thư',
            subtitle: 'Lời mời vào quán',
            onTap: onInbox,
          ),
          if (isOwner) ...[
            const SizedBox(height: 12),
            ActionTile(
              icon: const Icon(Icons.groups_outlined, color: AppColors.ink),
              title: 'Nhân viên',
              subtitle: 'Thêm và quản lý nhân viên',
              onTap: onTeam,
            ),
          ],
          const SizedBox(height: 24),
          const Text('Tài khoản', style: AppTextStyles.headline),
          const SizedBox(height: 12),
          ForeCard(
            radius: 20,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(personName, style: AppTextStyles.title),
                const SizedBox(height: 2),
                Text('$roleLabel · $shopName', style: AppTextStyles.caption),
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: onSignOut, child: const Text('Đăng xuất')),
              ],
            ),
          ),
        ],
      );
}
