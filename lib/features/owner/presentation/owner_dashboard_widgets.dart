part of 'owner_home_screen.dart';

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => ForeCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ForeIconBadge(
            icon: icon,
            color: AppColors.brand,
            background: AppColors.accentTint,
            size: 36,
          ),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.metric),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption),
        ]),
      );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
    this.iconColor,
    this.status,
    this.showArrow = false,
    this.level,
  });
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Widget? status;
  final bool showArrow;

  /// Thanh mức tồn (0..1) ở cuối thẻ, cùng màu với icon; null thì không vẽ.
  final double? level;

  @override
  Widget build(BuildContext context) {
    final child = ForeCard(
      padding: const EdgeInsets.all(15),
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ForeIconBadge(icon: icon, color: iconColor ?? AppColors.brandAccent),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.cardTitle),
            if (status != null) ...[
              const SizedBox(height: 6),
              status!,
            ],
            const SizedBox(height: 4),
            Text(body, style: AppTextStyles.caption),
            if (level != null) ...[
              const SizedBox(height: 10),
              Semantics(
                label: 'Mức tồn ${(level! * 100).round()}%',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: level,
                    minHeight: 8,
                    backgroundColor: AppColors.tint,
                    color: iconColor ?? AppColors.brandAccent,
                  ),
                ),
              ),
            ],
          ]),
        ),
        if (showArrow) ...[
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Icon(Icons.chevron_right_rounded,
                size: 22, color: AppColors.brand),
          ),
        ],
      ]),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: child,
    );
  }
}

class _NewShopChecklist extends StatelessWidget {
  const _NewShopChecklist({
    required this.onMenu,
    required this.onStock,
    required this.onInvite,
  });

  final VoidCallback onMenu;
  final VoidCallback onStock;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: ForeCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Chào mừng quán của bạn!',
                  style: AppTextStyles.appBarTitle
                      .copyWith(color: AppColors.brand)),
              const SizedBox(height: 4),
              Text('Hoàn thành vài bước để bắt đầu vận hành.',
                  style: AppTextStyles.caption),
              const SizedBox(height: 8),
              _ChecklistAction(
                icon: Icons.menu_book_outlined,
                label: 'Thiết lập thực đơn',
                onTap: onMenu,
              ),
              _ChecklistAction(
                icon: Icons.inventory_2_outlined,
                label: 'Thêm nguyên liệu đầu tiên',
                onTap: onStock,
              ),
              _ChecklistAction(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Mời nhân viên',
                onTap: onInvite,
              ),
            ],
          ),
        ),
      );
}

class _ChecklistAction extends StatelessWidget {
  const _ChecklistAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Material(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(AppRadius.field),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.field),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  ForeIconBadge(icon: icon, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: AppTextStyles.bodyStrong)),
                  Icon(Icons.chevron_right_rounded, color: AppColors.brand),
                ]),
              ),
            ),
          ),
        ),
      );
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: '$title. $subtitle',
        child: ForeCard(
          onTap: onTap,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ForeIconBadge(icon: icon, color: AppColors.brandAccent, size: 36),
              const SizedBox(height: 10),
              Text(title, style: AppTextStyles.bodyStrong),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
      );
}

class _StockActionButton extends StatelessWidget {
  const _StockActionButton({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 54,
        child: FilledButton.tonalIcon(
          onPressed: enabled ? onTap : null,
          icon: Icon(icon, size: 19),
          label: Text(title, maxLines: 2, textAlign: TextAlign.center),
          // Giữ màu mù tạt của theme (chủ quán chọn giữ kiểu này cho hai thao tác kho).
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Expanded(child: Text(title, style: AppTextStyles.sectionHeading)),
          if (trailing != null) trailing!,
        ]),
      );
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.onRetry, this.message});
  final Future<void> Function() onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ForeIconBadge(
              icon: Icons.cloud_off_outlined,
              color: AppColors.warningText,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text('Chưa thể cập nhật',
                style: AppTextStyles.appBarTitle
                    .copyWith(color: AppColors.brand, fontSize: 20)),
            const SizedBox(height: 6),
            Text(
              message ??
                  'Không tải được dữ liệu quán. Hãy kiểm tra kết nối và cấu hình database.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            ForeButton(
              label: 'Thử lại',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: onRetry,
            ),
          ]),
        ),
      );
}
