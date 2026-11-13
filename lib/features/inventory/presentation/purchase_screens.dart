import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/app_sheet.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/secondary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/tertiary_button.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../application/po_form_controller.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';
import '../../../core/widgets/lazy_list_view.dart';

// ======================================================================
// Phiếu nhập nhiều dòng (chủ) / Nhập hàng nhanh (nhân viên)
// ======================================================================
class PoFormScreen extends StatefulWidget {
  const PoFormScreen({
    super.key,
    required this.isOwner,
    this.orderId,
    this.presetIngredientId,
    this.presetSupplierId,
  });

  final bool isOwner;
  final String? orderId;
  final String? presetIngredientId;
  final String? presetSupplierId;

  @override
  State<PoFormScreen> createState() => _PoFormScreenState();
}

class _PoFormScreenState extends State<PoFormScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  PoFormController? _c;
  List<PickerItem> _picker = const [];
  List<SupplierOption> _suppliers = const [];
  bool _loading = true;
  String? _error;
  final _note = TextEditingController();
  final _ship = TextEditingController();

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _c?.dispose();
    _note.dispose();
    _ship.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final picker = await _repo.picker();
      final sups = await _repo.supplierOptions();
      final existing =
          widget.orderId == null ? null : await _repo.orderDetail(widget.orderId!);
      if (!mounted) return;
      final c = PoFormController(_repo,
          isOwner: widget.isOwner, existing: existing);
      if (existing == null && widget.presetSupplierId != null) {
        c.supplierId = widget.presetSupplierId;
      }
      final pre = widget.presetIngredientId;
      if (existing == null && pre != null) {
        final item = picker.where((p) => p.id == pre).firstOrNull;
        if (item != null) {
          c.addLine(item);
          c.supplierId ??= item.defaultSupplierId;
        }
      }
      _note.text = c.note;
      _ship.text = c.shippingFee == 0 ? '' : formatThousands(c.shippingFee);
      setState(() {
        _c = c;
        _picker = picker;
        _suppliers = sups;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is Exception ? 'Không tải được dữ liệu. Thử lại.' : '$e';
      });
    }
  }

  Future<void> _addIngredient() async {
    final c = _c!;
    final used = c.lines.map((l) => l.ingredientId).toSet();
    final chosen = await AppSheet.show<PickerItem>(
      context,
      builder: (ctx) => _IngredientPickerSheet(
        items: _picker.where((p) => !used.contains(p.id)).toList(),
      ),
    );
    if (chosen == null) return;
    c.addLine(chosen);
    if (c.supplierId == null && chosen.defaultSupplierId != null) {
      c.setSupplier(chosen.defaultSupplierId);
    }
  }

  Future<void> _saveDraft() async {
    final c = _c!;
    final saved = await guarded(context, c.saveDraft);
    if (saved != null && mounted) {
      showNotice(context, 'Đã lưu nháp ${saved.code}.');
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmStaff() async {
    final c = _c!;
    final saved = await guarded(context, c.confirm);
    if (saved != null && mounted) {
      showNotice(context, 'Đã nhận hàng ${saved.code} · Chờ chủ bổ sung giá');
      Navigator.of(context).pop();
    }
  }

  Future<void> _previewOwner() async {
    final c = _c!;
    final impact = await guarded(context, c.previewImpact);
    if (impact == null || !mounted) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
          builder: (_) => PoImpactScreen(form: c, impact: impact)),
    );
    if (done == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final owner = widget.isOwner;
    final title = owner ? 'Nhập hàng' : 'Nhập hàng nhanh';
    if (_loading) {
      return const KhoPage(title: 'Nhập hàng', body: KhoSkeleton());
    }
    final c = _c;
    if (c == null) {
      return KhoPage(
          title: title,
          body: Center(child: Text(_error ?? 'Không mở được phiếu.')));
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => KhoPage(
        title: title,
        subtitle: [
          c.code ?? 'Phiếu mới',
          formatDateTimeFull(DateTime.now()),
          owner ? 'Bản nháp' : 'Luồng nhận hàng',
        ].join(' · '),
        bottom: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (owner)
              PrimaryButton(
                label: c.grandTotal == null
                    ? 'Xem tác động giá'
                    : 'Xem tác động giá · ${formatVnd(c.grandTotal!)}',
                loading: c.busy,
                onPressed: c.canConfirm ? _previewOwner : null,
              )
            else
              PrimaryButton(
                label: 'Xác nhận đã nhận · ${c.lines.length} dòng',
                loading: c.busy,
                onPressed: c.canConfirm ? _confirmStaff : null,
              ),
            const SizedBox(height: 8),
            SecondaryButton(
                label: 'Lưu nháp', onPressed: c.canSaveDraft ? _saveDraft : null),
          ],
        ),
        body: LazyListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            if (!owner)
              const KhoNote(
                  'Bạn chỉ cần ghi đúng lượng nhận. Giá do chủ quán bổ sung sau.',
                  icon: Icons.fact_check_outlined),
            if (!owner) const SizedBox(height: 12),
            Text('Nhà cung cấp *', style: AppTextStyles.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              key: ValueKey('${c.supplierId}|${_suppliers.length}'),
              initialValue: _suppliers.any((s) => s.id == c.supplierId)
                  ? c.supplierId
                  : null,
              isExpanded: true,
              hint: const Text('Chọn nhà cung cấp'),
              items: [
                for (final s in _suppliers)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: c.setSupplier,
            ),
            const SizedBox(height: 16),
            KhoEyebrow(
                '${owner ? 'Tạm tính' : 'Hàng thực nhận'} · ${c.lines.length} dòng'),
            const SizedBox(height: 8),
            for (var i = 0; i < c.lines.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LineCard(
                  key: ValueKey(c.lines[i].ingredientId),
                  line: c.lines[i],
                  showPrice: owner,
                  onChanged: (l) => c.updateLine(i, l),
                  onRemove: () => c.removeLine(i),
                ),
              ),
            SecondaryButton(label: 'Thêm nguyên liệu', onPressed: _addIngredient),
            const SizedBox(height: 16),
            if (owner) ...[
              AppTextField(
                label: 'Phí giao hàng',
                controller: _ship,
                hint: '0',
                keyboardType: TextInputType.number,
                inputFormatters: const [VndInputFormatter()],
                onChanged: (t) => c.setShipping(parseVnd(t) ?? 0),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: c.vatIncluded,
                onChanged: c.setVat,
                title: const Text('Giá đã gồm thuế'),
              ),
              KhoCard(
                child: Column(children: [
                  LabelValueRow(
                      'Thành tiền dự kiến',
                      c.linesTotal == null ? 'Chưa đủ giá' : formatVnd(c.linesTotal!)),
                  LabelValueRow('Giao hàng', formatVnd(c.shippingFee)),
                  Divider(color: AppColors.cardBorder),
                  LabelValueRow('Tổng cộng',
                      c.grandTotal == null ? '—' : formatVnd(c.grandTotal!),
                      strong: true),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            AppTextField(
              label: 'Ghi chú phiếu',
              controller: _note,
              hint: 'Không bắt buộc',
              onChanged: c.setNote,
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientPickerSheet extends StatefulWidget {
  const _IngredientPickerSheet({required this.items});

  final List<PickerItem> items;

  @override
  State<_IngredientPickerSheet> createState() => _IngredientPickerSheetState();
}

class _IngredientPickerSheetState extends State<_IngredientPickerSheet> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppSheet(
        title: 'Chọn nguyên liệu',
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.5,
          child: ListenableBuilder(
            listenable: _q,
            builder: (context, _) {
              final q = _q.text.trim().toLowerCase();
              final list = widget.items
                  .where((i) => q.isEmpty || i.name.toLowerCase().contains(q))
                  .toList();
              return Column(children: [
                KhoSearchField(controller: _q, hint: 'Tìm nguyên liệu'),
                const SizedBox(height: 8),
                Expanded(
                  child: list.isEmpty
                      ? const Center(
                          child: Text('Không có nguyên liệu nào khớp.'))
                      : LazyListView(children: [
                          for (final i in list)
                            ListTile(
                              title: Text(i.name),
                              subtitle: Text(
                                  '${i.group ?? 'Khác'} · ${displayUnit(i.unit)}'),
                              onTap: () => Navigator.pop(context, i),
                            ),
                        ]),
                ),
              ]);
            },
          ),
        ),
      );
}

class _LineCard extends StatefulWidget {
  const _LineCard({
    super.key,
    required this.line,
    required this.showPrice,
    required this.onChanged,
    required this.onRemove,
  });

  final PoLine line;
  final bool showPrice;
  final ValueChanged<PoLine> onChanged;
  final VoidCallback onRemove;

  @override
  State<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends State<_LineCard> {
  late final _qty = TextEditingController(
      text: widget.line.qty > 0
          ? khoQtyInput(widget.line.qty, widget.line.unit)
          : '');
  late final _price = TextEditingController(
      text: khoPriceInput(widget.line.unitPrice, widget.line.unit));
  late final _lot = TextEditingController(text: widget.line.lotCode ?? '');
  late PoLine _line = widget.line;

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _lot.dispose();
    super.dispose();
  }

  void _push() => widget.onChanged(_line);

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _line.expiry ?? now.add(const Duration(days: 7)),
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (d == null) return;
    _line = _line.copyWith(expiry: d);
    setState(() {});
    _push();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.line.unit;
    final prevPrice = widget.line.lastPrice;
    final price = _line.unitPrice;
    String? hint;
    if (widget.showPrice && prevPrice != null && price != null && prevPrice > 0) {
      final pct = (price - prevPrice) / prevPrice * 100;
      hint = 'Giá nhập trước: ${formatKhoPrice(prevPrice, u)} · Giá mới ${formatPct(pct)}';
    } else if (widget.showPrice && prevPrice != null) {
      hint = 'Giá nhập trước: ${formatKhoPrice(prevPrice, u)}';
    }
    return KhoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(widget.line.name, style: AppTextStyles.cardTitle)),
            IconButton(
                tooltip: 'Bỏ dòng này',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.close_rounded)),
          ]),
          Row(children: [
            Expanded(
              child: AppTextField(
                label: 'Số lượng * (${displayUnit(u)})',
                controller: _qty,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (t) {
                  _line = _line.copyWith(qty: parseKhoQty(t, u) ?? 0);
                  _push();
                },
              ),
            ),
            if (widget.showPrice) ...[
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  label: 'Đơn giá (đ / ${displayUnit(u)}) *',
                  controller: _price,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [VndInputFormatter()],
                  onChanged: (t) {
                    final p = parseKhoPrice(t, u);
                    _line = p == null
                        ? _line.copyWith(clearPrice: true)
                        : _line.copyWith(unitPrice: p);
                    setState(() {});
                    _push();
                  },
                ),
              ),
            ],
          ]),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint, style: AppTextStyles.caption),
          ],
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: AppTextField(
                label: 'Mã lô',
                controller: _lot,
                hint: 'Tự đặt nếu để trống',
                onChanged: (t) {
                  _line = _line.copyWith(lotCode: t.trim());
                  _push();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hạn dùng', style: AppTextStyles.label),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: _pickExpiry,
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(AppSizes.controlHeight)),
                    child: Text(_line.expiry == null
                        ? 'Chọn ngày'
                        : formatDmy(_line.expiry!)),
                  ),
                ],
              ),
            ),
          ]),
          if (widget.showPrice && _line.lineTotal != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('Thành tiền ${formatVnd(_line.lineTotal!)}',
                  style: AppTextStyles.bodyStrong),
            ),
          ],
        ],
      ),
    );
  }
}

// ======================================================================
// Xác nhận và tác động giá
// ======================================================================
class PoImpactScreen extends StatelessWidget {
  const PoImpactScreen({super.key, required this.form, required this.impact});

  final PoFormController form;
  final PoImpact impact;

  Future<void> _confirm(BuildContext context) async {
    final saved = await guarded(context, form.confirm);
    if (saved != null && context.mounted) {
      showNotice(context, 'Đã nhập ${saved.code}. Kho và giá bình quân đã cập nhật.');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: form,
        builder: (context, _) => KhoPage(
          title: 'Giá mới, nhìn cho rõ',
          subtitle: '${impact.code} · Trước khi xác nhận',
          bottom: Column(mainAxisSize: MainAxisSize.min, children: [
            PrimaryButton(
              label: form.grandTotal == null
                  ? 'Xác nhận nhập'
                  : 'Xác nhận nhập · ${formatVnd(form.grandTotal!)}',
              loading: form.busy,
              onPressed: () => _confirm(context),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
                label: 'Quay lại sửa phiếu',
                onPressed: () => Navigator.of(context).pop(false)),
          ]),
          body: LazyListView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            children: [
              const KhoNote(
                  'Giá nhập mới khác giá bình quân. Giá bán không tự thay đổi.',
                  icon: Icons.sell_outlined),
              const KhoSectionTitle('Sau khi xác nhận'),
              for (final i in impact.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: KhoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${i.name} · ${formatKhoQty(i.qty, i.unit)}',
                            style: AppTextStyles.cardTitle),
                        const SizedBox(height: 6),
                        LabelValueRow(
                            'Giá nhập',
                            '${i.lastPrice == null ? '' : '${formatKhoPrice(i.lastPrice, i.unit)} → '}${formatKhoPrice(i.price, i.unit)}${i.priceChangePct == null ? '' : ' (${formatPct(i.priceChangePct!)})'}'),
                        LabelValueRow(
                            'Giá bình quân sau nhập',
                            '${i.avgBefore == null ? '' : '${formatKhoPrice(i.avgBefore, i.unit)} → '}${formatKhoPrice(i.avgAfter, i.unit)}${i.avgChangePct == null ? '' : ' · ${i.avgChangePct! >= 0 ? 'Tăng' : 'Giảm'} ${i.avgChangePct!.abs().round()}%'}',
                            strong: true),
                        LabelValueRow('Tồn sau nhập',
                            formatKhoQty(i.stockAfter, i.unit)),
                      ],
                    ),
                  ),
                ),
              if (impact.sizes.isNotEmpty) ...[
                const KhoSectionTitle('Tác động lên giá vốn'),
                KhoCard(
                  child: Column(children: [
                    for (final s in impact.sizes.take(10))
                      LabelValueRow(
                        '${s.itemName} · ${s.sizeName}',
                        s.costAfter == null
                            ? '—'
                            : '${s.costBefore == null ? '' : '${formatVnd(s.costBefore!)} → '}${formatVnd(s.costAfter!)}${s.marginAfterPct == null ? '' : ' · biên ${s.marginAfterPct!.toStringAsFixed(0)}%'}',
                      ),
                  ]),
                ),
                const SizedBox(height: 6),
                Text('Biên lợi nhuận tính nếu giữ nguyên giá bán hiện tại.',
                    style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
      );
}

// ======================================================================
// Gợi ý nhập hàng
// ======================================================================
class SuggestionsScreen extends StatefulWidget {
  const SuggestionsScreen({super.key});

  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<Suggestions> _data = AsyncData(_repo.suggestions)..load();
  final Map<String, int> _qty = {};
  final Set<String> _off = {};
  bool _busy = false;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _editQty(SuggestionItem i) async {
    final c = TextEditingController(
        text: khoQtyInput(_qty[i.ingredientId] ?? i.suggestedQty, i.unit));
    final text = await AppSheet.show<String>(
      context,
      builder: (ctx) => AppSheet(
        title: 'Lượng gợi ý · ${i.name}',
        footer: PrimaryButton(
            label: 'Dùng lượng này',
            onPressed: () => Navigator.pop(ctx, c.text)),
        child: AppTextField(
          label: 'Số lượng (${displayUnit(i.unit)})',
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ),
    );
    c.dispose();
    if (text == null) return;
    final v = parseKhoQty(text, i.unit);
    if (v == null || v <= 0) {
      if (mounted) showNotice(context, 'Số lượng chưa đúng.');
      return;
    }
    setState(() => _qty[i.ingredientId] = v);
  }

  Future<void> _create(Suggestions s) async {
    final picked = [
      for (final i in s.items)
        if (!_off.contains(i.ingredientId))
          (
            ingredientId: i.ingredientId,
            qty: _qty[i.ingredientId] ?? i.suggestedQty,
            supplierId: i.supplierId,
          )
    ];
    if (picked.isEmpty) return;
    setState(() => _busy = true);
    final drafts =
        await guarded(context, () => _repo.draftsFromSuggestions(picked));
    if (!mounted) return;
    setState(() => _busy = false);
    if (drafts == null || drafts.isEmpty) return;
    showNotice(context,
        'Đã tạo ${drafts.length} phiếu nháp: ${drafts.map((d) => d.code).join(', ')}. Không có đơn hàng nào được gửi.');
    await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => PoFormScreen(isOwner: true, orderId: drafts.first.id)));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final s = _data.data;
          final selected = s == null
              ? 0
              : s.items.where((i) => !_off.contains(i.ingredientId)).length;
          return KhoPage(
            title: 'Lần nhập tới, vừa đủ',
            subtitle: s == null
                ? null
                : 'Gợi ý ${formatDateTimeFull(s.generatedAt)}${s.draftCodes.isEmpty ? '' : ' · Chưa gồm phiếu ${s.draftCodes.join(', ')}'}',
            bottom: s == null || s.items.isEmpty
                ? null
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    PrimaryButton(
                      label: 'Tạo phiếu nháp · $selected nguyên liệu',
                      loading: _busy,
                      onPressed: selected == 0 ? null : () => _create(s),
                    ),
                    TertiaryButton(
                        label: 'Để sau, không tạo phiếu',
                        onPressed: () => Navigator.of(context).pop()),
                  ]),
            body: AsyncView<Suggestions>(
              source: _data,
              builder: (context, s) {
                if (s.items.isEmpty) {
                  return const [
                    KhoNote(
                        'Chưa cần nhập gì thêm. Kho đủ cho những ngày tới theo mức dùng gần đây.',
                        icon: Icons.check_circle_outline_rounded),
                  ];
                }
                final groups =
                    groupBy<SuggestionItem>(s.items, (i) => i.supplierName);
                return [
                  const KhoNote(
                      'Một gợi ý nhỏ. Quyết định vẫn ở bạn: Fore chỉ tạo phiếu nháp, không gửi đơn hàng nào.'),
                  for (final e in groups.entries) ...[
                    KhoSectionTitle(e.key == 'Khác' ? 'Chưa có nhà cung cấp' : e.key),
                    Text(
                      [
                        'Giao sau ${e.value.first.leadDays} ngày',
                        if (e.value.first.orderCutoff != null)
                          'Chốt trước ${e.value.first.orderCutoff}',
                        'Dùng ${s.windowDays} ngày gần nhất',
                      ].join(' · '),
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 8),
                    for (final i in e.value)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: KhoCard(
                          child: Row(children: [
                            Checkbox(
                              value: !_off.contains(i.ingredientId),
                              onChanged: (v) => setState(() => v == true
                                  ? _off.remove(i.ingredientId)
                                  : _off.add(i.ingredientId)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(i.name, style: AppTextStyles.cardTitle),
                                  Text(
                                    'Còn ${formatKhoQty(i.stock, i.unit)} · ${formatDaysLeft(i.daysLeft)}',
                                    style: AppTextStyles.caption,
                                  ),
                                  Text('Lượng gợi ý · Có thể sửa',
                                      style: AppTextStyles.caption),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () => _editQty(i),
                              child: Text(formatKhoQty(
                                  _qty[i.ingredientId] ?? i.suggestedQty, i.unit)),
                            ),
                          ]),
                        ),
                      ),
                  ],
                ];
              },
            ),
          );
        },
      );
}

// ======================================================================
// Danh sách phiếu + chi tiết (bổ sung giá)
// ======================================================================
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key, this.initialTab = 0});

  /// 0 = Nháp, 1 = Chờ bổ sung giá, 2 = Đã nhập.
  final int initialTab;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late int _tab = widget.initialTab;
  late AsyncData<List<PoSummary>> _data = _make()..load();

  AsyncData<List<PoSummary>> _make() => AsyncData(() async {
        final list = await _repo.orders(status: _tab == 0 ? 'draft' : 'confirmed');
        return _tab == 1 ? list.where((o) => o.needsPricing).toList() : list;
      });

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  void _select(int i) {
    final old = _data;
    setState(() {
      _tab = i;
      _data = _make()..load();
    });
    old.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _data.load(silent: true);
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Phiếu nhập hàng',
        subtitle: 'Mỗi lần nhập đều có phiếu và người ghi',
        bottom: PrimaryButton(
            label: 'Nhập hàng mới',
            onPressed: () => _open(const PoFormScreen(isOwner: true))),
        body: AsyncView<List<PoSummary>>(
          source: _data,
          builder: (context, list) => [
            KhoChipBar(
                labels: const ['Nháp', 'Chờ bổ sung giá', 'Đã nhập'],
                selected: _tab,
                onSelected: _select),
            const SizedBox(height: 12),
            if (list.isEmpty) const KhoNote('Chưa có phiếu nào ở mục này.'),
            for (final o in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KhoCard(
                  onTap: () => _open(o.status == PoStatus.draft
                      ? PoFormScreen(isOwner: true, orderId: o.id)
                      : PoDetailScreen(orderId: o.id)),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${o.code} · ${o.supplierName ?? 'Chưa chọn nhà cung cấp'}',
                              style: AppTextStyles.cardTitle),
                          Text(
                              '${o.lineCount} dòng · ${formatDateTimeShort(o.receivedAt ?? o.updatedAt ?? DateTime.now())}',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    if (o.needsPricing)
                      const StatusChip(
                          label: 'Chờ giá',
                          severity: StatusSeverity.attention,
                          compact: true)
                    else
                      Text(
                          o.totalAmount == null ? '' : formatVnd(o.totalAmount!),
                          style: AppTextStyles.bodyStrong),
                  ]),
                ),
              ),
          ],
        ),
      );
}

class PoDetailScreen extends StatefulWidget {
  const PoDetailScreen({super.key, required this.orderId, this.isOwner = true});

  final String orderId;
  final bool isOwner;

  @override
  State<PoDetailScreen> createState() => _PoDetailScreenState();
}

class _PoDetailScreenState extends State<PoDetailScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<PoDetail> _data =
      AsyncData(() => _repo.orderDetail(widget.orderId))..load();
  final Map<String, TextEditingController> _prices = {};
  bool _busy = false;

  @override
  void dispose() {
    _data.dispose();
    for (final c in _prices.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _savePrices(PoDetail o) async {
    final map = <String, double>{};
    for (final l in o.lines) {
      if (l.id == null || l.unitPrice != null) continue;
      final p = parseKhoPrice(_prices[l.id]?.text ?? '', l.unit);
      if (p == null) {
        return showNotice(context, 'Hãy điền đơn giá cho ${l.name}.');
      }
      map[l.id!] = p;
    }
    setState(() => _busy = true);
    final r = await guarded(context, () => _repo.setOrderPrices(o.id, map));
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      showNotice(context, 'Đã bổ sung giá. Giá bình quân đã cập nhật.');
      _data.load(silent: true);
    }
  }

  Future<void> _requestFix(PoDetail o) async {
    final c = TextEditingController();
    final note = await AppSheet.show<String>(
      context,
      builder: (ctx) => AppSheet(
        title: 'Gửi yêu cầu sửa cho chủ',
        footer: PrimaryButton(
            label: 'Gửi yêu cầu', onPressed: () => Navigator.pop(ctx, c.text)),
        child: AppTextField(label: 'Cần sửa gì?', controller: c),
      ),
    );
    c.dispose();
    if (note == null || !mounted) return;
    final done = await guarded(context, () async {
      await _repo.requestCorrection(kind: 'purchase', refId: o.id, note: note);
      return true;
    });
    if (done == true && mounted) showNotice(context, 'Đã gửi yêu cầu cho chủ quán.');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final o = _data.data;
          return KhoPage(
            title: o?.code ?? 'Phiếu nhập',
            subtitle: o == null
                ? null
                : '${o.supplierName ?? ''}${o.receivedAt == null ? '' : ' · ${formatDateTimeFull(o.receivedAt!)}'}',
            bottom: o != null && widget.isOwner && o.needsPricing
                ? PrimaryButton(
                    label: 'Lưu giá cho phiếu',
                    loading: _busy,
                    onPressed: () => _savePrices(o))
                : null,
            body: AsyncView<PoDetail>(
              source: _data,
              builder: (context, o) => [
                if (o.needsPricing)
                  KhoNote(
                      widget.isOwner
                          ? 'Nhân viên đã nhận hàng. Điền giá để cập nhật giá bình quân.'
                          : 'Đã nhận hàng · Chờ chủ bổ sung giá',
                      icon: Icons.sell_outlined),
                const SizedBox(height: 8),
                for (final l in o.lines)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KhoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name, style: AppTextStyles.cardTitle),
                          Text(
                            [
                              formatKhoQty(l.qty, l.unit),
                              if (l.lotCode != null) 'Lô ${l.lotCode}',
                              if (l.expiry != null) 'HSD ${formatDmy(l.expiry!)}',
                            ].join(' · '),
                            style: AppTextStyles.caption,
                          ),
                          if (widget.isOwner && l.unitPrice != null)
                            LabelValueRow(formatKhoPrice(l.unitPrice, l.unit),
                                l.lineTotal == null ? '' : formatVnd(l.lineTotal!),
                                strong: true),
                          if (widget.isOwner && l.unitPrice == null && l.id != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: AppTextField(
                                label: 'Đơn giá (đ / ${displayUnit(l.unit)}) *',
                                controller: _prices.putIfAbsent(
                                    l.id!, () => TextEditingController()),
                                keyboardType: TextInputType.number,
                                inputFormatters: const [VndInputFormatter()],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (widget.isOwner && o.totalAmount != null)
                  KhoCard(
                    child: Column(children: [
                      LabelValueRow('Giao hàng', formatVnd(o.shippingFee ?? 0)),
                      LabelValueRow('Tổng cộng', formatVnd(o.totalAmount!),
                          strong: true),
                    ]),
                  ),
                if (!widget.isOwner)
                  TertiaryButton(
                      label: 'Ghi nhầm? Gửi yêu cầu sửa cho chủ',
                      onPressed: () => _requestFix(o)),
              ],
            ),
          );
        },
      );
}
