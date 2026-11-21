import 'package:flutter/material.dart';

import '../../core/application/load_phase.dart';
import '../../core/design/colors.dart';
import '../../core/design/empty_state.dart';
import '../../core/design/error_state.dart';
import '../../core/design/spacing.dart';
import '../../core/design/status_pill.dart';
import '../../core/design/typography.dart';
import '../../core/errors/app_failure.dart';
import '../../core/format.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/status_chip.dart';
import '../admin_errors.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';
import 'admin_widgets.dart';

/// Màn hình Người dùng (`admin_list_users`) có tìm kiếm & phân trang server-side.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({
    super.key,
    required this.repository,
    this.pageSize = 20,
    this.onInspectLogins,
  });

  final AdminUsersRepository repository;
  final int pageSize;
  final ValueChanged<AdminUser>? onInspectLogins;

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();

  LoadPhase _phase = LoadPhase.loading;
  AdminUserPage? _page;
  String? _errorMessage;
  String _appliedSearch = '';
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? offset}) async {
    final targetOffset = offset ?? _offset;
    setState(() {
      _phase = LoadPhase.loading;
      _errorMessage = null;
      _offset = targetOffset;
    });
    try {
      final result = await widget.repository.listUsers(
        search: _appliedSearch.isEmpty ? null : _appliedSearch,
        limit: widget.pageSize,
        offset: targetOffset,
      );
      if (!mounted) return;
      setState(() {
        _page = result;
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
        _errorMessage = 'Không thể tải danh sách người dùng.';
        _phase = LoadPhase.error;
      });
    }
  }

  void _applySearch() {
    _appliedSearch = _searchController.text.trim();
    _load(offset: 0);
  }

  void _clearSearch() {
    _searchController.clear();
    _appliedSearch = '';
    _load(offset: 0);
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        AdminPageHeader(
          title: 'Người dùng',
          subtitle: 'Tìm theo email, số điện thoại hoặc họ tên và xem lịch sử đăng nhập.',
          trailing: OutlinedButton.icon(
            onPressed: _phase == LoadPhase.loading ? null : () => _load(),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Làm mới'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('users_search_field'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _applySearch(),
                decoration: InputDecoration(
                  hintText: 'Tìm theo email, số điện thoại hoặc tên...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isEmpty &&
                          _appliedSearch.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('users_search_clear'),
                          tooltip: 'Xóa tìm kiếm',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _clearSearch,
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppGaps.sm),
            FilledButton(
              key: const Key('users_search_submit'),
              onPressed: _phase == LoadPhase.loading ? null : _applySearch,
              style: FilledButton.styleFrom(
                minimumSize: const Size(96, AppSizes.fieldHeight),
              ),
              child: const Text('Tìm'),
            ),
          ],
        ),
        const SizedBox(height: AppGaps.lg),
        switch (_phase) {
          LoadPhase.loading => const AdminLoadingList(),
          LoadPhase.error => ForeCard(
              elevated: false,
              child: ErrorState(
                message: _errorMessage ?? 'Đã có lỗi xảy ra.',
                onRetry: () => _load(),
              ),
            ),
          LoadPhase.ready => _buildResults(page!),
        },
      ],
    );
  }

  Widget _buildResults(AdminUserPage page) {
    if (page.items.isEmpty) {
      return ForeCard(
        elevated: false,
        child: EmptyState(
          icon: Icons.people_outline_rounded,
          title: _appliedSearch.isEmpty
              ? 'Chưa có người dùng nào'
              : 'Không tìm thấy người dùng',
          message: _appliedSearch.isEmpty
              ? 'Hệ thống chưa ghi nhận tài khoản nào.'
              : 'Không có tài khoản nào khớp với "$_appliedSearch".',
          actionLabel: _appliedSearch.isEmpty ? 'Tải lại' : 'Xóa tìm kiếm',
          onAction: _appliedSearch.isEmpty ? () => _load() : _clearSearch,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppGaps.sm),
          child: Text(
            'Hiển thị ${page.items.length} / ${formatThousands(page.totalCount)} người dùng · Trang ${page.currentPage}/${page.totalPages}',
            style: AppTextStyles.captionStrong,
          ),
        ),
        for (var i = 0; i < page.items.length; i++) ...[
          _UserCard(
            user: page.items[i],
            onInspectLogins: widget.onInspectLogins,
          ),
          if (i < page.items.length - 1)
            const SizedBox(height: AppSizes.cardGap),
        ],
        const SizedBox(height: AppGaps.lg),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              key: const Key('users_prev_page'),
              onPressed: page.hasPrevious
                  ? () => _load(
                        offset: (page.offset - widget.pageSize)
                            .clamp(0, page.totalCount),
                      )
                  : null,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Trang trước'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
            const SizedBox(width: AppGaps.sm),
            OutlinedButton.icon(
              key: const Key('users_next_page'),
              onPressed: page.hasNext
                  ? () => _load(offset: page.offset + widget.pageSize)
                  : null,
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Trang sau'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    this.onInspectLogins,
  });

  final AdminUser user;
  final ValueChanged<AdminUser>? onInspectLogins;

  @override
  Widget build(BuildContext context) {
    return ForeCard(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      elevated: false,
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
                  Text(user.displayName, style: AppTextStyles.title),
                  if (user.isPlatformAdmin) ...[
                    const SizedBox(width: AppGaps.sm),
                    const StatusPill(
                      label: 'Super-admin',
                      severity: StatusSeverity.healthy,
                      compact: true,
                    ),
                  ],
                ],
              ),
              if (onInspectLogins != null)
                TextButton.icon(
                  key: Key('inspect_logins_${user.userId}'),
                  onPressed: () => onInspectLogins!(user),
                  icon: const Icon(Icons.router_outlined, size: 18),
                  label: const Text('Xem IP'),
                  style: TextButton.styleFrom(minimumSize: const Size(0, 36)),
                ),
            ],
          ),
          const SizedBox(height: AppGaps.xs),
          Wrap(
            spacing: AppGaps.lg,
            runSpacing: AppGaps.xs,
            children: [
              if (user.email != null && user.email!.isNotEmpty)
                Text('Email: ${user.email}', style: AppTextStyles.body),
              if (user.phone != null && user.phone!.isNotEmpty)
                Text('SĐT: ${user.phone}', style: AppTextStyles.body),
              Text(
                'Quán: ${user.shopCount == 0 ? 'Chưa thuộc quán nào' : '${user.shopCount} (${user.shopNames ?? ''})'}',
                style: AppTextStyles.body,
              ),
              Text(
                'Đăng nhập gần nhất: ${formatAdminDateTime(user.lastLoginAt, empty: 'Chưa ghi nhận')}',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: AppGaps.xs),
          SelectableText(
            'ID: ${user.userId}',
            style: AppTextStyles.caption.copyWith(
              fontFamily: 'monospace',
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
