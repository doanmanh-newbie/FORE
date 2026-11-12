import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import 'menu_format.dart';
import 'menu_history_views.dart';
import 'menu_models.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// "200đ" hoặc "0,5đ": giá vốn của một đơn vị nguyên liệu.
String formatUnitCost(num cost) {
  if (cost == cost.roundToDouble()) return '${formatThousands(cost.round())}đ';
  return '${cost.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ',')}đ';
}

List<DraftRecipeLine> draftFromLines(List<RecipeLine> lines) => [
      for (final l in lines)
        DraftRecipeLine(
          ingredientId: l.ingredientId,
          name: l.name,
          unit: l.unit,
          qty: l.qty,
          unitCost: l.unitCost,
        ),
    ];

bool sameLines(List<DraftRecipeLine> a, List<DraftRecipeLine> b) {
  if (a.length != b.length) return false;
  final map = {for (final l in a) l.ingredientId: l.qty};
  for (final l in b) {
    if (map[l.ingredientId] != l.qty) return false;
  }
  return true;
}

/// Mô tả ngắn thay đổi giữa hai công thức: "sữa 140 → 160 ml (+20 ml) · thêm đá 100 g".
String describeRecipeDiff(List<DraftRecipeLine> before, List<DraftRecipeLine> after) {
  final old = {for (final l in before) l.ingredientId: l};
  final now = {for (final l in after) l.ingredientId: l};
  final parts = <String>[];
  for (final l in after) {
    final o = old[l.ingredientId];
    final unit = menuUnitLabel(l.unit);
    if (o == null) {
      parts.add('thêm ${l.name.toLowerCase()} ${l.qty} $unit');
    } else if (o.qty != l.qty) {
      final d = l.qty - o.qty;
      parts.add('${l.name.toLowerCase()} ${o.qty} → ${l.qty} $unit (${d > 0 ? '+' : ''}$d $unit)');
    }
  }
  for (final o in before) {
    if (!now.containsKey(o.ingredientId)) parts.add('bỏ ${o.name.toLowerCase()}');
  }
  return parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Soạn công thức
// ---------------------------------------------------------------------------

class RecipeEditorPage extends StatefulWidget {
  const RecipeEditorPage({
    super.key,
    required this.detail,
    required this.initialSizeId,
  });

  final ItemDetail detail;
  final String initialSizeId;

  @override
  State<RecipeEditorPage> createState() => _RecipeEditorPageState();
}

class _RecipeEditorPageState extends State<RecipeEditorPage> {
  late final List<SizeDetail> _sizes;
  final Map<String, List<DraftRecipeLine>> _drafts = {};
  final Map<String, List<DraftRecipeLine>> _saved = {};
  int _index = 0;
  IngredientCatalog? _catalog;
  Object? _catalogError;

  @override
  void initState() {
    super.initState();
    _sizes = widget.detail.activeSizes;
    for (final s in _sizes) {
      final lines = draftFromLines(s.current?.lines ?? const []);
      _drafts[s.id] = List.of(lines);
      _saved[s.id] = List.of(lines);
    }
    _index = _sizes.indexWhere((s) => s.id == widget.initialSizeId);
    if (_index < 0) _index = 0;
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await context.read<MenuStore>().loadIngredients();
      if (mounted) setState(() => _catalog = catalog);
    } catch (error) {
      if (mounted) setState(() => _catalogError = error);
    }
  }

  SizeDetail get _size => _sizes[_index];
  List<DraftRecipeLine> get _lines => _drafts[_size.id]!;

  bool get _dirty =>
      _sizes.any((s) => !sameLines(_drafts[s.id]!, _saved[s.id]!));
  bool _dirtyFor(SizeDetail s) => !sameLines(_drafts[s.id]!, _saved[s.id]!);

  bool get _valid => _lines.isNotEmpty && _lines.every((l) => l.qty > 0);

  Future<void> _addIngredient() async {
    var catalog = _catalog;
    if (catalog == null) {
      await _loadCatalog();
      catalog = _catalog;
      if (catalog == null) return;
    }
    if (!mounted) return;
    final picked = await openMenuPage<DraftRecipeLine>(
      context,
      IngredientPickerPage(
        sizeName: _size.name,
        existing: _lines,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      final lines = _lines;
      final i = lines.indexWhere((l) => l.ingredientId == picked.ingredientId);
      if (i >= 0) {
        lines[i] = picked;
      } else {
        lines.add(picked);
      }
    });
  }

  Future<void> _review() async {
    final saved = await openMenuPage<bool>(
      context,
      RecipeConfirmPage(
        detail: widget.detail,
        size: _size,
        lines: List.of(_lines),
      ),
    );
    if (saved == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<bool> _confirmLeave() async {
    final dirtyNames = [
      for (final s in _sizes)
        if (_dirtyFor(s)) s.name,
    ].join(', ');
    return confirmSheet(
      context,
      title: 'Bản pha mới chưa được cất lại.',
      message:
          'Bạn có thay đổi chưa lưu${dirtyNames.isEmpty ? '' : ' (size $dirtyNames)'}. Nếu thoát bây giờ, phần chỉnh sửa trong bản nháp sẽ mất. '
          'Công thức đang dùng không bị ảnh hưởng.',
      confirmLabel: 'Bỏ bản nháp chưa lưu',
      cancelLabel: 'Tiếp tục chỉnh sửa',
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _size;
    final lines = _lines;
    final current = size.current;
    final newCost = draftCost(lines);
    final dirty = _dirtyFor(size);
    final nextNo = (current?.versionNo ?? 0) + 1;
    final diff = current == null
        ? ''
        : describeRecipeDiff(draftFromLines(current.lines), lines);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmLeave();
        if (leave && mounted) Navigator.of(context).pop();
      },
      child: MenuPage(
        title: 'Công thức pha chế',
        subtitle: '${widget.detail.name} · Mỗi size một công thức riêng',
        onBack: () => Navigator.of(context).maybePop(),
        primary: MenuPrimaryButton(
          label: current == null ? 'Xem lại và lưu công thức' : 'Xem lại thay đổi',
          onPressed: dirty && _valid ? _review : null,
        ),
        children: [
          SizeTabs(
            labels: [
              for (final s in _sizes)
                '${s.name}${(_drafts[s.id]!.isNotEmpty) ? ' ✓' : ''}',
            ],
            selected: _index,
            onChanged: (i) => setState(() => _index = i),
          ),
          if (dirty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                children: [
                  _Pill('v$nextNo · Bản nháp chưa lưu', warn: true),
                  if (current != null) _Pill('v${current.versionNo} vẫn đang dùng'),
                ],
              ),
            )
          else if (current == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text('Chưa có công thức. Thêm nguyên liệu đầu tiên bên dưới.',
                  style: AppTextStyles.caption),
            ),
          if (_catalogError != null)
            MenuBanner(
              kind: BannerKind.warning,
              title: 'Chưa tải được danh sách nguyên liệu',
              body: menuErrorMessage(_catalogError!),
              action: TextButton(
                onPressed: () {
                  setState(() => _catalogError = null);
                  _loadCatalog();
                },
                child: const Text('Thử lại'),
              ),
            ),
          MenuCard(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Nguyên liệu / 1 ly ${size.name}',
                          style: AppTextStyles.cardTitle),
                    ),
                    const Text('Lượng · Thành tiền', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < lines.length; i++)
                  _LineRow(
                    key: ValueKey('${size.id}_${lines[i].ingredientId}'),
                    line: lines[i],
                    onQty: (q) => setState(() => lines[i] = lines[i].withQty(q)),
                    onRemove: () => setState(() => lines.removeAt(i)),
                  ),
                TextButton.icon(
                  onPressed: _addIngredient,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Thêm nguyên liệu'),
                ),
              ],
            ),
          ),
          if (lines.any((l) => l.unitCost == null))
            const MenuBanner(
              kind: BannerKind.warning,
              title: 'Có nguyên liệu chưa có giá',
              body:
                  'Giá vốn chưa xác định. Nhập giá nguyên liệu ở bước "Thêm nguyên liệu" để xem lãi gộp.',
            ),
          if (diff.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'So với v${current!.versionNo}: $diff.'
                '${newCost != null && current.cost != null ? ' Giá vốn ${newCost - current.cost! >= 0 ? '+' : ''}${formatVnd(newCost - current.cost!)}.' : ''}'
                ' Giá bán giữ ${formatVnd(size.price)}.',
                style: AppTextStyles.caption,
              ),
            ),
          MenuMarginHero(
            label: current == null
                ? 'Xem trước · Công thức đầu tiên'
                : 'Xem trước · Bản nháp v$nextNo',
            price: size.price,
            cost: newCost,
            lowMarginPct: widget.detail.lowMarginPct,
          ),
          if (current != null)
            const Text(
              'Đây mới là bản xem trước. Công thức đang dùng không đổi cho đến khi bạn lưu.',
              style: AppTextStyles.caption,
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label, {this.warn = false});

  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: warn ? AppColors.statusAttentionTint : AppColors.tint,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: warn ? AppColors.statusAttention : AppColors.textSecondary)),
      );
}

class _LineRow extends StatelessWidget {
  const _LineRow({
    super.key,
    required this.line,
    required this.onQty,
    required this.onRemove,
  });

  final DraftRecipeLine line;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(line.name, style: AppTextStyles.bodyStrong),
                  Text(
                    line.unitCost == null
                        ? 'Chưa có giá'
                        : '${formatUnitCost(line.unitCost!)}/${menuUnitLabel(line.unit)}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 92,
              child: TextFormField(
                initialValue: line.qty == 0 ? '' : '${line.qty}',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (v) => onQty(int.tryParse(v) ?? 0),
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: menuUnitLabel(line.unit),
                  errorText: line.qty <= 0 ? 'Phải > 0' : null,
                ),
              ),
            ),
            SizedBox(
              width: 70,
              child: Text(
                line.lineCost == null ? '—' : formatVnd(line.lineCost!),
                textAlign: TextAlign.end,
                style: AppTextStyles.bodyStrong,
              ),
            ),
            IconButton(
              tooltip: 'Bỏ ${line.name}',
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded, size: 18),
              constraints: const BoxConstraints.tightFor(width: 40, height: 48),
            ),
          ],
        ),
      );
}

// ---------------------------------------------------------------------------
// Chọn nguyên liệu
// ---------------------------------------------------------------------------

class IngredientPickerPage extends StatefulWidget {
  const IngredientPickerPage({
    super.key,
    required this.sizeName,
    required this.existing,
    this.purpose,
  });

  final String sizeName;

  /// Thay cho "Cho size X" ở dòng phụ đề (dùng khi chọn nguyên liệu cho topping/tùy chọn).
  final String? purpose;
  final List<DraftRecipeLine> existing;

  @override
  State<IngredientPickerPage> createState() => _IngredientPickerPageState();
}

class _IngredientPickerPageState extends State<IngredientPickerPage> {
  IngredientCatalog? _catalog;
  Object? _error;
  String _query = '';
  IngredientInfo? _selected;
  final _qty = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final catalog = await context.read<MenuStore>().loadIngredients();
      if (mounted) setState(() => _catalog = catalog);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  DraftRecipeLine? _existingFor(String id) {
    for (final l in widget.existing) {
      if (l.ingredientId == id) return l;
    }
    return null;
  }

  void _select(IngredientInfo info) {
    setState(() {
      _selected = info;
      final old = _existingFor(info.id);
      _qty.text = old == null ? '' : '${old.qty}';
    });
  }

  Future<void> _setCost(IngredientInfo info) async {
    final controller = TextEditingController(
        text: info.unitCost == null ? '' : formatUnitCost(info.unitCost!).replaceAll('đ', ''));
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Giá của ${info.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Giá vốn / ${menuUnitLabel(info.unit)}',
            suffixText: 'đ',
            helperText: 'Ví dụ cà phê 200đ/g, sữa 50đ/ml.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim().replaceAll(',', '.'));
              if (v == null || v < 0) return;
              Navigator.of(dialogContext).pop(v);
            },
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            child: const Text('Lưu giá'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    final store = context.read<MenuStore>();
    final ok = await menuGuard<bool>(context, () async {
      await store.setIngredientCost(info.id, value);
      return true;
    });
    if (ok == true && mounted) await _load();
    if (!mounted) return;
    final updated = _catalog?.items.where((i) => i.id == info.id);
    if (updated != null && updated.isNotEmpty && _selected?.id == info.id) {
      setState(() => _selected = updated.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalog = _catalog;
    final q = foldVietnamese(_query);
    final items = catalog == null
        ? const <IngredientInfo>[]
        : [
            for (final i in catalog.items)
              if (q.isEmpty || foldVietnamese(i.name).contains(q)) i,
          ];
    final selected = _selected;
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    final cost = selected?.unitCost;

    return MenuPage(
      title: 'Chọn nguyên liệu',
      subtitle: 'Kho nguyên liệu · ${menuShopName(context)} · ${widget.purpose ?? 'Cho size ${widget.sizeName}'}',
      primary: MenuPrimaryButton(
        label: selected == null
            ? 'Chọn một nguyên liệu'
            : qty <= 0
                ? 'Nhập lượng dùng'
                : 'Dùng ${selected.name.toLowerCase()} · $qty ${menuUnitLabel(selected.unit)}${cost == null ? '' : ' · ${formatVnd((qty * cost).round())}'}',
        onPressed: selected == null || qty <= 0
            ? null
            : () => Navigator.of(context).pop(DraftRecipeLine(
                  ingredientId: selected.id,
                  name: selected.name,
                  unit: selected.unit,
                  qty: qty,
                  unitCost: selected.unitCost,
                )),
      ),
      children: [
        TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Tìm nguyên liệu trong kho...',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        if (_error != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được kho nguyên liệu',
            body: menuErrorMessage(_error!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (catalog == null)
          const MenuSkeleton(rows: 4)
        else ...[
          Row(
            children: [
              const Expanded(child: Text('Đang có trong kho', style: AppTextStyles.cardTitle)),
              const Text('Giá vốn theo đơn vị', style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('Không có nguyên liệu nào khớp. Thêm nguyên liệu mới ở tab Kho.',
                  style: AppTextStyles.body),
            ),
          for (final info in items)
            MenuCard(
              onTap: () => _select(info),
              borderColor: selected?.id == info.id ? AppColors.brand : AppColors.cardBorder,
              child: Row(
                children: [
                  Icon(
                    selected?.id == info.id
                        ? Icons.check_box_rounded
                        : Icons.check_box_outline_blank_rounded,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.name, style: AppTextStyles.cardTitle),
                        Text(
                          _existingFor(info.id) == null
                              ? 'Đơn vị công thức: ${menuUnitLabel(info.unit)}'
                              : 'Đã có trong công thức · ${_existingFor(info.id)!.qty} ${menuUnitLabel(info.unit)}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (info.unitCost == null)
                    TextButton(
                      onPressed: () => _setCost(info),
                      child: const Text('Nhập giá'),
                    )
                  else
                    GestureDetector(
                      onLongPress: () => _setCost(info),
                      child: Text(
                          '${formatUnitCost(info.unitCost!)}/${menuUnitLabel(info.unit)}',
                          style: AppTextStyles.bodyStrong),
                    ),
                ],
              ),
            ),
          if (selected != null)
            MenuCard(
              color: AppColors.surface,
              borderColor: AppColors.brand,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(selected.name, style: AppTextStyles.cardTitle)),
                      Text(
                        cost == null
                            ? 'Chưa có giá'
                            : '${formatUnitCost(cost)}/${menuUnitLabel(selected.unit)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _qty,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Lượng dùng (${menuUnitLabel(selected.unit)})',
                      helperText:
                          'Nhập số nguyên lớn hơn 0 theo ${menuUnitLabel(selected.unit)}.',
                    ),
                  ),
                  if (cost == null)
                    TextButton(
                      onPressed: () => _setCost(selected),
                      child: const Text('Nhập giá vốn nguyên liệu này'),
                    ),
                ],
              ),
            ),
          const Text(
            'Chọn từ kho có sẵn, không tạo nguyên liệu mới ở đây. Nếu đã có trong công thức, cập nhật lượng thay vì tạo dòng trùng.',
            style: AppTextStyles.caption,
          ),
          if (catalog.costUpdatedAt != null) ...[
            const SizedBox(height: 8),
            _Pill('Giá kho cập nhật ${dateTimeLabel(catalog.costUpdatedAt!)}'),
          ],
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Xác nhận phiên bản mới
// ---------------------------------------------------------------------------

class RecipeConfirmPage extends StatefulWidget {
  const RecipeConfirmPage({
    super.key,
    required this.detail,
    required this.size,
    required this.lines,
  });

  final ItemDetail detail;
  final SizeDetail size;
  final List<DraftRecipeLine> lines;

  @override
  State<RecipeConfirmPage> createState() => _RecipeConfirmPageState();
}

enum _SaveState { idle, saving, failed, done }

class _RecipeConfirmPageState extends State<RecipeConfirmPage> {
  late bool _immediate;
  late DateTime _when;
  _SaveState _state = _SaveState.idle;
  Object? _error;
  DateTime? _appliedAt;

  @override
  void initState() {
    super.initState();
    _immediate = widget.size.current == null || !widget.size.everSold;
    _when = nextBusinessDayStart();
  }

  Future<void> _save() async {
    final store = context.read<MenuStore>();
    setState(() {
      _state = _SaveState.saving;
      _error = null;
    });
    final effective = _immediate ? null : _when;
    try {
      await store.saveRecipe(widget.size.id, widget.lines, effectiveFrom: effective);
      if (!mounted) return;
      _appliedAt = _immediate ? DateTime.now() : _when;
      setState(() => _state = _SaveState.done);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = _SaveState.failed;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final current = size.current;
    final newCost = draftCost(widget.lines);
    final nextNo = (current?.versionNo ?? 0) + 1;
    if (_state == _SaveState.done && !_immediate) return _scheduled(context, nextNo, newCost);
    if (_state == _SaveState.done) return _appliedNow(context, nextNo);

    final saving = _state == _SaveState.saving;
    final oldLines = draftFromLines(current?.lines ?? const []);
    final oldCost = current?.costKnown == true ? current!.cost : null;
    final oldMargin = oldCost == null ? null : size.price - oldCost;
    final newMargin = newCost == null ? null : size.price - newCost;
    final others = widget.detail.activeSizes.where((s) => s.id != size.id).map((s) => s.name).toList();

    TableRow row(String label, String a, String b, {bool bold = false}) => TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(label, style: AppTextStyles.body),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(a, textAlign: TextAlign.end, style: AppTextStyles.body),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(b,
                  textAlign: TextAlign.end,
                  style: bold ? AppTextStyles.bodyStrong : AppTextStyles.body),
            ),
          ],
        );

    final changed = <TableRow>[];
    final oldMap = {for (final l in oldLines) l.ingredientId: l};
    for (final l in widget.lines) {
      final o = oldMap[l.ingredientId];
      if (o == null) {
        changed.add(row(l.name, '—', '${l.qty} ${menuUnitLabel(l.unit)}', bold: true));
      } else if (o.qty != l.qty) {
        changed.add(row(l.name, '${o.qty} ${menuUnitLabel(o.unit)}',
            '${l.qty} ${menuUnitLabel(l.unit)}', bold: true));
      }
    }
    for (final o in oldLines) {
      if (!widget.lines.any((l) => l.ingredientId == o.ingredientId)) {
        changed.add(row(o.name, '${o.qty} ${menuUnitLabel(o.unit)}', 'Bỏ', bold: true));
      }
    }

    return MenuPage(
      title: current == null ? 'Lưu công thức đầu tiên' : 'Hẹn công thức mới',
      subtitle: '${widget.detail.name} · Size ${size.name} · ${current == null ? 'v1' : 'v${current.versionNo} → v$nextNo'}',
      primary: MenuPrimaryButton(
        label: _state == _SaveState.failed
            ? 'Thử lưu${_immediate ? '' : ' & lên lịch'} lại'
            : _immediate
                ? 'Lưu v$nextNo & áp dụng ngay'
                : 'Lưu v$nextNo & lên lịch áp dụng',
        loading: saving,
        onPressed: _save,
      ),
      secondary: MenuSecondaryButton(
        label: _state == _SaveState.failed ? 'Trở lại chỉnh sửa' : 'Quay lại chỉnh sửa',
        onPressed: saving ? null : () => Navigator.of(context).pop(false),
      ),
      children: [
        if (saving)
          const MenuBanner(
            kind: BannerKind.info,
            title: 'Đang gửi lên hệ thống',
            body: 'Chưa xác nhận lưu thành công. Đừng đóng màn hình này.',
          ),
        if (_state == _SaveState.failed)
          MenuBanner(
            kind: BannerKind.error,
            title: 'Lưu thất bại · Chưa áp dụng',
            body:
                '${menuErrorMessage(_error ?? '')} Nội dung bạn vừa sửa vẫn được giữ ở đây; chưa tạo lịch áp dụng.',
          ),
        Wrap(spacing: 8, runSpacing: 6, children: [
          if (current != null) _Pill('v${current.versionNo} · Đang dùng'),
          _Pill('v$nextNo · Bản mới', warn: true),
        ]),
        const SizedBox(height: 10),
        MenuCard(
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(1.3),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              ...changed,
              row('Giá vốn / ly ${size.name}', moneyOrUnknown(oldCost), moneyOrUnknown(newCost), bold: true),
              row('Lãi gộp ước tính', moneyOrUnknown(oldMargin), moneyOrUnknown(newMargin), bold: true),
              row(
                'Tỷ lệ lãi gộp',
                oldCost == null || size.price <= 0 ? '—' : formatPct(oldMargin! * 100 / size.price),
                newCost == null || size.price <= 0 ? '—' : formatPct(newMargin! * 100 / size.price),
                bold: true,
              ),
            ],
          ),
        ),
        Text('Giá bán không đổi: ${formatVnd(size.price)}. Các nguyên liệu khác giữ nguyên.',
            style: AppTextStyles.caption),
        const SizedBox(height: 12),
        ApplyModePicker(
          immediate: _immediate,
          onChanged: saving ? (_) {} : (v) => setState(() => _immediate = v),
        ),
        if (!_immediate) ...[
          DateTimeFields(value: _when, onChanged: (v) => setState(() => _when = v)),
          const SizedBox(height: 4),
          Text(
            'Giờ Việt Nam. ${current == null ? '' : 'v${current.versionNo} dùng đến trước ${formatHm(_when)} ngày ${formatDmy(_when)}. '}Mặc định 06:00 để không đổi công thức giữa ca bán.',
            style: AppTextStyles.caption,
          ),
        ],
        const SizedBox(height: 10),
        MenuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Người xác nhận: ${menuOwnerName(context)} · Chủ quán',
                  style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text(
                'Chỉ áp dụng cho ${menuShopName(context)}, size ${size.name}${others.isEmpty ? '' : ' (${others.join(', ')} không đổi)'}.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        if (current != null)
          const MenuBanner(
            kind: BannerKind.warning,
            title: 'Bill cũ giữ nguyên công thức cũ',
            body:
                'Phiên bản mới chỉ áp dụng cho các lần bán từ thời điểm hiệu lực. Đối soát ca cũ vẫn tính theo công thức cũ.',
          ),
      ],
    );
  }

  Widget _scheduled(BuildContext context, int nextNo, int? newCost) {
    final size = widget.size;
    final current = size.current;
    final at = _appliedAt ?? _when;
    final oldCost = current?.costKnown == true ? current!.cost : null;
    return MenuPage(
      title: 'Đã hẹn, chưa áp dụng',
      subtitle: '${widget.detail.name} · Size ${size.name}',
      showBack: false,
      primary: MenuPrimaryButton(
        label: 'Về chi tiết món',
        onPressed: () => Navigator.of(context).pop(true),
      ),
      secondary: MenuSecondaryButton(
        label: 'Xem lịch sử thay đổi',
        onPressed: () async {
          await openMenuPage<void>(
              context, MenuHistoryPage(itemId: widget.detail.id, itemName: widget.detail.name));
          if (context.mounted) Navigator.of(context).pop(true);
        },
      ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('v$nextNo đã lưu trên hệ thống',
                    style: const TextStyle(
                        color: AppColors.actionLime, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(formatDmy(at),
                    style: const TextStyle(
                        color: Colors.white, fontSize: 30, fontFamily: AppFonts.display)),
                Text('Lúc ${formatHm(at)}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 26, fontFamily: AppFonts.display)),
                const SizedBox(height: 8),
                const Text('Tự áp dụng từ giờ đã hẹn, theo giờ Việt Nam.',
                    style: TextStyle(color: AppColors.onInkMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (current != null)
          MenuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Pill('✓ Bây giờ · v${current.versionNo} đang dùng'),
                const SizedBox(height: 4),
                Text(
                    'Giá vốn ${moneyOrUnknown(oldCost)}${oldCost == null ? '' : ' · Lãi gộp ${formatVnd(size.price - oldCost)}'}',
                    style: AppTextStyles.body),
                const SizedBox(height: 10),
                _Pill('Sắp tới · v$nextNo đã lên lịch', warn: true),
                const SizedBox(height: 4),
                Text(
                    'Giá vốn ${moneyOrUnknown(newCost)}${newCost == null ? '' : ' · Lãi gộp ${formatVnd(size.price - newCost)}'}',
                    style: AppTextStyles.body),
              ],
            ),
          ),
        Text(
          '${menuOwnerName(context)} xác nhận ${dateTimeLabel(DateTime.now())}. Áp dụng size ${size.name} tại ${menuShopName(context)}. Bill cũ giữ đúng phiên bản công thức đã bán.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _appliedNow(BuildContext context, int nextNo) => MenuPage(
        title: 'Đã lưu công thức',
        subtitle: '${widget.detail.name} · Size ${widget.size.name}',
        showBack: false,
        primary: MenuPrimaryButton(
          label: 'Về chi tiết món',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        children: [
          MenuBanner(
            kind: BannerKind.success,
            title: 'v$nextNo đang dùng',
            body:
                'Công thức mới áp dụng cho các lần bán từ bây giờ. Bill cũ giữ nguyên công thức đã bán.',
          ),
        ],
      );
}
