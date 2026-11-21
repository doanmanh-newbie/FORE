import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/application/load_phase.dart';
import '../../core/design/colors.dart';
import '../../core/design/empty_state.dart';
import '../../core/design/error_state.dart';
import '../../core/design/spacing.dart';
import '../../core/design/status_pill.dart';
import '../../core/design/typography.dart';
import '../../core/errors/app_failure.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/notify.dart';
import '../../core/widgets/status_chip.dart';
import '../admin_errors.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';
import 'admin_widgets.dart';

/// Màn hình Nhật ký lỗi (`admin_list_errors`) có xem chi tiết stack & tải thêm theo `p_before`.
class AdminErrorsScreen extends StatefulWidget {
  const AdminErrorsScreen({
    super.key,
    required this.repository,
    this.pageSize = 30,
  });

  final AdminErrorsRepository repository;
  final int pageSize;

  @override
  State<AdminErrorsScreen> createState() => _AdminErrorsScreenState();
}

class _AdminErrorsScreenState extends State<AdminErrorsScreen> {
  LoadPhase _phase = LoadPhase.loading;
  List<AdminErrorLog> _items = const [];
  String? _errorMessage;
  bool _loadingMore = false;
  bool _hasMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _phase = LoadPhase.loading;
      _errorMessage = null;
      _hasMore = false;
    });
    try {
      final rows = await widget.repository.listErrors(limit: widget.pageSize);
      if (!mounted) return;
      setState(() {
        _items = rows;
        _hasMore = rows.length >= widget.pageSize;
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
        _errorMessage = 'Không thể tải nhật ký lỗi.';
        _phase = LoadPhase.error;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _items.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final older = await widget.repository.listErrors(
        limit: widget.pageSize,
        before: _items.last.createdAt,
      );
      if (!mounted) return;
      final existingIds = _items.map((e) => e.id).toSet();
      final merged = [
        ..._items,
        for (final item in older)
          if (!existingIds.contains(item.id)) item,
      ];
      setState(() {
        _items = merged;
        _hasMore = older.length >= widget.pageSize;
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showNotice(context, adminFailureMessage(failure));
    } catch (_) {
      if (!mounted) return;
      showNotice(context, 'Không thể tải thêm lỗi cũ hơn.');
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  Future<void> _showDetail(AdminErrorLog item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final stackText = (item.stack == null || item.stack!.trim().isEmpty)
            ? '(Không có stack trace)'
            : item.stack!;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.bug_report_outlined, color: AppColors.statusCritical),
              const SizedBox(width: AppGaps.sm),
              Expanded(child: Text('Chi tiết lỗi #${item.id}')),
            ],
          ),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Thông điệp lỗi', style: AppTextStyles.label),
                  const SizedBox(height: AppGaps.xs),
                  SelectableText(
                    item.message,
                    style: AppTextStyles.bodyStrong.copyWith(
                      color: AppColors.statusCritical,
                    ),
                  ),
                  const SizedBox(height: AppGaps.md),
                  Wrap(
                    spacing: AppGaps.lg,
                    runSpacing: AppGaps.xs,
                    children: [
                      Text(
                        'Thời gian: ${formatAdminDateTime(item.createdAt)}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Nền tảng: ${item.platform ?? 'Không rõ'}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Phiên bản: ${item.appVersion ?? 'Không rõ'}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Người dùng: ${item.userEmail ?? item.userId ?? 'Ẩn danh'}',
                        style: AppTextStyles.caption,
                      ),
                      Text(
                        'Quán: ${item.shopName ?? item.shopId ?? 'Không có'}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppGaps.lg),
                  Text('Stack trace', style: AppTextStyles.label),
                  const SizedBox(height: AppGaps.xs),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppGaps.md),
                    decoration: BoxDecoration(
                      color: AppColors.tint,
                      borderRadius: BorderRadius.circular(AppRadius.field),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: SelectableText(
                      stackText,
                      key: const Key('error_detail_stack'),
                      style: AppTextStyles.caption.copyWith(
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (item.context != null) ...[
                    const SizedBox(height: AppGaps.lg),
                    Text('Context (JSON)', style: AppTextStyles.label),
                    const SizedBox(height: AppGaps.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppGaps.md),
                      decoration: BoxDecoration(
                        color: AppColors.tint,
                        borderRadius: BorderRadius.circular(AppRadius.field),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: SelectableText(
                        formatPrettyJson(item.context),
                        style: AppTextStyles.caption.copyWith(
                          fontFamily: 'monospace',
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (item.stack != null && item.stack!.trim().isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: item.stack!));
                  if (dialogContext.mounted) {
                    showNotice(dialogContext, 'Đã sao chép stack trace.');
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Sao chép stack'),
              ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: FilledButton.styleFrom(minimumSize: const Size(88, 42)),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        AdminPageHeader(
          title: 'Nhật ký lỗi',
          subtitle: 'Các lỗi được ứng dụng gửi về qua log_error. Nhấn vào từng dòng để xem stack trace.',
          trailing: OutlinedButton.icon(
            onPressed: _phase == LoadPhase.loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Làm mới'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
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
          LoadPhase.ready => _buildList(),
        },
      ],
    );
  }

  Widget _buildList() {
    if (_items.isEmpty) {
      return ForeCard(
        elevated: false,
        child: EmptyState(
          icon: Icons.verified_outlined,
          title: 'Chưa ghi nhận lỗi nào',
          message: 'Ứng dụng chưa gửi lỗi nào lên bảng error_logs.',
          actionLabel: 'Tải lại',
          onAction: _load,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          _ErrorLogCard(
            item: _items[i],
            onTap: () => _showDetail(_items[i]),
          ),
          if (i < _items.length - 1) const SizedBox(height: AppSizes.cardGap),
        ],
        if (_hasMore) ...[
          const SizedBox(height: AppGaps.lg),
          Center(
            child: OutlinedButton.icon(
              key: const Key('errors_load_more'),
              onPressed: _loadingMore ? null : _loadMore,
              icon: _loadingMore
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_rounded),
              label: Text(_loadingMore ? 'Đang tải...' : 'Tải thêm lỗi cũ hơn'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(200, 44)),
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorLogCard extends StatelessWidget {
  const _ErrorLogCard({
    required this.item,
    required this.onTap,
  });

  final AdminErrorLog item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ForeCard(
      key: Key('error_row_${item.id}'),
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      elevated: false,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppGaps.sm,
            runSpacing: AppGaps.xs,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(
                    label: item.platform ?? 'unknown',
                    severity: StatusSeverity.critical,
                    compact: true,
                  ),
                  if (item.appVersion != null &&
                      item.appVersion!.isNotEmpty) ...[
                    const SizedBox(width: AppGaps.sm),
                    AdminCodeBadge(text: 'v${item.appVersion!}'),
                  ],
                  const SizedBox(width: AppGaps.sm),
                  Text('#${item.id}', style: AppTextStyles.caption),
                ],
              ),
              Text(
                formatAdminDateTime(item.createdAt),
                style: AppTextStyles.captionStrong,
              ),
            ],
          ),
          const SizedBox(height: AppGaps.sm),
          Text(
            item.message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyStrong,
          ),
          const SizedBox(height: AppGaps.xs),
          Wrap(
            spacing: AppGaps.lg,
            runSpacing: AppGaps.xs,
            children: [
              Text(
                'Người dùng: ${item.userEmail ?? item.userId ?? 'Ẩn danh'}',
                style: AppTextStyles.caption,
              ),
              if (item.shopName != null && item.shopName!.isNotEmpty)
                Text('Quán: ${item.shopName}', style: AppTextStyles.caption),
              Text(
                item.stack != null && item.stack!.trim().isNotEmpty
                    ? 'Nhấn để xem stack trace'
                    : 'Nhấn để xem chi tiết',
                style: AppTextStyles.captionStrong.copyWith(
                  color: AppColors.brandAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
