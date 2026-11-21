import 'package:flutter/material.dart';

import '../../core/application/load_phase.dart';
import '../../core/design/colors.dart';
import '../../core/design/empty_state.dart';
import '../../core/design/error_state.dart';
import '../../core/design/spacing.dart';
import '../../core/design/status_pill.dart';
import '../../core/design/typography.dart';
import '../../core/errors/app_failure.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/status_chip.dart';
import '../admin_errors.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';
import 'admin_widgets.dart';

/// Màn hình IP đăng nhập theo người dùng (`admin_list_logins`).
class AdminLoginsScreen extends StatefulWidget {
  const AdminLoginsScreen({
    super.key,
    required this.repository,
    this.initialUserId,
    this.initialUserLabel,
    this.onClearInitialUser,
  });

  final AdminLoginsRepository repository;
  final String? initialUserId;
  final String? initialUserLabel;
  final VoidCallback? onClearInitialUser;

  @override
  State<AdminLoginsScreen> createState() => _AdminLoginsScreenState();
}

class _AdminLoginsScreenState extends State<AdminLoginsScreen> {
  static const _limits = [50, 100, 200];

  final _userIdController = TextEditingController();
  LoadPhase _phase = LoadPhase.loading;
  List<AdminLoginIp> _items = const [];
  String? _errorMessage;
  String? _appliedUserId;
  String? _appliedUserLabel;
  int _limit = 100;

  @override
  void initState() {
    super.initState();
    _appliedUserId = widget.initialUserId;
    _appliedUserLabel = widget.initialUserLabel;
    if (_appliedUserId != null) {
      _userIdController.text = _appliedUserId!;
    }
    _load();
  }

  @override
  void didUpdateWidget(covariant AdminLoginsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialUserId != oldWidget.initialUserId) {
      _appliedUserId = widget.initialUserId;
      _appliedUserLabel = widget.initialUserLabel;
      _userIdController.text = _appliedUserId ?? '';
      _load();
    }
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _phase = LoadPhase.loading;
      _errorMessage = null;
    });
    try {
      final rows = await widget.repository.listLogins(
        userId: _appliedUserId,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _items = rows;
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
        _errorMessage = 'Không thể tải lịch sử IP đăng nhập.';
        _phase = LoadPhase.error;
      });
    }
  }

  void _applyUserFilter() {
    final trimmed = _userIdController.text.trim();
    setState(() {
      _appliedUserId = trimmed.isEmpty ? null : trimmed;
      _appliedUserLabel = null;
    });
    _load();
  }

  void _clearFilter() {
    _userIdController.clear();
    setState(() {
      _appliedUserId = null;
      _appliedUserLabel = null;
    });
    widget.onClearInitialUser?.call();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        AdminPageHeader(
          title: 'IP đăng nhập',
          subtitle: 'Lịch sử IP và User-Agent ghi nhận từ PostgREST qua record_login().',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('logins_user_filter_field'),
                      controller: _userIdController,
                      onSubmitted: (_) => _applyUserFilter(),
                      decoration: InputDecoration(
                        hintText: 'Lọc theo user_id (UUID), để trống để xem tất cả...',
                        prefixIcon: const Icon(Icons.person_search_outlined),
                        suffixIcon: _userIdController.text.isEmpty &&
                                _appliedUserId == null
                            ? null
                            : IconButton(
                                key: const Key('logins_filter_clear'),
                                tooltip: 'Xem tất cả người dùng',
                                icon: const Icon(Icons.close_rounded),
                                onPressed: _clearFilter,
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppGaps.sm),
                  FilledButton(
                    key: const Key('logins_filter_submit'),
                    onPressed:
                        _phase == LoadPhase.loading ? null : _applyUserFilter,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(88, AppSizes.fieldHeight),
                    ),
                    child: const Text('Lọc'),
                  ),
                ],
              ),
              const SizedBox(height: AppGaps.sm),
              Wrap(
                spacing: AppGaps.sm,
                runSpacing: AppGaps.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Giới hạn dòng:', style: AppTextStyles.captionStrong),
                  for (final limit in _limits)
                    ChoiceChip(
                      label: Text('$limit'),
                      selected: _limit == limit,
                      onSelected: (_) {
                        setState(() => _limit = limit);
                        _load();
                      },
                    ),
                  if (_appliedUserId != null)
                    StatusPill(
                      label:
                          'Đang lọc: ${_appliedUserLabel ?? _appliedUserId!}',
                      severity: StatusSeverity.neutral,
                      compact: true,
                    ),
                ],
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
          icon: Icons.router_outlined,
          title: 'Chưa có lịch sử IP đăng nhập',
          message: _appliedUserId == null
              ? 'Chưa có phiên đăng nhập nào được ghi nhận trong login_ips.'
              : 'Không có lịch sử đăng nhập nào cho user_id "$_appliedUserId".',
          actionLabel: _appliedUserId == null ? 'Tải lại' : 'Xem tất cả',
          onAction: _appliedUserId == null ? _load : _clearFilter,
        ),
      );
    }

    return ForeCard(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      elevated: false,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Thời gian')),
            DataColumn(label: Text('Người dùng')),
            DataColumn(label: Text('Địa chỉ IP')),
            DataColumn(label: Text('User-Agent')),
          ],
          rows: [
            for (final item in _items)
              DataRow(cells: [
                DataCell(Text(formatAdminDateTime(item.createdAt))),
                DataCell(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.userEmail ?? '(Không có email)',
                        style: AppTextStyles.bodyStrong,
                      ),
                      Text(
                        item.userId,
                        style: AppTextStyles.caption.copyWith(
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  AdminCodeBadge(text: item.ip ?? 'Không xác định'),
                ),
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Tooltip(
                      message: item.userAgent ?? 'Không có User-Agent',
                      child: Text(
                        item.userAgent ?? 'Không có',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
