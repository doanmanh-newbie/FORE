import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../shift/operations/application/ops_shift_controller.dart';
import '../../stocktake/domain/stocktake_models.dart';
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';
import 'purchase_screens.dart';
import 'stocktake_screens.dart';
import 'waste_screens.dart';

/// Tab Kho của nhân viên trong ca: việc cần làm, KHÔNG có số tồn hay giá (đếm mù).
/// Giữ nguyên hai lối đếm mở ca / đóng ca của luồng đối soát.
class StaffKhoHome extends StatefulWidget {
  const StaffKhoHome({
    super.key,
    required this.shift,
    required this.onCount,
  });

  final OpsShiftController shift;
  final void Function(CountKind kind) onCount;

  @override
  State<StaffKhoHome> createState() => _StaffKhoHomeState();
}

class _StaffKhoHomeState extends State<StaffKhoHome> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<StaffInventoryHomeData> _data =
      AsyncData(_repo.staffHome)..load();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _go(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _data.load(silent: true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final d = _data.data;
          final k = d?.stocktake;
          return RefreshIndicator(
            onRefresh: () => _data.load(silent: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  AppSizes.pageTopPadding,
                  AppSizes.pagePadding,
                  AppSizes.pageBottomPadding),
              children: [
                Text('Kho trong ca', style: AppTextStyles.pageTitle),
                const SizedBox(height: 2),
                Text(
                  d == null
                      ? 'Việc kho của bạn hôm nay'
                      : '${shiftLabel(d.shiftOpenedAt)}${d.shiftOpenedAt == null ? '' : ' · từ ${formatHm(d.shiftOpenedAt!)}'}'
                          ' · ${d.staffName}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                if (d == null && _data.failure != null)
                  KhoNote(_data.failure!.userMessage,
                      icon: Icons.cloud_off_outlined),
                if (d?.hint != null) ...[
                  KhoNote(
                    'Dùng lô ${d!.hint!.lotCode} (${d.hint!.ingredientName}) trước'
                    '${d.hint!.expiry == null ? '' : ' · HSD ${formatShortDate(d.hint!.expiry!)}'}',
                    icon: Icons.event_available_outlined,
                  ),
                  const SizedBox(height: 12),
                ],
                _ActionTile(
                  icon: Icons.local_shipping_outlined,
                  title: 'Nhập hàng nhanh',
                  subtitle: 'Ghi đúng lượng nhận. Giá do chủ bổ sung sau',
                  onTap: () => _go(const PoFormScreen(isOwner: false)),
                ),
                _ActionTile(
                  icon: Icons.fact_check_outlined,
                  title: switch (k?.status) {
                    StocktakeStatus.draft => 'Tiếp tục kiểm kê · ${k!.counted}/${k.total}',
                    StocktakeStatus.recount => 'Đếm lại theo yêu cầu của chủ',
                    _ => 'Kiểm kê trong ca',
                  },
                  subtitle: switch (k?.status) {
                    StocktakeStatus.submitted =>
                      '${k!.code} đã gửi, chờ chủ duyệt. Có thể đếm đợt mới',
                    StocktakeStatus.approved => '${k!.code} đã được duyệt. Có thể đếm đợt mới',
                    StocktakeStatus.recount => k!.reviewNote ?? 'Một vài dòng cần đếm lại',
                    StocktakeStatus.draft => 'Nháp ${k!.code} còn nguyên',
                    _ => 'Đếm mù, không hiện số hệ thống',
                  },
                  highlight: k?.status == StocktakeStatus.recount,
                  onTap: () => _go(const CountScreen()),
                ),
                _ActionTile(
                  icon: Icons.delete_outline_rounded,
                  title: 'Ghi hao hụt',
                  subtitle: 'Hết hạn, đổ vỡ, căn chỉnh máy…',
                  onTap: () => _go(const WasteEntryScreen()),
                ),
                const KhoSectionTitle('Đếm kho theo ca'),
                _ActionTile(
                  icon: Icons.wb_sunny_outlined,
                  title: 'Đếm kho đầu ca',
                  subtitle: 'Làm khi vừa mở ca',
                  onTap: () => widget.onCount(CountKind.open),
                ),
                _ActionTile(
                  icon: Icons.nightlight_outlined,
                  title: 'Đếm kho cuối ca',
                  subtitle: 'Làm trước khi đóng ca',
                  onTap: () => widget.onCount(CountKind.close),
                ),
              ],
            ),
          );
        },
      );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: KhoCard(
          onTap: onTap,
          child: Row(children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: highlight ? AppColors.statusAttentionTint : AppColors.tint,
                borderRadius: BorderRadius.circular(AppSizes.radiusTile),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(icon,
                    color: highlight ? AppColors.statusAttention : AppColors.brand),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.cardTitle),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ]),
        ),
      );
}
