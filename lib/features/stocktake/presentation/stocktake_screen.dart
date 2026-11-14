import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/stocktake_controller.dart';
import '../domain/stocktake_models.dart';
import '../domain/stocktake_repository.dart';

/// Phiếu kiểm kê ĐẾM MÙ (đầu ca / cuối ca).
/// Màn này không bao giờ hiện số dự kiến, số tồn, số đếm lần trước, hay đúng/sai sau khi nhập.
/// Sau khi lưu, dòng chỉ còn "Đã đếm"; muốn sửa thì đếm lại từ ô trống.
class StocktakeScreen extends StatefulWidget {
  const StocktakeScreen(
      {super.key, required this.repository, required this.kind});

  final StocktakeRepository repository;
  final CountKind kind;

  @override
  State<StocktakeScreen> createState() => _StocktakeScreenState();
}

class _StocktakeScreenState extends State<StocktakeScreen> {
  late final StocktakeController _c =
      StocktakeController(widget.repository, widget.kind)..load();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final saved = await guarded(context, _c.saveAll);
    if (saved == null || !mounted) return;
    if (widget.kind == CountKind.close && _c.allDailyCounted) {
      showNotice(context, 'Đã lưu. Đã đếm đủ nguyên liệu cuối ca.');
    } else {
      showNotice(context, 'Đã lưu $saved dòng.');
    }
  }

  Future<bool> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thoát khi chưa lưu?'),
        content: Text(
            'Còn ${_c.pendingCount} dòng đã nhập nhưng chưa lưu. Thoát thì các số này sẽ mất.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Ở lại')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Thoát')),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) => PopScope(
          canPop: !_c.hasPending,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            if (await _confirmLeave() && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Column(
              children: [
                ScreenHeader(
                  title: 'Kiểm kê ${widget.kind.label.toLowerCase()}',
                  subtitle:
                      'Đo và nhập số thực tế còn lại. App không hiện số dự kiến.',
                ),
                Expanded(child: _body()),
                _saveBar(),
              ],
            ),
          ),
        ),
      );

  Widget _body() {
    if (_c.phase == LoadPhase.loading && _c.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_c.phase == LoadPhase.error) {
      return ErrorRetry(
          message: _c.failure?.userMessage ?? 'Không tải được phiếu kiểm kê.',
          onRetry: _c.load);
    }
    if (_c.items.isEmpty) {
      return const EmptyState(
        icon: 'assets/icons/package.svg',
        title: 'Chưa có nguyên liệu',
        message: 'Chủ quán cần thêm nguyên liệu trước khi kiểm kê.',
      );
    }
    final dailyItems = _c.dailyItems;
    final weeklyItems = _c.weeklyItems;
    final progress = _c.dailyTotal == 0 ? 1.0 : _c.dailyCounted / _c.dailyTotal;
    return RefreshIndicator(
      onRefresh: _c.load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: ForeCard(
                radius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text('Tiến độ',
                                style: AppTextStyles.bodyStrong)),
                        Text('Đã đếm ${_c.dailyCounted}/${_c.dailyTotal}',
                            style: AppTextStyles.captionStrong),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppColors.surfaceTint,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            sliver: SliverToBoxAdapter(
                child: Text('Cần đếm', style: AppTextStyles.headline)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _row(dailyItems[index]),
                childCount: dailyItems.length,
              ),
            ),
          ),
          if (weeklyItems.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Kiểm theo tuần', style: AppTextStyles.headline),
                    const SizedBox(height: 2),
                    Text('Không bắt buộc đếm lúc cuối ca.',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _row(weeklyItems[index]),
                  childCount: weeklyItems.length,
                ),
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  Widget _row(CountItem item) {
    final needs = _c.needsInput(item);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _CountRow(
        // Đổi khóa khi chuyển giữa "nhập" và "đã đếm" để ô nhập luôn trống, không giữ số cũ.
        key: ValueKey('${item.id}:$needs'),
        item: item,
        needsInput: needs,
        enabled: !_c.busy,
        onChanged: (v) => _c.setDraft(item.id, v),
        onRecount: () => _c.startRecount(item),
      ),
    );
  }

  Widget _saveBar() => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.cardBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: FilledButton(
              onPressed: _c.hasPending && !_c.busy ? _save : null,
              child: Text(_c.hasPending
                  ? 'Lưu ${_c.pendingCount} dòng'
                  : 'Nhập số để lưu'),
            ),
          ),
        ),
      );
}

class _CountRow extends StatefulWidget {
  const _CountRow({
    super.key,
    required this.item,
    required this.needsInput,
    required this.enabled,
    required this.onChanged,
    required this.onRecount,
  });

  final CountItem item;
  final bool needsInput;
  final bool enabled;
  final ValueChanged<int?> onChanged;
  final VoidCallback onRecount;

  @override
  State<_CountRow> createState() => _CountRowState();
}

class _CountRowState extends State<_CountRow> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ForeCard(
      radius: 18,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: AppFontSizes.s16,
                    fontWeight:
                        item.important ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                    item.important
                        ? 'Quan trọng · ${item.unitLabel}'
                        : item.unitLabel,
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: widget.needsInput
                ? TextField(
                    controller: _field,
                    enabled: widget.enabled,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(9)
                    ],
                    textAlign: TextAlign.end,
                    style: AppTextStyles.number,
                    onChanged: (t) => widget.onChanged(int.tryParse(t)),
                    decoration: InputDecoration(
                      hintText: '0',
                      suffixText: item.unitLabel,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const StatusChip(
                        label: 'Đã đếm',
                        severity: StatusSeverity.healthy,
                        compact: true,
                      ),
                      TextButton(
                          onPressed: widget.enabled ? widget.onRecount : null,
                          child: const Text('Đếm lại')),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
