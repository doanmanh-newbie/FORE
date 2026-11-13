part of 'bill_screen.dart';

class _BillLoadingState extends StatelessWidget {
  const _BillLoadingState();

  @override
  Widget build(BuildContext context) => const LazyListView(
        padding: EdgeInsets.all(16),
        children: [
          SkeletonBox(height: 44),
          SizedBox(height: 18),
          SkeletonBox(height: 20, width: 130),
          SizedBox(height: 10),
          SkeletonBox(height: 112),
          SizedBox(height: 12),
          SkeletonBox(height: 112),
          SizedBox(height: 12),
          SkeletonBox(height: 112),
        ],
      );
}

class _BillHeader extends StatelessWidget {
  const _BillHeader({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onCancel,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          boxShadow: [
            BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 18,
                offset: const Offset(0, 6))
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Quay lại',
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back_rounded,
                      color: AppColors.ink),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: AppTextStyles.headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (subtitle.isNotEmpty)
                        Text(subtitle,
                            style: AppTextStyles.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (onCancel != null)
                  PopupMenuButton<String>(
                    tooltip: 'Thêm',
                    icon: Icon(Icons.more_horiz_rounded,
                        color: AppColors.ink),
                    onSelected: (_) => onCancel!(),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'cancel', child: Text('Hủy bill')),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
}

class _Segmented extends StatelessWidget {
  const _Segmented(
      {required this.labels, required this.selected, required this.onChanged});

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
            color: AppColors.surfaceTint,
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: labels[i],
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onChanged(i),
                        child: AnimatedContainer(
                          duration: Motion.of(
                              context, const Duration(milliseconds: 200)),
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: i == selected
                                ? AppColors.ink
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            labels[i],
                            style: TextStyle(
                              fontSize: AppFontSizes.s15,
                              fontWeight: FontWeight.w700,
                              color:
                                  i == selected ? AppColors.onInk : AppColors.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------- tab "Gọi món"
class _MenuTab extends StatelessWidget {
  const _MenuTab({super.key, required this.controller});

  final BillController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (!c.isOpen) {
      return const EmptyState(
        icon: ForeIcons.lock,
        title: 'Bill đã đóng',
        message: 'Không gọi thêm món được nữa. Xem các dòng ở tab Bill.',
      );
    }
    final items = c.visibleMenu;
    return LazyListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        TextField(
          onChanged: c.setQuery,
          decoration: InputDecoration(
            hintText: 'Tìm món',
            prefixIcon:
                Icon(Icons.search_rounded, color: AppColors.textSecondary),
          ),
        ),
        if (c.groups.length > 1) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: LazyListView(
              scrollDirection: Axis.horizontal,
              children: [
                _GroupChip(
                    label: 'Tất cả',
                    selected: c.selectedGroup == null,
                    onTap: () => c.selectGroup(null)),
                for (final g in c.groups)
                  _GroupChip(
                      label: g,
                      selected: c.selectedGroup == g,
                      onTap: () => c.selectGroup(g)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (c.menu.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'Thực đơn đang trống. Chủ quán cần thêm món trước.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          )
        else if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Text('Không có món nào khớp.',
                textAlign: TextAlign.center, style: AppTextStyles.body),
          )
        else
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _MenuItemCard(item: item, controller: c),
            ),
      ],
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: PressableScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: Motion.of(context, const Duration(milliseconds: 180)),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: selected ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: selected ? AppColors.ink : AppColors.border),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppFontSizes.s14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.onInk : AppColors.ink,
              ),
            ),
          ),
        ),
      );
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({required this.item, required this.controller});

  final MenuItemEntry item;
  final BillController controller;

  @override
  Widget build(BuildContext context) => ForeCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.name, style: AppTextStyles.title),
            if (item.group != null)
              Text(item.group!, style: AppTextStyles.caption),
            const SizedBox(height: 4),
            for (final size in item.sizes)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (item.sizes.length > 1 || size.name.isNotEmpty)
                          Text(size.name, style: AppTextStyles.bodyStrong),
                        Text(formatVnd(size.price),
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  QtyStepper(
                    value: controller.cartQty(size.id),
                    max: controller.maxLineQty,
                    onChanged: (q) => controller.setCartQty(size.id, q),
                  ),
                ],
              ),
          ],
        ),
      );
}

// ---------------------------------------------------------------- tab "Bill"
