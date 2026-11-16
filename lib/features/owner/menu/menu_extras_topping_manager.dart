part of 'menu_extras_views.dart';

class ToppingManagerPage extends StatefulWidget {
  const ToppingManagerPage({super.key});

  @override
  State<ToppingManagerPage> createState() => _ToppingManagerPageState();
}

class _ToppingManagerPageState extends State<ToppingManagerPage> {
  List<ToppingInfo>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await context.read<MenuStore>().loadToppings();
      if (mounted) setState(() => _items = r);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _edit([ToppingInfo? t]) async {
    await openMenuPage<void>(context, ToppingEditPage(existing: t));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return MenuPage(
      title: 'Topping của quán',
      subtitle: menuShopName(context),
      primary: MenuPrimaryButton(label: '+ Thêm topping', onPressed: () => _edit()),
      children: [
        if (_error != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được topping',
            body: menuErrorMessage(_error!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (items == null)
          const MenuSkeleton(rows: 3)
        else if (items.isEmpty)
          const MenuBanner(
            kind: BannerKind.info,
            title: 'Chưa có topping',
            body: 'Tạo topping như trân châu, thạch, kem sữa rồi gắn vào từng món.',
          )
        else
          for (final t in items)
            MenuCard(
              onTap: () => _edit(t),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: AppTextStyles.cardTitle),
                        Text(
                          '＋${formatVnd(t.price)} / phần · ${t.hasRecipe ? '${t.qty} ${menuUnitLabel(t.unit ?? '')} ${t.ingredientName ?? ''}${t.cost == null ? ' · vốn chưa xác định' : ' · vốn ${formatVnd(t.cost!)}'}' : 'Chưa có định lượng'}',
                          style: AppTextStyles.caption,
                        ),
                        Text('${t.usedBy} món đang bán kèm', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Text(t.active ? 'Có thể bán' : 'Tạm ngừng',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
      ],
    );
  }
}

