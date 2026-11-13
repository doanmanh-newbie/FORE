import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/ops_icon.dart';
import '../../../core/widgets/fore_sheet.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/table_map_controller.dart';
import '../domain/sales_models.dart';

/// Tab "Trang chủ" khi đang có ca (thiết kế "Home / Shift-open"): chọn khu, tìm bàn, lưới bàn.
/// Chạm bàn trống để mở bill; chạm bàn đang dùng để vào bill đang mở.
class TablesView extends StatefulWidget {
  const TablesView({
    super.key,
    required this.tables,
    required this.servingLabel,
    required this.onOpenBill,
  });

  final TableMapController tables;
  final String servingLabel;

  /// Mở màn bill; hoàn thành khi người dùng quay lại (để tải lại bản đồ).
  final Future<void> Function(String billId) onOpenBill;

  @override
  State<TablesView> createState() => _TablesViewState();
}

class _TablesViewState extends State<TablesView> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _tap(TableSlot slot) async {
    final billId = slot.billId;
    if (billId != null) {
      await widget.onOpenBill(billId);
      return;
    }
    final guests = await showForeSheet<int>(
      context,
      title: slot.tableName,
      subtitle: 'Mở bill cho bàn này. Số khách không bắt buộc.',
      builder: (_) => const _GuestsForm(),
    );
    if (guests == null || !mounted) return;
    final id = await guarded(
        context,
        () =>
            widget.tables.openTable(slot, guests: guests == 0 ? null : guests));
    if (id != null && mounted) await widget.onOpenBill(id);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.tables,
        builder: (context, _) {
          final c = widget.tables;
          if (c.phase == LoadPhase.loading && c.slots.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (c.phase == LoadPhase.error) {
            final failure = c.failure;
            final diagnostic = failure is DatabaseFailure
                ? '\n\nMã lỗi: ${failure.code}'
                : kDebugMode && failure is UnknownFailure
                    ? '\n\nChi tiết kỹ thuật: ${failure.detail}'
                    : '';
            return ErrorRetry(
              message:
                  '${failure?.userMessage ?? 'Không tải được sơ đồ bàn.'}$diagnostic',
              onRetry: c.load,
            );
          }
          if (c.areas.isEmpty) {
            return const EmptyState(
              icon: ForeIcons.package,
              title: 'Chưa có bàn nào',
              message: 'Chủ quán cần tạo khu và bàn trước khi nhận order.',
            );
          }
          final area = c.selectedArea!;
          final visible = c.visibleTables;
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final tableCardExtent = 112.0 + (textScale - 1).clamp(0.0, 0.8) * 136;
          return RefreshIndicator(
            onRefresh: c.load,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _filters(c)),
                if (c.failure != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'Đang hiện dữ liệu cũ vì mất kết nối. Kéo xuống để thử lại.',
                        style: TextStyle(
                            fontSize: AppFontSizes.s12,
                            color: AppColors.statusWatch),
                      ),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: SectionHeader(
                      title: c.isSearching ? 'Kết quả tìm' : area.name,
                      trailing: c.isSearching
                          ? '${visible.length} bàn'
                          : '${area.tables.length} bàn · ${area.busyCount} đang dùng',
                    ),
                  ),
                ),
                if (visible.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Không có bàn nào khớp.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: tableCardExtent,
                      ),
                      itemCount: visible.length,
                      itemBuilder: (_, i) => _TableCard(
                        slot: visible[i],
                        servingLabel: widget.servingLabel,
                        showArea: c.isSearching,
                        onTap: () => _tap(visible[i]),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  Widget _filters(TableMapController c) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (c.areas.length > 1)
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: c.areas.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final a = c.areas[i];
                    final selected =
                        !c.isSearching && a.id == c.selectedArea?.id;
                    return _AreaChip(
                      label: a.name,
                      selected: selected,
                      onTap: () {
                        _search.clear();
                        c.setQuery('');
                        c.selectArea(a.id);
                      },
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: _search,
              onChanged: c.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Tìm bàn',
                prefixIcon: Icon(Icons.search_rounded,
                    color: AppColors.textSecondary),
                suffixIcon: c.query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Xóa',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _search.clear();
                          c.setQuery('');
                        },
                      ),
              ),
            ),
          ],
        ),
      );
}

class _AreaChip extends StatelessWidget {
  const _AreaChip(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: ExcludeSemantics(
          child: PressableScale(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: selected ? AppColors.ink : AppColors.border),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSizes.s15,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.onInk : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      );
}

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.slot,
    required this.servingLabel,
    required this.showArea,
    required this.onTap,
  });

  final TableSlot slot;
  final String servingLabel;
  final bool showArea;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final busy = slot.isBusy;
    final Color fg = busy ? AppColors.onInk : AppColors.ink;
    final Color sub = busy ? AppColors.onInkMuted : AppColors.textSecondary;
    final status = busy ? 'Đang dùng' : 'Trống';
    final detail = busy
        ? '${formatServings(slot.portions, servingLabel)}'
            '${slot.billOpenedAt == null ? '' : ' · ${formatClock(slot.billOpenedAt!)}'}'
        : 'Sẵn sàng';
    return Semantics(
      button: true,
      label: '${slot.tableName}, $status, $detail',
      child: ExcludeSemantics(
        child: PressableScale(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: busy ? AppColors.ink : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: busy ? null : Border.all(color: AppColors.hairline),
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slot.tableName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: AppFontSizes.s18,
                            fontWeight: FontWeight.w700,
                            color: fg),
                      ),
                    ),
                    if (showArea)
                      Text(slot.areaName,
                          style: TextStyle(
                              fontSize: AppFontSizes.s12, color: sub)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusChip(
                      label: status,
                      severity: busy
                          ? StatusSeverity.neutral
                          : StatusSeverity.healthy,
                      compact: true,
                    ),
                    const SizedBox(height: 2),
                    Text(detail,
                        style:
                            TextStyle(fontSize: AppFontSizes.s14, color: sub)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GuestsForm extends StatefulWidget {
  const _GuestsForm();

  @override
  State<_GuestsForm> createState() => _GuestsFormState();
}

class _GuestsFormState extends State<_GuestsForm> {
  int _guests = 0;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('Số khách', style: AppTextStyles.title)),
              _RoundIcon(
                icon: Icons.remove_rounded,
                onTap: _guests > 0 ? () => setState(() => _guests--) : null,
              ),
              SizedBox(
                width: 56,
                child: Text(
                  _guests == 0 ? '–' : '$_guests',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.number,
                ),
              ),
              _RoundIcon(
                icon: Icons.add_rounded,
                onTap: _guests < 50 ? () => setState(() => _guests++) : null,
              ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_guests),
            child: const Text('Mở bàn'),
          ),
        ],
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton.filledTonal(
        tooltip:
            icon == Icons.remove_rounded ? 'Giảm số khách' : 'Tăng số khách',
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.surfaceTint,
          foregroundColor: AppColors.ink,
        ),
      );
}
