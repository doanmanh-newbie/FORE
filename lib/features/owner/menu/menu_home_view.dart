import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../../../core/widgets/status_chip.dart';
import 'menu_category_views.dart';
import 'menu_detail_view.dart';
import 'menu_filter_view.dart';
import 'menu_image_view.dart';
import 'menu_format.dart';
import 'menu_item_form_view.dart';
import 'menu_models.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// Thân tab Thực đơn: tìm kiếm, lọc, danh sách món. [header] là thanh quán/chuông của trang chủ chủ quán.
class MenuHomeView extends StatefulWidget {
  const MenuHomeView({super.key, required this.header});

  final Widget header;

  @override
  State<MenuHomeView> createState() => _MenuHomeViewState();
}

class _MenuHomeViewState extends State<MenuHomeView> {
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<MenuStore>();
    _search.text = store.filters.query;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && store.overview == null && !store.loading) {
        store.load();
      }
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(MenuStore store, MenuItem item, bool value) async {
    if (!value) {
      final ok = await confirmSheet(
        context,
        title: 'Tạm ngừng bán món này?',
        message:
            'Món sẽ không xuất hiện cho lần chọn bán mới. Bill đang mở, doanh thu và lịch sử bán hàng cũ vẫn còn nguyên. '
            'Không xóa món đã bán. Bạn có thể bật bán lại bất cứ lúc nào.',
        confirmLabel: 'Tạm ngừng bán',
        cancelLabel: 'Hủy',
        extra: [
          const SizedBox(height: 10),
          Text('${item.name} · ${item.activeSizes.length} size',
              style: AppTextStyles.bodyStrong),
        ],
      );
      if (!ok || !mounted) return;
    }
    await menuGuard(context, () => store.setActive(item.id, value));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MenuStore>();
    final data = store.overview;
    return Column(
      children: [
        widget.header,
        Expanded(child: _body(store, data)),
      ],
    );
  }

  Widget _body(MenuStore store, MenuOverview? data) {
    if (data == null && store.loading) {
      return const LazyListView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [MenuSkeleton(rows: 5)],
      );
    }
    if (data == null) {
      return _FailureView(store: store);
    }
    final offline = store.stale;
    final items = store.visibleItems;
    final filters = store.filters;
    final searching = filters.query.trim().isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => store.load(silent: true),
            child: LazyListView(
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding, 0, AppSizes.pagePadding, 16),
              children: [
                Text(
                  offline
                      ? 'SỔ TAY THỰC ĐƠN'
                      : '${menuOwnerName(context).toUpperCase()} · CHỦ QUÁN',
                  style: AppTextStyles.micro,
                ),
                const SizedBox(height: 4),
                LayoutBuilder(builder: (context, constraints) {
                  final title = Text(
                    offline
                        ? 'Thực đơn đang giữ lại'
                        : searching
                            ? 'Tìm trong thực đơn'
                            : 'Thực đơn',
                    style: AppTextStyles.display,
                  );
                  if (offline) return title;
                  final manageButton = OutlinedButton(
                    onPressed: () =>
                        openMenuPage<void>(context, const CategoryListPage()),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('Quản lý danh mục'),
                  );
                  if (constraints.maxWidth < 400) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        Align(
                          alignment: Alignment.centerRight,
                          child: manageButton,
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [Expanded(child: title), manageButton],
                  );
                }),
                if (offline) _OfflineBanner(store: store, data: data),
                const SizedBox(height: 10),
                _SearchRow(
                  controller: _search,
                  onChanged: store.setQuery,
                  hasFilter: filters.hasAdvanced,
                  onFilter: () =>
                      openMenuPage<void>(context, const MenuFilterPage()),
                ),
                const SizedBox(height: 10),
                _CategoryChips(store: store, data: data),
                if (!offline && !searching && data.items.isNotEmpty) ...[
                  _AttentionCard(store: store, data: data),
                ],
                if (data.items.isEmpty)
                  const _EmptyMenu()
                else if (items.isEmpty)
                  _NoResult(store: store)
                else ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            searching
                                ? '${items.length} món khớp "${filters.query.trim()}"'
                                : '${items.length} món · Giá VNĐ',
                            style: AppTextStyles.caption,
                          ),
                        ),
                        Text(
                          searching
                              ? 'Tên A → Z'
                              : 'Bán tại ${menuShopName(context)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  for (final item in items)
                    _ItemCard(
                      item: item,
                      lowMarginPct: data.lowMarginPct,
                      weekLabelText: weekLabel(data.weekFrom, data.weekTo),
                      readOnly: offline,
                      onToggle: (v) => _toggle(store, item, v),
                      onOpen: () => openMenuPage<void>(
                          context, MenuDetailPage(itemId: item.id)),
                    ),
                  if (searching)
                    MenuCard(
                      onTap: () {
                        _search.clear();
                        store.setQuery('');
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('Xóa tìm kiếm, xem tất cả',
                                style: AppTextStyles.bodyStrong),
                          ),
                          const Icon(Icons.close_rounded),
                        ],
                      ),
                    ),
                ],
                if (offline)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Thêm / đóng món đang khóa. Không có thay đổi nào được lưu lên hệ thống. '
                      'Kết nối lại sẽ kiểm tra dữ liệu trước khi cho phép sửa.',
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding, 6, AppSizes.pagePadding, 10),
          child: offline
              ? MenuPrimaryButton(
                  label: 'Thử kết nối lại',
                  loading: store.loading,
                  onPressed: () => store.load(silent: true),
                )
              : MenuPrimaryButton(
                  label: data.items.isEmpty ? '+ Thêm món đầu tiên' : '+ Thêm món',
                  onPressed: () =>
                      openMenuPage<void>(context, const MenuItemFormPage()),
                ),
        ),
      ],
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({
    required this.controller,
    required this.onChanged,
    required this.hasFilter,
    required this.onFilter,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool hasFilter;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm tên món...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa tìm kiếm',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          controller.clear();
                          onChanged('');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Badge(
            isLabelVisible: hasFilter,
            smallSize: 10,
            child: IconButton.outlined(
              tooltip: 'Lọc và sắp xếp',
              onPressed: onFilter,
              icon: const Icon(Icons.tune_rounded),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            ),
          ),
        ],
      );
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.store, required this.data});

  final MenuStore store;
  final MenuOverview data;

  @override
  Widget build(BuildContext context) {
    final names = store.categoryNames;
    final total = data.items.length;
    final selected = store.filters.category;
    return SizedBox(
      height: 48,
      child: LazyListView(
        scrollDirection: Axis.horizontal,
        children: [
          OptionChip(
            label: 'Tất cả · $total',
            selected: selected == null,
            onTap: () => store.setCategory(null),
          ),
          for (final name in names) ...[
            const SizedBox(width: 8),
            OptionChip(
              label: name,
              selected: selected != null &&
                  foldVietnamese(selected) == foldVietnamese(name),
              onTap: () => store.setCategory(name),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Cần chăm sóc": món thiếu công thức và size lãi thấp, bấm vào là lọc ra ngay.
class _AttentionCard extends StatelessWidget {
  const _AttentionCard({required this.store, required this.data});

  final MenuStore store;
  final MenuOverview data;

  @override
  Widget build(BuildContext context) {
    final missing = data.itemsMissingRecipe;
    final low = data.lowMarginSizeCount;
    if (missing == 0 && low == 0) return const SizedBox(height: 8);
    final firstMissing = data.items.cast<MenuItem?>().firstWhere(
        (i) => i!.status != MenuItemStatus.draft && i.missingRecipe,
        orElse: () => null);
    final firstLow = data.firstLowMarginItem;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.statusAttentionTint,
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      size: 16, color: AppColors.statusAttention),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Cần chăm sóc',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.statusAttention)),
                  ),
                  Flexible(
                    child: Text(
                      'Lãi thấp: dưới ${data.lowMarginPct}%',
                      textAlign: TextAlign.end,
                      style: AppTextStyles.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (missing > 0)
                    Expanded(
                      child: _AttentionTile(
                        title: '$missing món thiếu công thức',
                        subtitle: firstMissing?.name ?? '',
                        onTap: () => store.setFilters(store.filters.copyWith(
                          recipe: MenuRecipeFilter.missing,
                        )),
                      ),
                    ),
                  if (missing > 0 && low > 0) const SizedBox(width: 8),
                  if (low > 0)
                    Expanded(
                      child: _AttentionTile(
                        title: '$low size lãi thấp',
                        subtitle: firstLow?.name ?? '',
                        onTap: () => store.setFilters(
                            store.filters.copyWith(lowMarginOnly: true)),
                      ),
                    ),
                ],
              ),
              if (missing > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Thiếu công thức: báo cáo đối soát có thể thiếu chính xác.',
                  style: AppTextStyles.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  const _AttentionTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppTextStyles.bodyStrong.copyWith(fontSize: 13)),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ],
          ),
        ),
      );
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.lowMarginPct,
    required this.weekLabelText,
    required this.readOnly,
    required this.onToggle,
    required this.onOpen,
  });

  final MenuItem item;
  final int lowMarginPct;
  final String weekLabelText;
  final bool readOnly;
  final ValueChanged<bool> onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final draft = item.status == MenuItemStatus.draft;
    final sizes = item.activeSizes;
    final worst = item.worstMarginSize;
    final single = sizes.length == 1 ? sizes.first : null;
    final lines = <Widget>[];

    lines.add(Text(priceSummary(item) + (single != null && single.cost != null ? ' · Vốn ${formatVnd(single.cost!)}' : ''),
        style: AppTextStyles.body));

    if (draft) {
      lines.add(Text('Bản nháp · chưa bán', style: AppTextStyles.caption));
    } else if (item.missingRecipe) {
      lines.add(Text(
        item.sizesMissingRecipe == sizes.length
            ? '! Thiếu công thức · Vốn/lãi chưa xác định'
            : '! ${item.sizesMissingRecipe} size thiếu công thức',
        style: TextStyle(
            color: AppColors.statusAttention,
            fontWeight: FontWeight.w600,
            fontSize: 12),
      ));
    } else if (worst != null && worst.marginPct! < lowMarginPct) {
      lines.add(Text(
        '! Lãi gộp ${formatVnd(worst.margin!)} · ${formatPct(worst.marginPct!)} · Lãi thấp',
        style: TextStyle(
            color: AppColors.statusAttention,
            fontWeight: FontWeight.w600,
            fontSize: 12),
      ));
    } else if (item.bestSeller) {
      lines.add(Text(
        '✦ Bán chạy tuần này${weekLabelText.isEmpty ? '' : ' · $weekLabelText'}',
        style: AppTextStyles.caption,
      ));
    } else {
      lines.add(Text(
        '✓ Đủ công thức · ${sizes.length} size',
        style: AppTextStyles.caption,
      ));
    }

    return MenuCard(
      onTap: onOpen,
      child: Row(
        children: [
          MenuThumb(path: item.imagePath, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.cardTitle),
                const SizedBox(height: 2),
                ...lines,
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (draft)
            const StatusChip(
                label: 'Bản nháp',
                severity: StatusSeverity.neutral,
                compact: true)
          else
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: item.status == MenuItemStatus.selling,
                  onChanged: readOnly ? null : onToggle,
                ),
                Text(
                  item.status == MenuItemStatus.selling
                      ? 'Đang bán'
                      : 'Ngừng bán',
                  style: AppTextStyles.micro,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.store, required this.data});

  final MenuStore store;
  final MenuOverview data;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${menuShopName(context)} · Chỉ xem bản đã tải',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: 8),
            MenuBanner(
              kind: BannerKind.error,
              title: store.networkFailure
                  ? '~ Mất kết nối · Chỉ xem'
                  : 'Chưa cập nhật được · Chỉ xem',
              body:
                  'Giá và trạng thái có thể đã thay đổi. Chưa thể đăng món, đổi giá hay bật/tắt bán.',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusAttentionTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Lần đồng bộ cuối: ${dateTimeLabel(data.fetchedAt)}',
                  style: AppTextStyles.micro),
            ),
          ],
        ),
      );
}

class _EmptyMenu extends StatelessWidget {
  const _EmptyMenu();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.backgroundTint,
                borderRadius: BorderRadius.circular(AppSizes.radiusCard),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 36),
                    const SizedBox(height: 10),
                    Text('Món đầu tiên, chỉ cần tên và giá.',
                        style: AppTextStyles.headline),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            MenuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Không cần hoàn thiện ngay', style: AppTextStyles.cardTitle),
                  const SizedBox(height: 6),
                  Text('1. Đặt tên và chọn nhóm món.', style: AppTextStyles.body),
                  Text('2. Thêm size cùng giá bán riêng.', style: AppTextStyles.body),
                  Text('3. Lưu bản nháp, thêm công thức sau.', style: AppTextStyles.body),
                  const SizedBox(height: 6),
                  Text('Món mới mặc định chưa bán. Chỉ bật bán khi bạn sẵn sàng.',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
            Text(
              'Khi thêm công thức, Fore giúp bạn nhìn rõ giá vốn và lãi gộp ước tính bên cạnh từng size.',
              style: AppTextStyles.caption,
            ),
          ],
        ),
      );
}

class _NoResult extends StatelessWidget {
  const _NoResult({required this.store});

  final MenuStore store;

  @override
  Widget build(BuildContext context) {
    final f = store.filters;
    final query = f.query.trim();
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 40, color: AppColors.brandAccent),
          const SizedBox(height: 10),
          Text(
            query.isEmpty ? 'Không có món nào khớp bộ lọc.' : 'Chưa gặp món bạn đang tìm.',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            query.isEmpty
                ? 'Thử bỏ bớt bộ lọc để xem lại các món.'
                : 'Không có món khớp "$query"${f.category != null ? ' trong nhóm ${f.category}' : ''}. Thực đơn của bạn vẫn còn nguyên.',
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          if (query.isNotEmpty)
            MenuSecondaryButton(
              label: 'Xóa riêng từ khóa',
              onPressed: () => store.setQuery(''),
            ),
          if (query.isNotEmpty) const SizedBox(height: 8),
          MenuSecondaryButton(
            label: 'Đặt lại bộ lọc',
            onPressed: store.resetFilters,
          ),
        ],
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.store});

  final MenuStore store;

  @override
  Widget build(BuildContext context) => LazyListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.cloud_off_outlined, size: 40, color: AppColors.brandAccent),
          const SizedBox(height: 12),
          Text(
            store.networkFailure
                ? 'Không có kết nối'
                : 'Chưa tải được thực đơn',
            style: AppTextStyles.headline,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            store.failure == null ? '' : menuErrorMessage(store.failure!),
            style: AppTextStyles.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          MenuPrimaryButton(label: 'Thử lại', onPressed: store.load),
        ],
      );
}
