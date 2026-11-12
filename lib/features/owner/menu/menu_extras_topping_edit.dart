part of 'menu_extras_views.dart';

class ToppingEditPage extends StatefulWidget {
  const ToppingEditPage({super.key, this.existing});

  final ToppingInfo? existing;

  @override
  State<ToppingEditPage> createState() => _ToppingEditPageState();
}

class _ToppingEditPageState extends State<ToppingEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _price =
      TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.price}');
  late bool _active = widget.existing?.active ?? true;
  DraftRecipeLine? _recipe;
  bool _recipeCleared = false;
  bool _saving = false;
  String? _nameError;
  String? _priceError;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final t = widget.existing;
    if (t != null && t.ingredientId != null && t.qty != null) {
      _recipe = DraftRecipeLine(
        ingredientId: t.ingredientId!,
        name: t.ingredientName ?? '',
        unit: t.unit ?? '',
        qty: t.qty!,
        unitCost: t.unitCost,
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _pickIngredient() async {
    final line = await openMenuPage<DraftRecipeLine>(
      context,
      IngredientPickerPage(
        sizeName: '',
        purpose: 'Định lượng cho 1 phần topping',
        existing: const [],
      ),
    );
    if (line != null && mounted) setState(() => _recipe = line);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = int.tryParse(_price.text.trim());
    setState(() {
      _nameError = name.isEmpty ? 'Nhập tên topping' : null;
      _priceError = price == null ? 'Nhập giá bán thêm (có thể là 0đ)' : null;
    });
    if (_nameError != null || _priceError != null) return;
    final store = context.read<MenuStore>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await store.saveTopping(
        id: widget.existing?.id,
        name: name,
        price: price!,
        ingredientId: _recipe?.ingredientId,
        qty: _recipe?.qty,
        active: _active,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final recipe = _recipe;
    return MenuPage(
      title: editing ? 'Sửa topping' : 'Thêm topping',
      subtitle: menuShopName(context),
      primary: MenuPrimaryButton(
        label: editing ? 'Lưu topping' : 'Thêm topping',
        loading: _saving,
        onPressed: _save,
      ),
      children: [
        if (_error != null)
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa lưu được topping',
            body: menuErrorMessage(_error!),
          ),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: 'Tên topping *', errorText: _nameError),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _price,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          decoration: InputDecoration(
            labelText: 'Giá bán thêm / phần',
            suffixText: 'đ',
            errorText: _priceError,
          ),
        ),
        const SizedBox(height: 12),
        MenuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Định lượng (không bắt buộc)', style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text(
                recipe == null
                    ? 'Chưa có. Thêm nguyên liệu và lượng cho 1 phần để tính giá vốn topping.'
                    : '${recipe.qty} ${menuUnitLabel(recipe.unit)} ${recipe.name}${recipe.lineCost == null ? ' · chưa có giá nguyên liệu' : ' · vốn ${formatVnd(recipe.lineCost!)}'}',
                style: AppTextStyles.body,
              ),
              Row(
                children: [
                  TextButton(
                    onPressed: _pickIngredient,
                    child: Text(recipe == null ? 'Chọn nguyên liệu' : 'Đổi nguyên liệu'),
                  ),
                  if (recipe != null)
                    TextButton(
                      onPressed: () => setState(() {
                        _recipe = null;
                        _recipeCleared = true;
                      }),
                      child: const Text('Bỏ định lượng'),
                    ),
                ],
              ),
              if (_recipeCleared && editing)
                const Text('Bỏ định lượng thì topping không trừ kho và không tính vốn.',
                    style: AppTextStyles.caption),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Đang bán'),
          subtitle: const Text('Tắt để tạm ngừng bán, không xóa topping.'),
          value: _active,
          onChanged: (v) => setState(() => _active = v),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tùy chọn pha chế
// ---------------------------------------------------------------------------

