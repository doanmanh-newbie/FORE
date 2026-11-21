import 'package:flutter/material.dart';

import '../../core/application/load_phase.dart';
import '../../core/design/colors.dart';
import '../../core/design/empty_state.dart';
import '../../core/design/error_state.dart';
import '../../core/design/spacing.dart';
import '../../core/design/typography.dart';
import '../../core/errors/app_failure.dart';
import '../../core/format.dart';
import '../../core/widgets/fore_card.dart';
import '../admin_errors.dart';
import '../admin_theme.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';
import 'admin_widgets.dart';

/// Màn hình Thống kê sự kiện theo khoảng ngày (`admin_event_counts`).
/// Biểu đồ cột được vẽ trực tiếp bằng Flutter, không cần thêm thư viện ngoài.
class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({
    super.key,
    required this.repository,
    this.initialDays = 7,
  });

  final AdminEventsRepository repository;
  final int initialDays;

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  static const _presets = [7, 14, 30, 90];

  late DateTime _fromDate;
  late DateTime _toDateInclusive;
  int? _selectedPreset;

  LoadPhase _phase = LoadPhase.loading;
  List<AdminEventCount> _rows = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _applyPreset(widget.initialDays, triggerLoad: false);
    _load();
  }

  void _applyPreset(int days, {bool triggerLoad = true}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _toDateInclusive = today;
    _fromDate = today.subtract(Duration(days: days - 1));
    _selectedPreset = days;
    if (triggerLoad) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _phase = LoadPhase.loading;
      _errorMessage = null;
    });
    final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
    final toExclusive = DateTime(
      _toDateInclusive.year,
      _toDateInclusive.month,
      _toDateInclusive.day,
    ).add(const Duration(days: 1));

    try {
      final rows = await widget.repository.fetchEventCounts(
        from: from,
        to: toExclusive,
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _phase = LoadPhase.ready;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _errorMessage = adminFailureMessage(failure);
        _phase = LoadPhase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải thống kê sự kiện.';
        _phase = LoadPhase.error;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _fromDate : _toDateInclusive;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedPreset = null;
      if (isStart) {
        _fromDate = DateTime(picked.year, picked.month, picked.day);
        if (_fromDate.isAfter(_toDateInclusive)) {
          _toDateInclusive = _fromDate;
        }
      } else {
        _toDateInclusive = DateTime(picked.year, picked.month, picked.day);
        if (_toDateInclusive.isBefore(_fromDate)) {
          _fromDate = _toDateInclusive;
        }
      }
    });
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        AdminPageHeader(
          title: 'Thống kê sự kiện',
          subtitle: 'Tổng hợp lượt sử dụng ứng dụng theo ngày (giờ Việt Nam) và tên sự kiện.',
          trailing: OutlinedButton.icon(
            onPressed: _phase == LoadPhase.loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Làm mới'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        ForeCard(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          elevated: false,
          child: Wrap(
            spacing: AppGaps.sm,
            runSpacing: AppGaps.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final days in _presets)
                ChoiceChip(
                  key: Key('events_preset_$days'),
                  label: Text('$days ngày'),
                  selected: _selectedPreset == days,
                  onSelected: (_) => _applyPreset(days),
                ),
              const SizedBox(width: AppGaps.sm),
              OutlinedButton.icon(
                key: const Key('events_from_date'),
                onPressed: () => _pickDate(isStart: true),
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text('Từ: ${formatAdminDate(_fromDate)}'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
              OutlinedButton.icon(
                key: const Key('events_to_date'),
                onPressed: () => _pickDate(isStart: false),
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text('Đến: ${formatAdminDate(_toDateInclusive)}'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        switch (_phase) {
          LoadPhase.loading => const AdminLoadingList(),
          LoadPhase.error => ForeCard(
              elevated: false,
              child: ErrorState(
                message: _errorMessage ?? 'Đã có lỗi xảy ra.',
                onRetry: _load,
              ),
            ),
          LoadPhase.ready => _buildBody(),
        },
      ],
    );
  }

  Widget _buildBody() {
    if (_rows.isEmpty) {
      return ForeCard(
        elevated: false,
        child: EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'Không có sự kiện trong khoảng ngày này',
          message:
              'Chưa có dữ liệu log_event từ ${formatAdminDate(_fromDate)} đến ${formatAdminDate(_toDateInclusive)}.',
          actionLabel: 'Tải lại',
          onAction: _load,
        ),
      );
    }

    final totalEvents = _rows.fold<int>(0, (sum, r) => sum + r.eventCount);
    final byDay = <DateTime, int>{};
    final byName = <String, int>{};
    for (final row in _rows) {
      final dayKey = DateTime(row.day.year, row.day.month, row.day.day);
      byDay[dayKey] = (byDay[dayKey] ?? 0) + row.eventCount;
      byName[row.name] = (byName[row.name] ?? 0) + row.eventCount;
    }

    final sortedDays = byDay.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedNames = byName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSizes.cardGap,
          runSpacing: AppSizes.cardGap,
          children: [
            AdminMetricCard(
              icon: Icons.bolt_rounded,
              label: 'Tổng lượt sự kiện',
              value: formatThousands(totalEvents),
            ),
            AdminMetricCard(
              icon: Icons.category_outlined,
              label: 'Loại sự kiện',
              value: formatThousands(sortedNames.length),
            ),
            AdminMetricCard(
              icon: Icons.date_range_outlined,
              label: 'Số ngày có dữ liệu',
              value: formatThousands(sortedDays.length),
              accentColor: AppColors.statusHealthy,
            ),
          ],
        ),
        const SizedBox(height: AppGaps.lg),
        ForeCard(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Biểu đồ lượt sự kiện theo ngày',
                  style: AppTextStyles.sectionHeading),
              const SizedBox(height: AppGaps.md),
              _DailyBarChart(entries: sortedDays),
            ],
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        ForeCard(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Phân bổ theo tên sự kiện',
                  style: AppTextStyles.sectionHeading),
              const SizedBox(height: AppGaps.md),
              for (final entry in sortedNames) ...[
                _EventNameBar(
                  name: entry.key,
                  count: entry.value,
                  maxCount: sortedNames.first.value,
                ),
                const SizedBox(height: AppGaps.sm),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        ForeCard(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bảng chi tiết theo ngày', style: AppTextStyles.sectionHeading),
              const SizedBox(height: AppGaps.md),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Ngày')),
                    DataColumn(label: Text('Sự kiện')),
                    DataColumn(label: Text('Lượt gọi'), numeric: true),
                    DataColumn(label: Text('Người dùng'), numeric: true),
                  ],
                  rows: [
                    for (final row in _rows)
                      DataRow(cells: [
                        DataCell(Text(formatAdminDate(row.day))),
                        DataCell(AdminCodeBadge(text: row.name)),
                        DataCell(Text(formatThousands(row.eventCount))),
                        DataCell(Text(formatThousands(row.userCount))),
                      ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DailyBarChart extends StatelessWidget {
  const _DailyBarChart({required this.entries});

  final List<MapEntry<DateTime, int>> entries;

  @override
  Widget build(BuildContext context) {
    final maxValue = entries.fold<int>(
      1,
      (max, e) => e.value > max ? e.value : max,
    );

    return SizedBox(
      height: 196,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(right: AppGaps.md),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        formatThousands(entry.value),
                        style: AppTextStyles.captionStrong,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: (entry.value / maxValue) * 124 + 8,
                        width: 28,
                        decoration: const BoxDecoration(
                          color: AdminPalette.forestTeal,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${entry.key.day.toString().padLeft(2, '0')}/${entry.key.month.toString().padLeft(2, '0')}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventNameBar extends StatelessWidget {
  const _EventNameBar({
    required this.name,
    required this.count,
    required this.maxCount,
  });

  final String name;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount <= 0 ? 0.0 : (count / maxCount).clamp(0.05, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AdminCodeBadge(text: name),
            Text(
              '${formatThousands(count)} lượt',
              style: AppTextStyles.bodyStrong,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: AppColors.tint,
            valueColor: const AlwaysStoppedAnimation<Color>(
              AdminPalette.logoTeal,
            ),
          ),
        ),
      ],
    );
  }
}
