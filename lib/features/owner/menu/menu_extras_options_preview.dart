part of 'menu_extras_views.dart';

class OptionsPreviewPage extends StatefulWidget {
  const OptionsPreviewPage({super.key, required this.detail});

  final ItemDetail detail;

  @override
  State<OptionsPreviewPage> createState() => _OptionsPreviewPageState();
}

class _OptionsPreviewPageState extends State<OptionsPreviewPage> {
  ItemExtras? _extras;
  Object? _error;
  int _sizeIndex = 0;
  final Set<String> _toppings = {};
  final Map<String, String> _choices = {}; // groupId -> choiceId

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final e = await context.read<MenuStore>().loadExtras(widget.detail.id);
      if (!mounted) return;
      setState(() {
        _extras = e;
        for (final g in e.groups) {
          final d = g.defaultChoice;
          if (d != null) _choices[g.id] = d.id;
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final sizes = detail.activeSizes;
    final extras = _extras;
    if (sizes.isEmpty) {
      return MenuPage(title: 'Xem trước lựa chọn', subtitle: detail.name, children: const [
        MenuBanner(kind: BannerKind.info, title: 'Món chưa có size đang bán'),
      ]);
    }
    final size = sizes[_sizeIndex.clamp(0, sizes.length - 1)];

    var price = size.price;
    int? cost = size.cost;
    final lines = <(String, int, int?)>[];
    if (extras != null) {
      for (final t in extras.selectedToppings) {
        if (!_toppings.contains(t.id)) continue;
        price += t.price;
        lines.add(('${t.name} · 1 phần', t.price, t.hasRecipe ? t.cost : 0));
        if (cost != null) {
          if (t.hasRecipe && t.cost == null) {
            cost = null;
          } else {
            cost += t.cost ?? 0;
          }
        }
      }
      for (final g in extras.groups) {
        final c = g.choices.where((x) => x.id == _choices[g.id]).firstOrNull;
        if (c == null) continue;
        price += c.priceDelta;
        int? ccost = 0;
        if (c.ingredientId != null) {
          ccost = c.unitCost == null ? null : ((c.qty ?? 0) * c.unitCost!).round();
          if (cost != null) cost = ccost == null ? null : cost + ccost;
        }
        lines.add(('${g.name}: ${c.name}', c.priceDelta, ccost));
      }
    }
    final margin = cost == null ? null : price - cost;

    return MenuPage(
      title: 'Xem trước lựa chọn',
      subtitle: 'Dành cho chủ quán · Không tạo đơn bán hàng',
      primary: MenuPrimaryButton(
        label: 'Về thiết lập món',
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        SizeTabs(
          labels: [for (final s in sizes) s.name],
          selected: _sizeIndex.clamp(0, sizes.length - 1),
          onChanged: (i) => setState(() => _sizeIndex = i),
        ),
        if (_error != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được thiết lập',
            body: menuErrorMessage(_error!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (extras == null)
          const MenuSkeleton(rows: 3)
        else ...[
          if (extras.selectedToppings.isEmpty && extras.groups.isEmpty)
            const MenuBanner(
              kind: BannerKind.info,
              title: 'Món chưa có topping hay tùy chọn',
              body: 'Thiết lập ở màn chi tiết món rồi quay lại xem trước.',
            ),
          for (final g in extras.groups)
            MenuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(g.name, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in g.choices)
                        OptionChip(
                          label: c.name,
                          selected: _choices[g.id] == c.id,
                          onTap: () => setState(() {
                            if (_choices[g.id] == c.id && !g.required) {
                              _choices.remove(g.id);
                            } else {
                              _choices[g.id] = c.id;
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (extras.selectedToppings.isNotEmpty)
            MenuCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Topping · tối đa ${extras.maxKinds} loại', style: AppTextStyles.cardTitle),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in extras.selectedToppings)
                        OptionChip(
                          label: '${t.name} ＋${formatThousands(t.price)}',
                          selected: _toppings.contains(t.id),
                          onTap: () => setState(() {
                            if (!_toppings.remove(t.id) && _toppings.length < extras.maxKinds) {
                              _toppings.add(t.id);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          MenuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Lựa chọn mẫu', style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                _row('${detail.name} · ${size.name}', formatVnd(size.price)),
                for (final l in lines) _row(l.$1, formatVnd(l.$2)),
                const Divider(),
                _row('Tổng cộng', formatVnd(price), strong: true),
                const SizedBox(height: 6),
                _row(
                  'Giá vốn ước tính',
                  size.cost == null
                      ? 'Chưa xác định'
                      : cost == null
                          ? 'Chưa xác định'
                          : formatVnd(cost),
                  strong: true,
                ),
                if (size.current != null)
                  Text('Công thức ${size.name} · v${size.current!.versionNo}',
                      style: AppTextStyles.caption),
              ],
            ),
          ),
          MenuMarginHero(
            label: 'XEM TRƯỚC · LỰA CHỌN MẪU',
            price: price,
            cost: cost,
            lowMarginPct: detail.lowMarginPct,
          ),
          Text(
            margin == null
                ? 'Lãi gộp chưa xác định vì thiếu công thức hoặc giá nguyên liệu.'
                : 'Lãi gộp ước tính, chưa trừ thuê mặt bằng, nhân công và phí nền tảng.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 6),
          Text(
            'Ít đá / ít đường chỉ là chỉ dẫn pha chế. Lượng trừ kho và vốn công thức gốc không đổi khi chưa thiết lập định lượng riêng.',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }

  Widget _row(String a, String b, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(a, style: strong ? AppTextStyles.bodyStrong : AppTextStyles.body)),
            Text(b, style: strong ? AppTextStyles.bodyStrong : AppTextStyles.body),
          ],
        ),
      );
}
