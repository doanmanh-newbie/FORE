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
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../domain/inventory_models.dart' show WasteTypeOption;
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';
import '../../../core/widgets/lazy_list_view.dart';

// ======================================================================
// Ghi hao hụt (nhân viên): chọn nguyên liệu, lô, số lượng, lý do
// ======================================================================
class WasteEntryScreen extends StatefulWidget {
  const WasteEntryScreen({super.key});

  @override
  State<WasteEntryScreen> createState() => _WasteEntryScreenState();
}

class _WasteEntryScreenState extends State<WasteEntryScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  List<PickerItem> _items = const [];
  List<WasteTypeOption> _types = const [];
  List<LotOption> _lots = const [];
  PickerItem? _item;
  LotOption? _lot;
  String? _type;
  final _qty = TextEditingController();
  final _note = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  WasteRecord? _done;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await guarded(context, _repo.picker);
    if (!mounted) return;
    final types = await guarded(context, _repo.wasteTypes);
    if (!mounted) return;
    setState(() {
      _items = items ?? const [];
      _types = types ?? const [];
      _loading = false;
    });
  }

  Future<void> _pickItem() async {
    final chosen = await AppSheet.show<PickerItem>(
      context,
      builder: (ctx) => AppSheet(
        title: 'Chọn nguyên liệu',
        child: SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.5,
          child: LazyListView(children: [
            for (final i in _items)
              ListTile(
                title: Text(i.name),
                subtitle: Text(i.group ?? 'Khác'),
                onTap: () => Navigator.pop(ctx, i),
              ),
          ]),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    setState(() {
      _item = chosen;
      _lot = null;
      _lots = const [];
    });
    final lots = await guarded(context, () => _repo.lotsFor(chosen.id));
    if (!mounted) return;
    setState(() {
      _lots = lots ?? const [];
      // Lô gần hết hạn nhất nằm đầu danh sách: gợi ý sẵn, nhân viên vẫn đổi được.
      _lot = _lots.isEmpty ? null : _lots.first;
    });
  }

  WasteTypeOption? get _typeOpt =>
      _types.where((t) => t.code == _type).firstOrNull;

  Future<void> _save() async {
    final item = _item;
    if (item == null) return showNotice(context, 'Hãy chọn nguyên liệu.');
    final qty = parseKhoQty(_qty.text, item.unit);
    if (qty == null || qty <= 0) {
      return showNotice(context, 'Số lượng chưa đúng. Ví dụ: 0,5 hoặc 2.');
    }
    if (_type == null) return showNotice(context, 'Hãy chọn lý do hao hụt.');
    if ((_typeOpt?.requiresNote ?? false) && _note.text.trim().length < 5) {
      return showNotice(context, 'Lý do này cần ghi chú ngắn (ít nhất 5 ký tự).');
    }
    setState(() => _busy = true);
    final r = await guarded(
      context,
      () => _repo.addWaste(
          ingredientId: item.id,
          qty: qty,
          typeCode: _type!,
          note: _note.text,
          lotId: _lot?.id),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = r;
    });
  }

  Future<void> _requestFix() async {
    final done = _done;
    if (done == null) return;
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
    final ok = await guarded(context, () async {
      await _repo.requestCorrection(kind: 'waste', refId: done.id, note: note);
      return true;
    });
    if (ok == true && mounted) {
      showNotice(context, 'Đã gửi yêu cầu cho chủ quán.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const KhoPage(title: 'Ghi hao hụt', body: KhoSkeleton());
    final done = _done;
    if (done != null) {
      return KhoPage(
        title: 'Đã ghi hao hụt',
        subtitle: '${done.code} · ${formatDateTimeFull(done.at)}',
        bottom: PrimaryButton(
            label: 'Xong', onPressed: () => Navigator.of(context).pop()),
        body: LazyListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            const KhoNote(
                'Phiếu đã vào sổ kho cùng tên bạn và giờ ghi. Chủ quán sẽ thấy ở mục Hao hụt.',
                icon: Icons.check_circle_outline_rounded),
            const SizedBox(height: 12),
            TertiaryButton(
                label: 'Ghi nhầm? Gửi yêu cầu sửa cho chủ',
                onPressed: _requestFix),
          ],
        ),
      );
    }
    final item = _item;
    return KhoPage(
      title: 'Ghi hao hụt',
      subtitle: 'Ghi thật, kho mới chính xác',
      bottom: PrimaryButton(label: 'Ghi hao hụt', loading: _busy, onPressed: _save),
      body: LazyListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          Text('Nguyên liệu *', style: AppTextStyles.label),
          const SizedBox(height: 6),
          OutlinedButton(
            onPressed: _pickItem,
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(AppSizes.controlHeight),
                alignment: Alignment.centerLeft),
            child: Text(item?.name ?? 'Chọn nguyên liệu'),
          ),
          if (item != null) ...[
            const SizedBox(height: 14),
            Text('Lô hàng', style: AppTextStyles.label),
            const SizedBox(height: 6),
            if (_lots.isEmpty)
              const KhoNote('Nguyên liệu này chưa có lô nào ghi hạn dùng.')
            else
              DropdownButtonFormField<String?>(
                value: _lot?.id,
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String?>(
                      value: null, child: Text('Không rõ lô')),
                  for (final l in _lots)
                    DropdownMenuItem<String?>(
                        value: l.id,
                        child: Text(
                            'Lô ${l.code}${l.expiry == null ? '' : ' · HSD ${formatShortDate(l.expiry!)}'}')),
                ],
                onChanged: (v) => setState(
                    () => _lot = _lots.where((l) => l.id == v).firstOrNull),
              ),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Số lượng hao hụt * (${displayUnit(item.unit)})',
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
          const SizedBox(height: 14),
          Text('Lý do *', style: AppTextStyles.label),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in _types)
              ChoiceChip(
                label: Text(t.label),
                selected: _type == t.code,
                onSelected: (_) => setState(() => _type = t.code),
              ),
          ]),
          const SizedBox(height: 14),
          AppTextField(
            label: (_typeOpt?.requiresNote ?? false)
                ? 'Ghi chú *'
                : 'Ghi chú (không bắt buộc)',
            controller: _note,
          ),
        ],
      ),
    );
  }
}

// ======================================================================
// Hao hụt: góc nhìn của chủ
// ======================================================================
class WasteOverviewScreen extends StatefulWidget {
  const WasteOverviewScreen({super.key});

  @override
  State<WasteOverviewScreen> createState() => _WasteOverviewScreenState();
}

class _WasteOverviewScreenState extends State<WasteOverviewScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  int _days = 7;
  late AsyncData<WasteOverview> _data = _make()..load();

  AsyncData<WasteOverview> _make() => AsyncData(() {
        final now = DateTime.now();
        final to = DateTime(now.year, now.month, now.day);
        return _repo.wasteOverview(to.subtract(Duration(days: _days - 1)), to);
      });

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  void _select(int i) {
    final old = _data;
    setState(() {
      _days = const [7, 14, 30][i];
      _data = _make()..load();
    });
    old.dispose();
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Hao hụt',
        subtitle: 'Góc nhìn của chủ quán',
        body: AsyncView<WasteOverview>(
          source: _data,
          builder: (context, w) {
            final change = w.prevValue <= 0
                ? null
                : (w.totalValue - w.prevValue) * 100 / w.prevValue;
            final maxDay = w.daily.fold<int>(0, (a, d) => d.value > a ? d.value : a);
            final spike = w.spike;
            return [
              KhoChipBar(
                  labels: const ['7 ngày', '14 ngày', '30 ngày'],
                  selected: const [7, 14, 30].indexOf(_days),
                  onSelected: _select),
              const SizedBox(height: 12),
              KhoCard(
                child: BigFigure(
                  label: 'Hao hụt đã ghi · ${formatRange(w.from, w.to)}',
                  value: formatVnd(w.totalValue),
                  caption: change == null
                      ? '${w.entryCount} lần ghi'
                      : '${w.entryCount} lần ghi · ${change >= 0 ? 'Tăng' : 'Giảm'} ${change.abs().round()}% so với kỳ trước',
                ),
              ),
              if (w.unpricedCount > 0) ...[
                const SizedBox(height: 8),
                KhoNote(
                    '${w.unpricedCount} lần ghi thuộc nguyên liệu chưa có giá nên chưa được tính tiền.'),
              ],
              if (spike != null) ...[
                const SizedBox(height: 8),
                KhoNote(
                    '${spike.label} tăng từ ${formatVnd(spike.prevValue)} lên ${formatVnd(spike.value)}. Nên xem lại lô hàng và hạn dùng.',
                    icon: Icons.trending_up_rounded),
              ],
              if (w.daily.isNotEmpty && maxDay > 0) ...[
                const KhoSectionTitle('Theo ngày'),
                KhoCard(
                  child: SizedBox(
                    height: 96,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final d in w.daily)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: Tooltip(
                                message:
                                    '${formatShortDate(d.date)}: ${formatVnd(d.value)}',
                                child: FractionallySizedBox(
                                  heightFactor:
                                      d.value == 0 ? 0.03 : d.value / maxDay,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: d.value == 0
                                          ? AppColors.cardBorder
                                          : AppColors.brand,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const KhoSectionTitle('Theo lý do'),
              if (w.byReason.isEmpty) const KhoNote('Chưa ghi hao hụt nào trong kỳ này.'),
              if (w.byReason.isNotEmpty)
                KhoCard(
                  child: Column(children: [
                    for (final r in w.byReason)
                      LabelValueRow('${r.label} · ${r.count} lần', formatVnd(r.value)),
                  ]),
                ),
              if (w.byIngredient.isNotEmpty) ...[
                const KhoSectionTitle('Theo nguyên liệu'),
                KhoCard(
                  child: Column(children: [
                    for (final i in w.byIngredient.take(8))
                      LabelValueRow('${i.name} · ${formatKhoQty(i.qty, i.unit)}',
                          formatVnd(i.value)),
                  ]),
                ),
              ],
              const SizedBox(height: 12),
              SecondaryButton(
                  label: 'Quay lại tổng quan kho',
                  onPressed: () => Navigator.of(context).pop()),
            ];
          },
        ),
      );
}
