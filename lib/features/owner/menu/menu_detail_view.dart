import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../../../core/widgets/status_chip.dart';
import 'menu_copy_views.dart';
import 'menu_extras_views.dart';
import 'menu_image_view.dart';
import 'menu_format.dart';
import 'menu_history_views.dart';
import 'menu_item_form_view.dart';
import 'menu_models.dart';
import 'menu_price_view.dart';
import 'menu_recipe_views.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// Chi tiết một món: giá vốn, lãi gộp, công thức đang dùng và các thao tác.
class MenuDetailPage extends StatefulWidget {
  const MenuDetailPage({super.key, required this.itemId});

  final String itemId;

  @override
  State<MenuDetailPage> createState() => _MenuDetailPageState();
}

class _MenuDetailPageState extends State<MenuDetailPage> {
  ItemDetail? _detail;
  Object? _error;
  bool _loading = true;
  int _size = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool keepSize = true}) async {
    setState(() {
      _loading = _detail == null;
      _error = null;
    });
    try {
      final detail = await context.read<MenuStore>().loadDetail(widget.itemId);
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _loading = false;
        final count = detail.activeSizes.length;
        if (!keepSize || _size >= count) _size = 0;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _open(Widget page) async {
    await openMenuPage<void>(context, page);
    if (mounted) await _load();
  }

  Future<void> _toggleActive(ItemDetail detail) async {
    final store = context.read<MenuStore>();
    if (detail.status == MenuItemStatus.selling) {
      final ok = await confirmSheet(
        context,
        title: 'Tạm ngừng bán món này?',
        message:
            'Món sẽ không xuất hiện cho lần chọn bán mới. Bill đang mở, doanh thu và lịch sử bán hàng cũ vẫn còn nguyên. '
            'Không xóa món đã bán. Bạn có thể bật bán lại bất cứ lúc nào.',
        confirmLabel: 'Tạm ngừng bán',
        cancelLabel: 'Giữ đang bán',
        extra: [
          const SizedBox(height: 10),
          StatusChip(
            label: 'Chỉ ${menuShopName(context)} · Có ${detail.activeSizes.length} size',
            severity: StatusSeverity.attention,
            compact: true,
          ),
        ],
      );
      if (!ok || !mounted) return;
    }
    setState(() => _busy = true);
    await menuGuard(
        context,
        () => store.setActive(
            detail.id, detail.status != MenuItemStatus.selling));
    if (mounted) {
      setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _publish(ItemDetail detail) async {
    setState(() => _busy = true);
    await menuGuard(context, () => context.read<MenuStore>().publish(detail.id));
    if (mounted) {
      setState(() => _busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    if (detail == null) {
      return MenuPage(
        title: 'Chi tiết món',
        children: [
          if (_loading) const MenuSkeleton(rows: 3),
          if (!_loading && _error != null) ...[
            MenuBanner(
              kind: BannerKind.error,
              title: 'Chưa tải được món này',
              body: menuErrorMessage(_error!),
            ),
            MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
          ],
        ],
      );
    }

    final sizes = detail.activeSizes;
    final size = sizes.isEmpty ? null : sizes[_size.clamp(0, sizes.length - 1)];
    final everSold = detail.sizes.any((s) => s.everSold);
    final draft = detail.status == MenuItemStatus.draft;
    final selling = detail.status == MenuItemStatus.selling;
    final lowPct = detail.lowMarginPct;
    final missingSizes = sizes.where((s) => s.current == null).toList();

    return MenuPage(
      title: detail.name,
      subtitle: [
        detail.category ?? 'Khác',
        if (draft) 'Bản nháp · chưa bán' else if (everSold) 'Đã có giao dịch bán' else 'Chưa có giao dịch bán',
      ].join(' · '),
      primary: size == null
          ? null
          : MenuPrimaryButton(
              label: size.current == null
                  ? 'Thêm công thức size ${size.name}'
                  : 'Sửa công thức size ${size.name}',
              onPressed: () => _open(
                  RecipeEditorPage(detail: detail, initialSizeId: size.id)),
            ),
      children: [
        MenuCard(
          child: Row(
            children: [
              MenuThumb(path: detail.imagePath, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(menuShopName(context), style: AppTextStyles.cardTitle),
                    Text(
                      draft
                          ? '— Bản nháp, chưa bán'
                          : selling
                              ? '✓ Đang bán'
                              : '— Ngừng bán',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              if (draft)
                FilledButton(
                  onPressed: _busy || sizes.isEmpty ? null : () => _publish(detail),
                  style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
                  child: const Text('Mở bán'),
                )
              else
                Switch(
                  value: selling,
                  onChanged: _busy ? null : (_) => _toggleActive(detail),
                ),
            ],
          ),
        ),
        if (draft)
          const MenuBanner(
            kind: BannerKind.info,
            title: 'Món chưa hiện ở màn bán hàng',
            body: 'Hoàn thiện công thức rồi bấm "Mở bán" khi bạn sẵn sàng.',
          ),
        if (sizes.isNotEmpty) ...[
          SizeTabs(
            labels: [for (final s in sizes) '${s.name} · ${formatVnd(s.price)}'],
            selected: _size.clamp(0, sizes.length - 1),
            onChanged: (i) => setState(() => _size = i),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in sizes)
                  StatusChip(
                    label: '${s.name} ${s.current == null ? 'Thiếu' : '✓ Đủ'}',
                    severity: s.current == null
                        ? StatusSeverity.attention
                        : StatusSeverity.healthy,
                    compact: true,
                  ),
              ],
            ),
          ),
          if (size != null) ...[
            MenuMarginHero(
              label: 'Size ${size.name} · Giá đang áp dụng',
              price: size.price,
              cost: size.cost,
              lowMarginPct: lowPct,
            ),
            _RecipeSummary(
              detail: detail,
              size: size,
              onOpen: () => _open(RecipeComparePage(detail: detail, sizeId: size.id)),
            ),
            if (size.scheduled != null)
              MenuBanner(
                kind: BannerKind.info,
                title: 'Công thức v${size.scheduled!.versionNo} đã hẹn',
                body:
                    'Áp dụng ${dateTimeLong(size.scheduled!.effectiveFrom ?? DateTime.now())}. Đến lúc đó v${size.current?.versionNo ?? '-'} vẫn đang dùng.',
              ),
            if (size.pendingPrice != null)
              MenuBanner(
                kind: BannerKind.info,
                title: 'Giá ${formatVnd(size.pendingPrice!.newPrice)} đã hẹn',
                body:
                    'Áp dụng ${dateTimeLong(size.pendingPrice!.effectiveFrom)}. Bill cũ giữ nguyên giá đã bán.',
              ),
          ],
        ],
        if (missingSizes.isNotEmpty)
          MenuBanner(
            kind: BannerKind.warning,
            title:
                '${missingSizes.map((s) => s.name).join(', ')} chưa có công thức',
            body:
                'Vẫn lưu được món. Giá vốn/lãi chưa xác định; báo cáo đối soát có thể thiếu chính xác.',
          ),
        const SizedBox(height: 4),
        MenuActionRow(
          icon: Icons.edit_outlined,
          title: 'Sửa tên, nhóm và size',
          subtitle: 'Thêm size mới, bỏ size không bán',
          onTap: () => _open(MenuItemFormPage(existing: detail)),
        ),
        MenuActionRow(
          icon: Icons.sell_outlined,
          title: 'Đổi giá theo size',
          subtitle: 'Giá bán tách biệt với công thức',
          onTap: sizes.isEmpty ? null : () => _open(PriceChangePage(detail: detail)),
        ),
        MenuActionRow(
          icon: Icons.image_outlined,
          title: 'Ảnh món',
          subtitle: (detail.imagePath ?? '').isEmpty
              ? 'Chưa có ảnh · Không bắt buộc'
              : 'Đổi hoặc gỡ ảnh hiện tại',
          onTap: () => _open(MenuImagePage(detail: detail)),
        ),
        MenuActionRow(
          icon: Icons.add_circle_outline_rounded,
          title: 'Topping bán kèm',
          subtitle: 'Chọn topping, giới hạn số loại và số phần',
          onTap: () => _open(ToppingPickerPage(detail: detail)),
        ),
        MenuActionRow(
          icon: Icons.tune_rounded,
          title: 'Tùy chọn pha chế',
          subtitle: 'Mức đá, mức đường... áp dụng cho mọi size',
          onTap: () => _open(OptionsSetupPage(detail: detail)),
        ),
        MenuActionRow(
          icon: Icons.visibility_outlined,
          title: 'Xem trước lựa chọn',
          subtitle: 'Giá, vốn và lãi của một lựa chọn mẫu',
          onTap: sizes.isEmpty ? null : () => _open(OptionsPreviewPage(detail: detail)),
        ),
        MenuActionRow(
          icon: Icons.copy_rounded,
          title: 'Sao chép món',
          subtitle: 'Tạo bản nháp độc lập tại quán này',
          onTap: () => _open(CopyItemPage(detail: detail)),
        ),
        MenuActionRow(
          icon: Icons.storefront_outlined,
          title: 'Sao chép sang quán khác',
          subtitle: 'Tạo bản nháp cho quán bạn sở hữu',
          onTap: () => _open(CopyToShopPage(detail: detail)),
        ),
        MenuActionRow(
          icon: Icons.history_rounded,
          title: 'Lịch sử thay đổi',
          subtitle: 'Xem tất cả thay đổi giá, công thức và trạng thái bán',
          onTap: () => _open(MenuHistoryPage(itemId: detail.id, itemName: detail.name)),
        ),
        MenuActionRow(
          icon: Icons.compare_arrows_rounded,
          title: 'So sánh công thức',
          subtitle: 'Xem chênh lệch giữa các phiên bản',
          onTap: sizes.isEmpty
              ? null
              : () => _open(RecipeComparePage(
                  detail: detail, sizeId: size?.id ?? sizes.first.id)),
        ),
        if (!draft)
          MenuActionRow(
            icon: selling ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
            title: selling ? 'Tạm ngừng bán' : 'Mở bán lại',
            subtitle: selling
                ? 'Giữ nguyên bill và lịch sử · Có thể bán lại'
                : 'Món sẽ hiện lại ở màn bán hàng',
            onTap: _busy ? null : () => _toggleActive(detail),
          ),
      ],
    );
  }
}

class _RecipeSummary extends StatelessWidget {
  const _RecipeSummary({
    required this.detail,
    required this.size,
    required this.onOpen,
  });

  final ItemDetail detail;
  final SizeDetail size;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final current = size.current;
    final others = detail.activeSizes.where((s) => s.id != size.id).toList();
    return MenuCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  current == null
                      ? 'Công thức ${size.name} · Chưa có'
                      : 'Công thức ${size.name} · v${current.versionNo} đang dùng',
                  style: AppTextStyles.cardTitle,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
          if (current != null)
            Text(
              '${current.effectiveFrom == null || current.effectiveFrom!.year < 2000 ? 'Từ đầu' : 'Từ ${dateTimeLabel(current.effectiveFrom!)}'} · ${current.lines.length} nguyên liệu',
              style: AppTextStyles.caption,
            )
          else
            Text('Thêm công thức để biết giá vốn và lãi gộp.',
                style: AppTextStyles.caption),
          for (final other in others)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_sizeLine(other), style: AppTextStyles.caption),
            ),
        ],
      ),
    );
  }

  String _sizeLine(SizeDetail s) {
    if (s.cost == null) return '${s.name}: chưa có giá vốn';
    return '${s.name}: vốn ${formatThousands(s.cost!)} · lãi ${formatThousands(s.margin!)} (${formatPct(s.marginPct!)})';
  }
}
