part of 'menu_extras_views.dart';

class OptionsSetupPage extends StatefulWidget {
  const OptionsSetupPage({super.key, required this.detail});

  final ItemDetail detail;

  @override
  State<OptionsSetupPage> createState() => _OptionsSetupPageState();
}

class _OptionsSetupPageState extends State<OptionsSetupPage> {
  List<DraftOptionGroup>? _groups;
  Object? _loadError;
  Object? _error;
  String? _validation;
  bool _saving = false;
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
      if (mounted) {
        setState(() => _groups = [for (final g in e.groups) DraftOptionGroup.from(g)]);
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _touch(VoidCallback f) => setState(() {
        f();
        _dirty = true;
        _validation = null;
      });

  void _addPreset(String name, List<String> choices, String def) => _touch(() {
        _groups!.add(DraftOptionGroup(
          name: name,
          choices: [
            for (final c in choices) DraftOptionChoice(name: c, isDefault: c == def),
          ],
        ));
      });

  String? _check() {
    final seen = <String>{};
    for (final g in _groups!) {
      final name = g.name.trim();
      if (name.isEmpty) return 'Nhóm tùy chọn cần có tên.';
      if (!seen.add(foldVietnamese(name))) return 'Có hai nhóm trùng tên "$name".';
      if (g.choices.isEmpty) return 'Nhóm "$name" cần ít nhất một lựa chọn.';
      final names = <String>{};
      for (final c in g.choices) {
        if (c.name.trim().isEmpty) return 'Nhóm "$name" có lựa chọn chưa đặt tên.';
        if (!names.add(foldVietnamese(c.name.trim()))) {
          return 'Nhóm "$name" có hai lựa chọn trùng tên "${c.name.trim()}".';
        }
        if (c.ingredientId != null && (c.qty ?? 0) <= 0) {
          return 'Định lượng riêng của "${c.name.trim()}" phải lớn hơn 0.';
        }
      }
      final defaults = g.choices.where((c) => c.isDefault).length;
      if (g.required && defaults != 1) return 'Nhóm "$name" bắt buộc chọn nên cần đúng 1 lựa chọn mặc định.';
      if (!g.required && defaults > 1) return 'Nhóm "$name" chỉ được có tối đa 1 lựa chọn mặc định.';
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _check();
    if (problem != null) {
      setState(() => _validation = problem);
      return;
    }
    final store = context.read<MenuStore>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await store.saveOptions(widget.detail.id, _groups!);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickRecipe(DraftOptionChoice c) async {
    final line = await openMenuPage<DraftRecipeLine>(
      context,
      IngredientPickerPage(
        sizeName: '',
        purpose: 'Định lượng riêng cho "${c.name.trim().isEmpty ? 'lựa chọn' : c.name.trim()}"',
        existing: const [],
      ),
    );
    if (line == null || !mounted) return;
    _touch(() {
      c.ingredientId = line.ingredientId;
      c.ingredientName = line.name;
      c.unit = line.unit;
      c.qty = line.qty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    return MenuPage(
      title: 'Tùy chọn pha chế',
      subtitle: '${widget.detail.name} · Áp dụng cho ${widget.detail.activeSizes.map((s) => s.name).join(', ')}',
      primary: MenuPrimaryButton(
        label: 'Lưu tùy chọn pha chế',
        loading: _saving,
        onPressed: groups == null || !_dirty ? null : _save,
      ),
      secondary: MenuSecondaryButton(
        label: 'Hủy',
        onPressed: _saving ? null : () => Navigator.of(context).pop(false),
      ),
      children: [
        if (_loadError != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được tùy chọn',
            body: menuErrorMessage(_loadError!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (groups == null)
          const MenuSkeleton(rows: 3)
        else ...[
          if (_validation != null)
            MenuBanner(kind: BannerKind.error, title: 'Cần sửa trước khi lưu', body: _validation),
          if (_error != null)
            MenuBanner(
              kind: BannerKind.error,
              title: 'Chưa lưu được',
              body: menuErrorMessage(_error!),
            ),
          if (groups.isEmpty)
            const MenuBanner(
              kind: BannerKind.info,
              title: 'Chưa thiết lập',
              body:
                  'Cấu hình nguyên liệu rõ ràng nếu cần đối soát chính xác. Thêm nhóm như Mức đá, Mức đường để barista pha đúng ý khách.',
            ),
          for (var gi = 0; gi < groups.length; gi++) _groupCard(groups, gi),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => _addPreset('Mức đá', const ['Không', 'Ít', 'Bình thường'], 'Bình thường'),
                child: const Text('+ Mức đá'),
              ),
              OutlinedButton(
                onPressed: () => _addPreset('Mức đường', const ['Ít', 'Bình thường', 'Nhiều'], 'Bình thường'),
                child: const Text('+ Mức đường'),
              ),
              OutlinedButton(
                onPressed: () => _touch(() => groups.add(DraftOptionGroup(name: '', choices: [
                      DraftOptionChoice(name: '', isDefault: true),
                    ]))),
                child: const Text('+ Nhóm khác'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ít đá / ít đường không tự giảm lượng trừ kho hoặc giá vốn lý thuyết. Công thức gốc vẫn được giữ nguyên. '
            'Chỉ lựa chọn có "định lượng riêng" mới trừ kho và tính vốn riêng.',
            style: AppTextStyles.caption,
          ),
        ],
      ],
    );
  }

  Widget _groupCard(List<DraftOptionGroup> groups, int gi) {
    final g = groups[gi];
    return MenuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  key: ValueKey('g${gi}_${g.id}_${g.hashCode}'),
                  initialValue: g.name,
                  onChanged: (v) {
                    g.name = v;
                    _dirty = true;
                    if (_validation != null) setState(() => _validation = null);
                  },
                  decoration: const InputDecoration(labelText: 'Tên nhóm'),
                ),
              ),
              IconButton(
                tooltip: 'Bỏ nhóm ${g.name}',
                onPressed: () => _touch(() => groups.removeAt(gi)),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(g.required ? 'Bắt buộc chọn 1' : 'Không bắt buộc'),
            value: g.required,
            onChanged: (v) => _touch(() => g.required = v),
          ),
          for (var ci = 0; ci < g.choices.length; ci++) _choiceRow(g, ci),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _touch(() => g.choices.add(DraftOptionChoice(name: ''))),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Thêm lựa chọn'),
              ),
            ],
          ),
          Text(
            g.required
                ? 'Tối thiểu 1, tối đa 1 lựa chọn. Chấm tròn là lựa chọn mặc định.'
                : 'Có thể không chọn. Chấm tròn là lựa chọn mặc định (nếu có).',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  Widget _choiceRow(DraftOptionGroup g, int ci) {
    final c = g.choices[ci];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: c.isDefault ? 'Mặc định' : 'Đặt làm mặc định',
                onPressed: () => _touch(() {
                  final was = c.isDefault;
                  for (final x in g.choices) {
                    x.isDefault = false;
                  }
                  c.isDefault = g.required ? true : !was;
                }),
                icon: Icon(c.isDefault
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked),
              ),
              Expanded(
                child: TextFormField(
                  key: ValueKey('c${g.hashCode}_${ci}_${c.hashCode}'),
                  initialValue: c.name,
                  onChanged: (v) {
                    c.name = v;
                    _dirty = true;
                    if (_validation != null) setState(() => _validation = null);
                  },
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Tên lựa chọn',
                    helperText: c.isDefault ? 'Mặc định · 0đ' : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Bỏ lựa chọn',
                onPressed: g.choices.length <= 1 ? null : () => _touch(() => g.choices.removeAt(ci)),
                icon: const Icon(Icons.close_rounded, size: 18),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  c.ingredientId == null
                      ? 'Chỉ dẫn cho barista · Thêm 0đ'
                      : 'Định lượng riêng: ${c.qty ?? 0} ${menuUnitLabel(c.unit ?? '')} ${c.ingredientName ?? ''}',
                  style: AppTextStyles.caption,
                ),
                TextButton(
                  onPressed: () => _pickRecipe(c),
                  child: Text(c.ingredientId == null ? 'Định lượng riêng' : 'Đổi'),
                ),
                if (c.ingredientId != null)
                  TextButton(
                    onPressed: () => _touch(() {
                      c.ingredientId = null;
                      c.ingredientName = null;
                      c.unit = null;
                      c.qty = null;
                    }),
                    child: const Text('Bỏ'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Xem trước lựa chọn mẫu (chỉ tính toán, không tạo đơn)
// ---------------------------------------------------------------------------

