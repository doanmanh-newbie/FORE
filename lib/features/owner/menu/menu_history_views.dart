import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import 'menu_format.dart';
import 'menu_models.dart';
import 'menu_recipe_views.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// Lịch sử thay đổi + các thay đổi đã hẹn của một món.
class MenuHistoryPage extends StatefulWidget {
  const MenuHistoryPage({super.key, required this.itemId, required this.itemName});

  final String itemId;
  final String itemName;

  @override
  State<MenuHistoryPage> createState() => _MenuHistoryPageState();
}

class _MenuHistoryPageState extends State<MenuHistoryPage> {
  MenuHistory? _history;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final h = await context.read<MenuStore>().loadHistory(widget.itemId);
      if (mounted) setState(() => _history = h);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _cancel(UpcomingChange u) async {
    final ok = await confirmSheet(
      context,
      title: u.kind == 'price' ? 'Hủy lịch đổi giá?' : 'Hủy lịch công thức mới?',
      message: 'Thay đổi này chưa áp dụng nên hủy sẽ không ảnh hưởng bill nào. Công thức và giá hiện tại vẫn giữ nguyên.',
      confirmLabel: 'Hủy lịch',
      cancelLabel: 'Giữ lịch',
    );
    if (!ok || !mounted) return;
    final store = context.read<MenuStore>();
    final done = await menuGuard<bool>(context, () async {
      if (u.kind == 'price') {
        await store.cancelPriceChange(u.id);
      } else {
        await store.cancelRecipe(u.id);
      }
      return true;
    });
    if (done == true && mounted) await _load();
  }

  IconData _icon(String kind) => switch (kind) {
        'recipe' => Icons.science_outlined,
        'price' => Icons.sell_outlined,
        'status' => Icons.toggle_on_outlined,
        'copy' => Icons.copy_all_outlined,
        'image' => Icons.image_outlined,
        'category' => Icons.folder_outlined,
        _ => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final h = _history;
    return MenuPage(
      title: 'Lịch sử thay đổi',
      subtitle: widget.itemName,
      children: [
        if (_error != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được lịch sử',
            body: menuErrorMessage(_error!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (h == null)
          const MenuSkeleton(rows: 4)
        else ...[
          if (h.upcoming.isNotEmpty) ...[
            Text('Đã hẹn, chưa áp dụng', style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            for (final u in h.upcoming)
              MenuCard(
                color: AppColors.statusAttentionTint,
                borderColor: AppColors.statusAttentionTint,
                child: Row(
                  children: [
                    Icon(u.kind == 'price' ? Icons.sell_outlined : Icons.science_outlined,
                        color: AppColors.statusAttention),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.kind == 'price'
                                ? 'Size ${u.sizeName}: ${u.oldPrice == null ? '' : '${formatVnd(u.oldPrice!)} → '}${formatVnd(u.newPrice ?? 0)}'
                                : 'Size ${u.sizeName}: công thức v${u.versionNo ?? '?'}',
                            style: AppTextStyles.bodyStrong,
                          ),
                          Text(
                            'Áp dụng ${dateTimeLong(u.effectiveFrom)}${u.actorName == null ? '' : ' · ${u.actorName}'}',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => _cancel(u), child: const Text('Hủy lịch')),
                  ],
                ),
              ),
            const SizedBox(height: 6),
          ],
          Text('Đã diễn ra', style: AppTextStyles.cardTitle),
          const SizedBox(height: 8),
          if (h.events.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('Chưa có thay đổi nào được ghi lại.', style: AppTextStyles.body),
            ),
          for (final e in h.events)
            MenuCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_icon(e.kind), color: AppColors.brand),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.summary, style: AppTextStyles.bodyStrong),
                        Text(
                          '${dateTimeLabel(e.createdAt.toLocal())}${e.actorName == null ? '' : ' · ${e.actorName}'}',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// So sánh các phiên bản công thức của một size.
class RecipeComparePage extends StatefulWidget {
  const RecipeComparePage({super.key, required this.detail, required this.sizeId});

  final ItemDetail detail;
  final String sizeId;

  @override
  State<RecipeComparePage> createState() => _RecipeComparePageState();
}

class _RecipeComparePageState extends State<RecipeComparePage> {
  late String _sizeId = widget.sizeId;
  List<RecipeVersion>? _versions;
  Object? _error;
  String? _leftId;
  String? _rightId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _versions = null;
    });
    try {
      final v = await context.read<MenuStore>().loadVersions(_sizeId);
      if (!mounted) return;
      setState(() {
        _versions = v;
        // Mặc định: bản đang dùng (hoặc bản mới nhất) so với bản liền trước.
        final active = v.where((x) => x.status == 'active').toList();
        final right = active.isNotEmpty ? active.first : (v.isEmpty ? null : v.first);
        RecipeVersion? left;
        if (right != null) {
          for (final x in v) {
            if (x.versionNo < right.versionNo) {
              left = x;
              break;
            }
          }
        }
        _rightId = right?.id;
        _leftId = left?.id;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  RecipeVersion? _find(String? id) {
    for (final v in _versions ?? const <RecipeVersion>[]) {
      if (v.id == id) return v;
    }
    return null;
  }

  String _statusLabel(RecipeVersion v) => switch (v.status) {
        'active' => 'đang dùng',
        'scheduled' => 'đã hẹn',
        _ => 'đã thay',
      };

  @override
  Widget build(BuildContext context) {
    final sizes = widget.detail.activeSizes;
    final size = sizes.firstWhere((s) => s.id == _sizeId, orElse: () => sizes.first);
    final versions = _versions;
    final left = _find(_leftId);
    final right = _find(_rightId);

    Widget picker(String label, String? value, ValueChanged<String?> onChanged) =>
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: [
            for (final v in versions ?? const <RecipeVersion>[])
              DropdownMenuItem(
                value: v.id,
                child: Text('v${v.versionNo} · ${_statusLabel(v)}'),
              ),
          ],
          onChanged: onChanged,
        );

    return MenuPage(
      title: 'So sánh công thức',
      subtitle: '${widget.detail.name} · Size ${size.name}',
      children: [
        SizeTabs(
          labels: [for (final s in sizes) s.name],
          selected: sizes.indexOf(size),
          onChanged: (i) {
            _sizeId = sizes[i].id;
            _load();
          },
        ),
        if (_error != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được các phiên bản',
            body: menuErrorMessage(_error!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (versions == null)
          const MenuSkeleton(rows: 3)
        else if (versions.length < 2)
          const MenuBanner(
            kind: BannerKind.info,
            title: 'Chưa có gì để so sánh',
            body: 'Size này mới có một phiên bản công thức. Khi lưu bản mới, bạn sẽ so sánh được ở đây.',
          )
        else ...[
          Row(
            children: [
              Expanded(child: picker('Bản cũ', _leftId, (v) => setState(() => _leftId = v))),
              const SizedBox(width: 10),
              Expanded(child: picker('Bản mới', _rightId, (v) => setState(() => _rightId = v))),
            ],
          ),
          const SizedBox(height: 12),
          if (left != null && right != null) _diff(left, right, size),
        ],
      ],
    );
  }

  Widget _diff(RecipeVersion a, RecipeVersion b, SizeDetail size) {
    final am = {for (final l in a.lines) l.ingredientId: l};
    final bm = {for (final l in b.lines) l.ingredientId: l};
    final ids = <String>{...am.keys, ...bm.keys};
    final rows = <Widget>[];
    for (final id in ids) {
      final x = am[id];
      final y = bm[id];
      final name = (y ?? x)!.name;
      final unit = menuUnitLabel((y ?? x)!.unit);
      final changed = x?.qty != y?.qty;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                  style: changed ? AppTextStyles.bodyStrong : AppTextStyles.body),
            ),
            Text(x == null ? '—' : '${x.qty} $unit', style: AppTextStyles.body),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward_rounded, size: 14),
            ),
            SizedBox(
              width: 72,
              child: Text(
                y == null ? 'Bỏ' : '${y.qty} $unit',
                textAlign: TextAlign.end,
                style: changed ? AppTextStyles.bodyStrong : AppTextStyles.body,
              ),
            ),
          ],
        ),
      ));
    }
    final ca = a.costKnown ? a.cost : null;
    final cb = b.costKnown ? b.cost : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MenuCard(child: Column(children: rows)),
        MenuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Giá vốn: ${moneyOrUnknown(ca)} → ${moneyOrUnknown(cb)}',
                  style: AppTextStyles.bodyStrong),
              const SizedBox(height: 4),
              Text(
                'Lãi gộp (giá bán hiện tại ${formatVnd(size.price)}): '
                '${ca == null ? '—' : formatVnd(size.price - ca)} → ${cb == null ? '—' : formatVnd(size.price - cb)}',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        Text(
          describeRecipeDiff(draftFromLines(a.lines), draftFromLines(b.lines)).isEmpty
              ? 'Hai bản giống nhau.'
              : 'Thay đổi: ${describeRecipeDiff(draftFromLines(a.lines), draftFromLines(b.lines))}.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
