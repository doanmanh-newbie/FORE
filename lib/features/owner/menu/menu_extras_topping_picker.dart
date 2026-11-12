part of 'menu_extras_views.dart';

class ToppingPickerPage extends StatefulWidget {
  const ToppingPickerPage({super.key, required this.detail});

  final ItemDetail detail;

  @override
  State<ToppingPickerPage> createState() => _ToppingPickerPageState();
}

class _ToppingPickerPageState extends State<ToppingPickerPage> {
  ItemExtras? _extras;
  Object? _loadError;
  final Set<String> _selected = {};
  int _maxKinds = 2;
  int _maxPortions = 1;
  bool _saving = false;
  Object? _error;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final e = await context.read<MenuStore>().loadExtras(widget.detail.id);
      if (!mounted) return;
      setState(() {
        _extras = e;
        _selected
          ..clear()
          ..addAll([for (final t in e.toppings) if (t.selected && t.active) t.id]);
        _maxKinds = e.maxKinds;
        _maxPortions = e.maxPortions;
        _clampKinds();
      });
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _clampKinds() {
    final cap = _selected.isEmpty ? 1 : _selected.length;
    if (_maxKinds > cap) _maxKinds = cap;
    if (_maxKinds < 1) _maxKinds = 1;
  }

  Future<void> _save() async {
    final store = context.read<MenuStore>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await store.saveItemToppings(
          widget.detail.id, _selected.toList(), _maxKinds, _maxPortions);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _manage() async {
    await openMenuPage<void>(context, const ToppingManagerPage());
    if (mounted) await _load();
  }

  Widget _stepper(String label, int value, int min, int max, ValueChanged<int> onChanged) =>
      Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          IconButton(
            tooltip: 'Giảm $label',
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
          ),
          SizedBox(
            width: 28,
            child: Text('$value',
                textAlign: TextAlign.center, style: AppTextStyles.bodyStrong),
          ),
          IconButton(
            tooltip: 'Tăng $label',
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final extras = _extras;
    final detail = widget.detail;
    return MenuPage(
      title: 'Chọn topping',
      subtitle: '${detail.name} · ${menuShopName(context)}',
      primary: MenuPrimaryButton(
        label: 'Lưu topping cho món',
        loading: _saving,
        onPressed: extras == null || !_dirty ? null : _save,
      ),
      secondary: MenuSecondaryButton(
        label: 'Hủy',
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
      ),
      children: [
        if (_loadError != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được topping',
            body: menuErrorMessage(_loadError!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (extras == null)
          const MenuSkeleton(rows: 3)
        else ...[
          Text(
            'Đánh dấu topping được phép bán kèm. Áp dụng cùng thiết lập cho ${detail.activeSizes.map((s) => s.name).join(', ')}.',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 10),
          if (_error != null)
            MenuBanner(
              kind: BannerKind.error,
              title: 'Chưa lưu được',
              body: menuErrorMessage(_error!),
            ),
          if (extras.toppings.isEmpty)
            const MenuBanner(
              kind: BannerKind.info,
              title: 'Quán chưa có topping nào',
              body: 'Bấm "Thêm / quản lý topping" để tạo topping đầu tiên.',
            ),
          for (final t in extras.toppings)
            MenuCard(
              onTap: !t.active
                  ? null
                  : () => setState(() {
                        _dirty = true;
                        if (!_selected.remove(t.id)) _selected.add(t.id);
                        _clampKinds();
                      }),
              borderColor:
                  _selected.contains(t.id) ? AppColors.brand : AppColors.cardBorder,
              child: Row(
                children: [
                  Icon(
                    _selected.contains(t.id)
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: t.active ? AppColors.brand : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: AppTextStyles.cardTitle),
                        Text('＋${formatVnd(t.price)} / phần', style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Text(t.active ? 'Có thể bán' : 'Tạm ngừng bán',
                      style: AppTextStyles.caption),
                ],
              ),
            ),
          MenuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nhóm không bắt buộc', style: AppTextStyles.cardTitle),
                const Text('Khách mặc định không chọn topping.',
                    style: AppTextStyles.caption),
                const SizedBox(height: 6),
                _stepper('Tối đa loại', _maxKinds, 1,
                    _selected.isEmpty ? 1 : _selected.length,
                    (v) => setState(() {
                          _maxKinds = v;
                          _dirty = true;
                        })),
                _stepper('Tối đa phần / loại', _maxPortions, 1, 5,
                    (v) => setState(() {
                          _maxPortions = v;
                          _dirty = true;
                        })),
                Text(
                  'Tối thiểu 0 · Tối đa $_maxKinds loại, mỗi loại $_maxPortions phần.',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          MenuActionRow(
            icon: Icons.tune_rounded,
            title: 'Thêm / quản lý topping',
            subtitle: 'Giá, định lượng và trạng thái tại quán',
            onTap: _manage,
          ),
          Text(
            'Giá ${_sizePrices(detail)} không đổi. Giá và vốn topping được tính riêng khi khách chọn, không gộp vào lãi của món gốc.',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quản lý topping của quán
// ---------------------------------------------------------------------------

