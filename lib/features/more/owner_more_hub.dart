import 'package:flutter/material.dart';

import '../../core/design/app_sheet.dart';
import '../../core/design/colors.dart';
import '../../core/design/spacing.dart';
import '../../core/design/typography.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/page_scaffold.dart';
import 'more_prefs.dart';

/// Một lối vào trong tab "Thêm". Mục chưa có màn đích thì KHÔNG đưa vào danh sách
/// (không hiện nút bấm vào chỗ trống); khi có màn mới chỉ cần thêm một [MoreEntry].
class MoreEntry {
  const MoreEntry({
    required this.id,
    required this.group,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.keywords = const [],
  });

  final String id;
  final String group;
  final IconData icon;
  final String title;
  final String subtitle;

  /// `null` = tạm khóa (ví dụ cần mở ca); mục vẫn hiện, phụ đề nói rõ lý do.
  final VoidCallback? onTap;
  final List<String> keywords;

  bool matches(String foldedQuery) =>
      foldVietnamese('$title $subtitle ${keywords.join(' ')}')
          .contains(foldedQuery);
}

/// Tab "Thêm" của chủ quán: hồ sơ, đổi quán, tìm chức năng, mục ghim, các nhóm lối vào,
/// chế độ gọn và đăng xuất.
class OwnerMoreHub extends StatefulWidget {
  const OwnerMoreHub({
    super.key,
    required this.personName,
    required this.shopName,
    required this.entries,
    required this.onSwitchShop,
    required this.onSignOut,
    this.header,
    this.prefs,
  });

  final String personName;
  final String shopName;
  final List<MoreEntry> entries;
  final VoidCallback onSwitchShop;
  final VoidCallback onSignOut;
  final Widget? header;

  /// Cho test; để trống thì đọc từ bộ nhớ thiết bị.
  final MorePrefs? prefs;

  @override
  State<OwnerMoreHub> createState() => _OwnerMoreHubState();
}

class _OwnerMoreHubState extends State<OwnerMoreHub> {
  late MorePrefs _prefs = widget.prefs ?? MorePrefs.memory();
  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.prefs == null) {
      MorePrefs.load().then((p) {
        if (mounted) setState(() => _prefs = p);
      }, onError: (Object _) {});
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _editPins() async {
    await AppSheet.show<void>(
      context,
      builder: (ctx) => ListenableBuilder(
        listenable: _prefs,
        builder: (ctx, _) => AppSheet(
          title: 'Chọn mục ghim (tối đa ${MorePrefs.maxPinned})',
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in widget.entries)
              CheckboxListTile(
                value: _prefs.isPinned(e.id),
                title: Text(e.title),
                onChanged: (_) async {
                  final ok = await _prefs.togglePin(e.id);
                  if (!ok && ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text(
                            'Đã ghim đủ 3 mục. Bỏ một mục để ghim mục khác.')));
                  }
                },
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([_prefs, _search]),
        builder: (context, _) {
          final query = foldVietnamese(_search.text.trim());
          final searching = query.isNotEmpty;
          final byId = {for (final e in widget.entries) e.id: e};
          final pinned = [
            for (final id in _prefs.pinned)
              if (byId[id] != null) byId[id]!,
          ];
          final groups = <String, List<MoreEntry>>{};
          for (final e in widget.entries) {
            if (searching && !e.matches(query)) continue;
            groups.putIfAbsent(e.group, () => []).add(e);
          }
          return PageScaffold(
            header: widget.header,
            children: [
              Text('Chăm quán, từ những điều nhỏ',
                  style: AppTextStyles.display),
              const SizedBox(height: 6),
              Text('Mọi thiết lập, gọn trong một cuốn sổ.',
                  style: AppTextStyles.caption),
              const SizedBox(height: 16),
              ForeCard(
                radius: AppSizes.radiusCard,
                padding: const EdgeInsets.all(AppSizes.cardPadding),
                child: Column(children: [
                  _ProfileRow(
                    icon: Icons.person_outline_rounded,
                    title: widget.personName,
                    subtitle: 'Chủ quán',
                  ),
                  Divider(height: 24, color: AppColors.cardBorder),
                  _ProfileRow(
                    icon: Icons.storefront_outlined,
                    title: widget.shopName.isEmpty ? 'Quán' : widget.shopName,
                    subtitle: 'Quán đang dùng',
                    action: 'Đổi quán',
                    onAction: widget.onSwitchShop,
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Tìm chức năng…',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 20),
              if (!searching && pinned.isNotEmpty) ...[
                Row(children: [
                  Expanded(
                      child: Text('Đã ghim', style: AppTextStyles.headline)),
                  TextButton(
                      onPressed: _editPins, child: const Text('Chỉnh sửa')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  for (var i = 0; i < pinned.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(child: _PinnedTile(entry: pinned[i])),
                  ],
                ]),
                const SizedBox(height: 20),
              ] else if (!searching)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                      onPressed: _editPins, child: const Text('Ghim lối tắt')),
                ),
              if (searching && groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('Không có chức năng nào khớp. Thử từ khác nhé.',
                      style: AppTextStyles.caption),
                ),
              for (final g in groups.entries) ...[
                Text(g.key, style: AppTextStyles.headline),
                const SizedBox(height: 8),
                ForeCard(
                  radius: AppSizes.radiusCard,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    for (var i = 0; i < g.value.length; i++) ...[
                      if (i > 0)
                        Divider(
                            height: 1,
                            indent: 60,
                            color: AppColors.cardBorder),
                      _EntryRow(entry: g.value[i], compact: _prefs.compact),
                    ],
                  ]),
                ),
                const SizedBox(height: 20),
              ],
              if (!searching) ...[
                ForeCard(
                  radius: AppSizes.radiusCard,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.cardPadding, vertical: 4),
                  child: Material(
                    color: Colors.transparent,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _prefs.compact,
                      onChanged: _prefs.setCompact,
                      title: const Text('Chế độ gọn'),
                      subtitle:
                          const Text('Ẩn dòng mô tả để trang Thêm ngắn lại'),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                    onPressed: widget.onSignOut,
                    child: const Text('Đăng xuất')),
              ],
            ],
          );
        },
      );
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.brand),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.title),
              Text(subtitle, style: AppTextStyles.caption),
            ],
          ),
        ),
        if (action != null)
          TextButton(onPressed: onAction, child: Text(action!)),
      ]);
}

class _PinnedTile extends StatelessWidget {
  const _PinnedTile({required this.entry});

  final MoreEntry entry;

  @override
  Widget build(BuildContext context) => ForeCard(
        onTap: entry.onTap,
        radius: AppSizes.radiusCard,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        child: Column(children: [
          Icon(entry.icon,
              color: entry.onTap == null
                  ? AppColors.textSecondary
                  : AppColors.brand),
          const SizedBox(height: 6),
          Text(entry.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.captionStrong),
        ]),
      );
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.compact});

  final MoreEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        enabled: entry.onTap != null,
        label: entry.title,
        child: InkWell(
          onTap: entry.onTap,
          borderRadius: BorderRadius.circular(AppSizes.radiusTile),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(children: [
              Icon(entry.icon,
                  color: entry.onTap == null
                      ? AppColors.textSecondary
                      : AppColors.brand),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: AppTextStyles.title),
                    if (!compact || entry.onTap == null) ...[
                      const SizedBox(height: 2),
                      Text(entry.subtitle, style: AppTextStyles.caption),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondary),
            ]),
          ),
        ),
      );
}
