import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/app_sheet.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/secondary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';
import 'purchase_screens.dart';

// ======================================================================
// Danh sách nguyên liệu
// ======================================================================
class IngredientListScreen extends StatefulWidget {
  const IngredientListScreen({super.key, this.initialSearch});

  final String? initialSearch;

  @override
  State<IngredientListScreen> createState() => _IngredientListScreenState();
}

class _IngredientListScreenState extends State<IngredientListScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<List<CatalogItem>> _data =
      AsyncData(() => _repo.catalog(includeInactive: true))..load();
  late final TextEditingController _search =
      TextEditingController(text: widget.initialSearch ?? '');
  int _status = 0; // 0 tất cả, 1 sắp hết, 2 ngừng dùng
  String? _group;

  @override
  void dispose() {
    _data.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _data.load(silent: true);
  }

  List<CatalogItem> _filter(List<CatalogItem> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((i) {
      if (_status == 2 ? i.active : !i.active) return false;
      if (_status == 1 && i.status == StockStatus.ok) return false;
      if (_group != null && (i.group ?? 'Khác') != _group) return false;
      return q.isEmpty || i.name.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Nguyên liệu',
        subtitle: 'Tồn, giá bình quân và lô hàng của từng nguyên liệu',
        bottom: PrimaryButton(
          label: 'Thêm nguyên liệu',
          onPressed: () => _open(const IngredientFormScreen()),
        ),
        body: ListenableBuilder(
          listenable: _search,
          builder: (context, _) => AsyncView<List<CatalogItem>>(
            source: _data,
            builder: (context, all) {
              final active = all.where((i) => i.active).toList();
              final lowCount =
                  active.where((i) => i.status != StockStatus.ok).length;
              final stopped = all.length - active.length;
              final groups = groupBy<CatalogItem>(
                  _filter(all), (i) => i.group);
              final groupNames = {
                for (final i in all.where((i) => _status == 2 ? !i.active : i.active))
                  i.group ?? 'Khác'
              }.toList()
                ..sort();
              return [
                KhoSearchField(
                    controller: _search, hint: 'Tìm nguyên liệu…'),
                const SizedBox(height: 12),
                KhoChipBar(
                  labels: [
                    'Tất cả · ${active.length}',
                    'Sắp hết · $lowCount',
                    'Ngừng dùng · $stopped',
                  ],
                  selected: _status,
                  onSelected: (i) => setState(() => _status = i),
                ),
                if (groupNames.length > 1) ...[
                  const SizedBox(height: 8),
                  KhoChipBar(
                    labels: ['Mọi nhóm', ...groupNames],
                    selected: _group == null ? 0 : groupNames.indexOf(_group!) + 1,
                    onSelected: (i) =>
                        setState(() => _group = i == 0 ? null : groupNames[i - 1]),
                  ),
                ],
                const SizedBox(height: 12),
                if (groups.isEmpty)
                  const KhoNote(
                      'Không có nguyên liệu nào khớp. Thử bỏ bớt bộ lọc.'),
                for (final e in groups.entries) ...[
                  KhoSectionTitle(e.key),
                  for (final i in e.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: KhoCard(
                        onTap: () =>
                            _open(IngredientProfileScreen(ingredientId: i.id)),
                        child: Row(children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(i.name, style: AppTextStyles.cardTitle),
                                const SizedBox(height: 2),
                                Text(
                                  i.active
                                      ? stockLine(i)
                                      : 'Ngừng dùng · giữ lịch sử',
                                  style: AppTextStyles.caption,
                                ),
                                if (i.value != null)
                                  Text('Giá trị ${formatVnd(i.value!)}',
                                      style: AppTextStyles.caption),
                              ],
                            ),
                          ),
                          if (i.active) StockBadge(i.status),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textSecondary),
                        ]),
                      ),
                    ),
                ],
              ];
            },
          ),
        ),
      );
}

// ======================================================================
// Hồ sơ nguyên liệu
// ======================================================================
class IngredientProfileScreen extends StatefulWidget {
  const IngredientProfileScreen({super.key, required this.ingredientId});

  final String ingredientId;

  @override
  State<IngredientProfileScreen> createState() =>
      _IngredientProfileScreenState();
}

class _IngredientProfileScreenState extends State<IngredientProfileScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<IngredientProfile> _data =
      AsyncData(() => _repo.ingredientProfile(widget.ingredientId))..load();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _data.load(silent: true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final p = _data.data;
          return KhoPage(
            title: p?.name ?? 'Hồ sơ nguyên liệu',
            subtitle: p == null
                ? null
                : '${p.group ?? 'Khác'} · Đơn vị kho: ${displayUnit(p.unit)}',
            bottom: p == null || !p.active
                ? null
                : PrimaryButton(
                    label: 'Nhập thêm ${p.name.toLowerCase()}',
                    onPressed: () => _open(PoFormScreen(
                        isOwner: true, presetIngredientId: p.id)),
                  ),
            body: AsyncView<IngredientProfile>(
              source: _data,
              builder: (context, p) => _content(p),
            ),
          );
        },
      );

  List<Widget> _content(IngredientProfile p) {
    final tight = p.status != StockStatus.ok;
    return [
      KhoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: BigFigure(
                  label: 'Tồn ghi nhận trong hệ thống',
                  value: formatKhoQty(p.stock < 0 ? 0 : p.stock, p.unit),
                  caption: p.stockAt == null
                      ? null
                      : 'Cập nhật ${formatDateTimeShort(p.stockAt!)}',
                ),
              ),
              StockBadge(p.status),
            ]),
            if (p.stock < 0) ...[
              const SizedBox(height: 8),
              KhoNote(
                  'Sổ kho đang âm ${formatKhoQty(-p.stock, p.unit)}. Nên kiểm kê hoặc ghi phiếu nhập còn thiếu.',
                  icon: Icons.warning_amber_rounded),
            ],
            const Divider(height: 24, color: AppColors.cardBorder),
            LabelValueRow('Giá trị tồn',
                p.value == null ? 'Chưa có giá' : formatVnd(p.value!),
                strong: true),
            LabelValueRow(
                'Giá bình quân hiện tại', formatKhoPrice(p.unitCost, p.unit)),
            LabelValueRow(
                'Giá nhập gần nhất',
                p.lastPurchaseCost == null
                    ? 'Chưa có phiếu nhập'
                    : '${formatKhoPrice(p.lastPurchaseCost, p.unit)}${p.lastPurchaseAt == null ? '' : ' · ${formatShortDate(p.lastPurchaseAt!)}'}'),
          ],
        ),
      ),
      const SizedBox(height: 12),
      KhoCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const KhoEyebrow('Dự báo còn dùng'),
            const SizedBox(height: 6),
            Text(
              p.daysLeft == null
                  ? 'Chưa đủ số liệu bán để dự báo'
                  : 'Còn ${formatDaysLeft(p.daysLeft)}',
              style: AppTextStyles.metric,
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (p.minStock > 0)
                  'Ngưỡng nhắc nhập: ${formatKhoQty(p.minStock, p.unit)}',
                if (p.supplierLeadDays != null)
                  'Giao sau ${p.supplierLeadDays} ngày',
              ].join(' · '),
              style: AppTextStyles.caption,
            ),
            if (tight && p.supplierName != null) ...[
              const SizedBox(height: 4),
              Text('Nhà cung cấp mặc định: ${p.supplierName}',
                  style: AppTextStyles.caption),
            ],
          ],
        ),
      ),
      KhoSectionTitle('Lô đang còn',
          action: p.lots.isEmpty ? null : null),
      if (p.lots.isEmpty)
        const KhoNote(
            'Chưa có lô nào còn hàng. Lô được tạo khi xác nhận phiếu nhập.')
      else
        for (var i = 0; i < p.lots.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: KhoCard(
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lô ${p.lots[i].code}',
                          style: AppTextStyles.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (p.lots[i].receivedAt != null)
                            'Nhập ${formatShortDate(p.lots[i].receivedAt!)}',
                          if (p.lots[i].expiry != null)
                            'Hạn dùng ${formatDmy(p.lots[i].expiry!)}'
                          else
                            'Chưa ghi hạn dùng',
                        ].join(' · '),
                        style: AppTextStyles.caption,
                      ),
                      Text(
                          'Còn ${formatKhoQty(p.lots[i].qtyRemaining, p.unit)} / ${formatKhoQty(p.lots[i].qtyReceived, p.unit)}',
                          style: AppTextStyles.caption),
                    ],
                  ),
                ),
                if (i == 0)
                  const StatusChip(
                      label: 'Ưu tiên dùng trước',
                      severity: StatusSeverity.attention,
                      compact: true),
              ]),
            ),
          ),
      if (p.storageNote != null) ...[
        const SizedBox(height: 4),
        KhoNote(p.storageNote!, icon: Icons.ac_unit_rounded),
      ],
      KhoSectionTitle(p.usedIn.isEmpty
          ? 'Chưa nằm trong công thức nào'
          : 'Đang dùng trong ${p.menuItemCount} món'),
      if (p.usedIn.isNotEmpty)
        KhoCard(
          child: Column(children: [
            for (final u in p.usedIn)
              LabelValueRow('${u.itemName} · ${u.sizeName}',
                  formatKhoQty(u.qty, p.unit)),
          ]),
        ),
      const SizedBox(height: 16),
      SecondaryButton(
        label: 'Biến động & giá nhập',
        onPressed: () => _open(IngredientHistoryScreen(
            ingredientId: p.id, name: p.name, unit: p.unit)),
      ),
      const SizedBox(height: 10),
      SecondaryButton(
        label: 'Sửa ngưỡng & thông tin',
        onPressed: () => _open(IngredientFormScreen(ingredientId: p.id)),
      ),
    ];
  }
}

// ======================================================================
// Sổ biến động và giá nhập
// ======================================================================
class IngredientHistoryScreen extends StatefulWidget {
  const IngredientHistoryScreen(
      {super.key,
      required this.ingredientId,
      required this.name,
      required this.unit});

  final String ingredientId;
  final String name;
  final String unit;

  @override
  State<IngredientHistoryScreen> createState() =>
      _IngredientHistoryScreenState();
}

class _IngredientHistoryScreenState extends State<IngredientHistoryScreen> {
  static const _kinds = <String?>[null, 'purchase', 'waste', 'adjust', 'sale'];
  static const _labels = [
    'Tất cả',
    'Nhập hàng',
    'Hao hụt',
    'Kiểm kê',
    'Dùng'
  ];
  late final KhoRepository _repo = context.read<KhoRepository>();
  int _filter = 0;
  late AsyncData<IngredientHistory> _data = _make()..load();

  AsyncData<IngredientHistory> _make() => AsyncData(() => _repo
      .ingredientHistory(widget.ingredientId, kind: _kinds[_filter]));

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  void _select(int i) {
    final old = _data;
    setState(() {
      _filter = i;
      _data = _make()..load();
    });
    old.dispose();
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Sổ biến động',
        subtitle: 'Hồ sơ ${widget.name} · Mỗi thay đổi đều có phiếu và người ghi',
        body: AsyncView<IngredientHistory>(
          source: _data,
          builder: (context, h) => [
            KhoChipBar(labels: _labels, selected: _filter, onSelected: _select),
            if (_filter == 0 || _filter == 1) ...[
              KhoSectionTitle('Giá nhập gần đây'),
              if (h.priceEvents.isEmpty)
                const KhoNote('Chưa có phiếu nhập nào có giá.')
              else
                KhoCard(
                  child: Column(children: [
                    for (final e in h.priceEvents.take(5))
                      LabelValueRow(
                        '${formatShortDate(e.at)}${e.orderCode == null ? '' : ' · ${e.orderCode}'}',
                        '${formatKhoPrice(e.price, widget.unit)} → bình quân ${formatKhoPrice(e.avgAfter, widget.unit)}',
                      ),
                  ]),
                ),
            ],
            KhoSectionTitle('Những lần thay đổi'),
            if (h.movements.isEmpty)
              const KhoNote('Chưa có biến động nào ở mục này.'),
            for (final m in h.movements)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KhoCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${movementLabel(m.kind)}${m.refCode == null ? '' : ' · ${m.refCode}'}',
                              style: AppTextStyles.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                            [
                              formatDateTimeShort(m.at),
                              if (m.actorName != null) m.actorName!,
                              if (m.note != null) m.note!,
                            ].join(' · '),
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      formatKhoQty(m.qtyDelta, widget.unit, signed: true),
                      style: AppTextStyles.bodyStrong.copyWith(
                          color: m.qtyDelta >= 0
                              ? AppColors.statusHealthy
                              : AppColors.statusCritical),
                    ),
                  ]),
                ),
              ),
          ],
        ),
      );
}

// ======================================================================
// Thêm / sửa nguyên liệu + quản lý nhóm
// ======================================================================
class IngredientFormScreen extends StatefulWidget {
  const IngredientFormScreen({super.key, this.ingredientId});

  final String? ingredientId;

  @override
  State<IngredientFormScreen> createState() => _IngredientFormScreenState();
}

class _IngredientFormScreenState extends State<IngredientFormScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  final _name = TextEditingController();
  final _min = TextEditingController();
  final _note = TextEditingController();
  String _unit = 'ml';
  String? _groupId;
  String? _supplierId;
  bool _important = false;
  bool _active = true;
  bool _loading = true;
  bool _busy = false;
  bool _unitLocked = false;
  List<IngredientGroup> _groups = const [];
  List<SupplierSummary> _suppliers = const [];
  IngredientProfile? _profile;

  bool get _editing => widget.ingredientId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _min.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groups = await guarded(context, _repo.groups);
    final suppliers = await guarded(context, _repo.suppliers);
    IngredientProfile? p;
    if (_editing) {
      if (!mounted) return;
      p = await guarded(
          context, () => _repo.ingredientProfile(widget.ingredientId!));
    }
    if (!mounted) return;
    setState(() {
      _groups = (groups ?? const []).where((g) => g.active).toList();
      _suppliers = (suppliers ?? const []).where((s) => s.active).toList();
      _profile = p;
      if (p != null) {
        _name.text = p.name;
        _unit = p.unit;
        _unitLocked = true;
        _important = p.importance == 'important';
        _active = p.active;
        _supplierId = p.supplierId;
        _note.text = p.storageNote ?? '';
        _min.text = p.minStock == 0 ? '' : khoQtyInput(p.minStock, p.unit);
        _groupId = _groups
            .where((g) => g.name.toLowerCase() == (p!.group ?? '').toLowerCase())
            .map((g) => g.id)
            .firstOrNull;
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return showNotice(context, 'Hãy nhập tên nguyên liệu.');
    if (_groupId == null) return showNotice(context, 'Hãy chọn nhóm nguyên liệu.');
    final minText = _min.text.trim();
    final min = minText.isEmpty ? 0 : parseKhoQty(minText, _unit);
    if (min == null) {
      return showNotice(context, 'Ngưỡng nhắc nhập chưa đúng. Ví dụ: 15 hoặc 2,5.');
    }
    setState(() => _busy = true);
    final id = await guarded(
      context,
      () => _repo.saveIngredient(
        widget.ingredientId,
        IngredientDraft(
          name: name,
          unit: _unit,
          groupId: _groupId,
          minStockQty: min,
          defaultSupplierId: _supplierId,
          storageNote: _note.text.trim().isEmpty ? null : _note.text.trim(),
          important: _important,
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (id != null) {
      showNotice(context, _editing ? 'Đã lưu thay đổi.' : 'Đã thêm nguyên liệu.');
      Navigator.of(context).pop();
    }
  }

  Future<void> _toggleActive() async {
    final id = widget.ingredientId;
    if (id == null) return;
    final target = !_active;
    final done = await guarded(context, () async {
      await _repo.setIngredientActive(id, target);
      return true;
    });
    if (done == true && mounted) {
      setState(() => _active = target);
      showNotice(context, target ? 'Đã dùng lại nguyên liệu.' : 'Đã ngừng dùng. Lịch sử vẫn được giữ.');
    }
  }

  Future<void> _manageGroups() async {
    await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const GroupsScreen()));
    final groups = await guarded(context, _repo.groups);
    if (!mounted || groups == null) return;
    setState(() {
      _groups = groups.where((g) => g.active).toList();
      if (!_groups.any((g) => g.id == _groupId)) _groupId = null;
    });
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: _editing ? 'Sửa nguyên liệu' : 'Thêm nguyên liệu',
        subtitle: _editing ? _profile?.name : 'Một nguyên liệu mới',
        bottom: _loading
            ? null
            : PrimaryButton(
                label: _editing ? 'Lưu thay đổi' : 'Thêm nguyên liệu',
                loading: _busy,
                onPressed: _save),
        body: _loading
            ? const KhoSkeleton()
            : ListView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                children: [
                  AppTextField(
                      label: 'Tên nguyên liệu *',
                      controller: _name,
                      hint: 'Ví dụ: Sữa tươi'),
                  const SizedBox(height: 14),
                  Text('Nhóm nguyên liệu *', style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _groupId,
                    isExpanded: true,
                    hint: const Text('Chọn nhóm'),
                    items: [
                      for (final g in _groups)
                        DropdownMenuItem(value: g.id, child: Text(g.name)),
                    ],
                    onChanged: (v) => setState(() => _groupId = v),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                        onPressed: _manageGroups,
                        child: const Text('Quản lý nhóm')),
                  ),
                  const SizedBox(height: 6),
                  Text('Đơn vị kho *', style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ml', label: Text('Lít')),
                      ButtonSegment(value: 'g', label: Text('Kg')),
                      ButtonSegment(value: 'piece', label: Text('Cái')),
                    ],
                    selected: {_unit},
                    onSelectionChanged: _unitLocked
                        ? null
                        : (s) => setState(() => _unit = s.first),
                  ),
                  if (_unitLocked)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                          'Đã có sổ kho hoặc công thức nên không đổi đơn vị.',
                          style: AppTextStyles.caption),
                    ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'Ngưỡng nhắc nhập (${displayUnit(_unit)})',
                    controller: _min,
                    hint: 'Để trống nếu không cần nhắc',
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 14),
                  Text('Nhà cung cấp mặc định', style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: _supplierId,
                    isExpanded: true,
                    hint: const Text('Chưa chọn'),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null, child: Text('Chưa chọn')),
                      for (final s in _suppliers)
                        DropdownMenuItem<String?>(
                            value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setState(() => _supplierId = v),
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                      label: 'Ghi chú bảo quản',
                      controller: _note,
                      hint: 'Ví dụ: Bảo quản 2–6°C'),
                  const SizedBox(height: 6),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _important,
                    onChanged: (v) => setState(() => _important = v),
                    title: const Text('Nguyên liệu quan trọng'),
                    subtitle: const Text(
                        'Đối soát ca sẽ cảnh báo sớm hơn khi lệch.'),
                  ),
                  if (_editing) ...[
                    const SizedBox(height: 12),
                    SecondaryButton(
                      label: _active ? 'Ngừng dùng' : 'Dùng lại nguyên liệu',
                      onPressed: _toggleActive,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                        'Không xóa nguyên liệu: chỉ ngừng dùng khi kho hết và không còn trong công thức đang bán.',
                        style: AppTextStyles.caption),
                  ],
                ],
              ),
      );
}

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<List<IngredientGroup>> _data =
      AsyncData(_repo.groups)..load();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _edit(IngredientGroup? g) async {
    final controller = TextEditingController(text: g?.name ?? '');
    final name = await AppSheet.show<String>(
      context,
      builder: (ctx) => AppSheet(
        title: g == null ? 'Thêm nhóm' : 'Đổi tên nhóm',
        footer: PrimaryButton(
            label: 'Lưu', onPressed: () => Navigator.pop(ctx, controller.text)),
        child: AppTextField(label: 'Tên nhóm', controller: controller),
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    final id = await guarded(context, () => _repo.saveGroup(g?.id, name));
    if (id != null) _data.load(silent: true);
  }

  Future<void> _toggle(IngredientGroup g) async {
    final done = await guarded(context, () async {
      await _repo.setGroupActive(g.id, !g.active);
      return true;
    });
    if (done == true) _data.load(silent: true);
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Nhóm nguyên liệu',
        subtitle: 'Cất gọn danh mục',
        bottom: PrimaryButton(label: 'Thêm nhóm', onPressed: () => _edit(null)),
        body: AsyncView<List<IngredientGroup>>(
          source: _data,
          builder: (context, groups) => [
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KhoCard(
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name, style: AppTextStyles.cardTitle),
                          const SizedBox(height: 2),
                          Text(
                              g.active
                                  ? '${g.ingredientCount} nguyên liệu · Trong ${g.menuItemCount} món'
                                  : 'Đã cất gọn',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    IconButton(
                        tooltip: 'Đổi tên',
                        onPressed: () => _edit(g),
                        icon: const Icon(Icons.edit_outlined)),
                    IconButton(
                        tooltip: g.active ? 'Cất gọn' : 'Dùng lại',
                        onPressed: () => _toggle(g),
                        icon: Icon(g.active
                            ? Icons.inventory_outlined
                            : Icons.unarchive_outlined)),
                  ]),
                ),
              ),
          ],
        ),
      );
}
