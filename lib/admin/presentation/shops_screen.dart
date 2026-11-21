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

/// Màn hình Danh sách quán (`admin_list_shops`).
class AdminShopsScreen extends StatefulWidget {
  const AdminShopsScreen({
    super.key,
    required this.repository,
  });

  final AdminShopsRepository repository;

  @override
  State<AdminShopsScreen> createState() => _AdminShopsScreenState();
}

class _AdminShopsScreenState extends State<AdminShopsScreen> {
  LoadPhase _phase = LoadPhase.loading;
  List<AdminShop> _shops = const [];
  String? _errorMessage;
  String _filter = '';
  final _searchController = TextEditingController();

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

  Future<void> _load() async {
    setState(() {
      _phase = LoadPhase.loading;
      _errorMessage = null;
    });
    try {
      final rows = await widget.repository.listShops();
      if (!mounted) return;
      setState(() {
        _shops = rows;
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
        _errorMessage = 'Không thể tải danh sách quán.';
        _phase = LoadPhase.error;
      });
    }
  }

  List<AdminShop> get _filteredShops {
    final q = _filter.trim().toLowerCase();
    if (q.isEmpty) return _shops;
    return _shops.where((shop) {
      return shop.name.toLowerCase().contains(q) ||
          (shop.code ?? '').toLowerCase().contains(q) ||
          (shop.ownerName ?? '').toLowerCase().contains(q) ||
          (shop.ownerEmail ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final totalMembers =
        _shops.fold<int>(0, (sum, shop) => sum + shop.memberCount);
    final activeShops = _shops.where((s) => s.lastBillAt != null).length;

    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        AdminPageHeader(
          title: 'Danh sách quán',
          subtitle: 'Theo dõi các quán đang vận hành trên nền tảng Fore.',
          trailing: OutlinedButton.icon(
            onPressed: _phase == LoadPhase.loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Làm mới'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        if (_phase == LoadPhase.ready && _shops.isNotEmpty) ...[
          Wrap(
            spacing: AppSizes.cardGap,
            runSpacing: AppSizes.cardGap,
            children: [
              AdminMetricCard(
                icon: Icons.storefront_outlined,
                label: 'Tổng số quán',
                value: formatThousands(_shops.length),
              ),
              AdminMetricCard(
                icon: Icons.groups_outlined,
                label: 'Tổng thành viên hoạt động',
                value: formatThousands(totalMembers),
              ),
              AdminMetricCard(
                icon: Icons.receipt_long_outlined,
                label: 'Quán đã phát sinh hóa đơn',
                value: formatThousands(activeShops),
                accentColor: AppColors.statusHealthy,
              ),
            ],
          ),
          const SizedBox(height: AppGaps.lg),
          TextField(
            key: const Key('shops_filter_field'),
            controller: _searchController,
            onChanged: (value) => setState(() => _filter = value),
            decoration: InputDecoration(
              hintText: 'Lọc theo tên quán, mã quán, tên hoặc email chủ quán...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _filter.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa từ khóa',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _filter = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: AppGaps.lg),
        ],
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
    if (_shops.isEmpty) {
      return ForeCard(
        elevated: false,
        child: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Chưa có quán nào',
          message: 'Khi có chủ quán tạo quán mới trên ứng dụng, danh sách sẽ hiện tại đây.',
          actionLabel: 'Tải lại',
          onAction: _load,
        ),
      );
    }

    final visible = _filteredShops;
    if (visible.isEmpty) {
      return ForeCard(
        elevated: false,
        child: EmptyState(
          icon: Icons.search_off_rounded,
          title: 'Không tìm thấy quán phù hợp',
          message: 'Không có quán nào khớp với từ khóa "$_filter".',
          actionLabel: 'Xóa bộ lọc',
          onAction: () {
            _searchController.clear();
            setState(() => _filter = '');
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < visible.length; i++) ...[
          _ShopTile(shop: visible[i]),
          if (i < visible.length - 1) const SizedBox(height: AppSizes.cardGap),
        ],
      ],
    );
  }
}

class _ShopTile extends StatelessWidget {
  const _ShopTile({required this.shop});

  final AdminShop shop;

  @override
  Widget build(BuildContext context) {
    final ownerLabel = [
      if (shop.ownerName != null && shop.ownerName!.isNotEmpty) shop.ownerName!,
      if (shop.ownerEmail != null && shop.ownerEmail!.isNotEmpty)
        shop.ownerEmail!,
    ].join(' · ');

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
                  Text(shop.name, style: AppTextStyles.title),
                  if (shop.code != null && shop.code!.isNotEmpty) ...[
                    const SizedBox(width: AppGaps.sm),
                    AdminCodeBadge(text: shop.code!),
                  ],
                ],
              ),
              StatusPill(
                label: '${formatThousands(shop.memberCount)} thành viên',
                severity: shop.memberCount > 0
                    ? StatusSeverity.healthy
                    : StatusSeverity.neutral,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: AppGaps.sm),
          Wrap(
            spacing: AppGaps.lg,
            runSpacing: AppGaps.xs,
            children: [
              _MetaItem(
                icon: Icons.person_outline_rounded,
                label: 'Chủ quán',
                value: ownerLabel.isEmpty ? 'Chưa xác định' : ownerLabel,
              ),
              _MetaItem(
                icon: Icons.calendar_today_outlined,
                label: 'Ngày tạo',
                value: formatAdminDateTime(shop.createdAt),
              ),
              _MetaItem(
                icon: Icons.receipt_outlined,
                label: 'Đơn gần nhất',
                value: formatAdminDateTime(
                  shop.lastBillAt,
                  empty: 'Chưa có đơn',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textSecondary),
        const SizedBox(width: 5),
        Text('$label: ', style: AppTextStyles.caption),
        Text(value, style: AppTextStyles.captionStrong.copyWith(color: AppColors.textPrimary)),
      ],
    );
  }
}
