import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/hero_card.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/widgets/notify.dart';
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'ingredient_screens.dart';
import 'kho_widgets.dart';
import 'purchase_screens.dart';
import 'shop_compare_sheet.dart';
import 'stocktake_screens.dart';
import 'supplier_screens.dart';
import 'waste_screens.dart';
import 'week_review_screen.dart';

/// Tab Kho của chủ quán: "Một vòng quanh kho" — tiền nằm trong kho, việc cần ưu tiên, lối vào
/// nguyên liệu / nhà cung cấp / phiếu nhập / kiểm kê / hao hụt / tuần nhìn lại.
class OwnerKhoHome extends StatefulWidget {
  const OwnerKhoHome({super.key, required this.header, this.footer});

  /// Thanh đầu trang chung của chủ quán (tên quán, chuông thông báo).
  final Widget header;
  /// Khối thao tác cũ (Ghi hao hụt trong ca, Thu / chi) đặt dưới cùng.
  final Widget? footer;

  @override
  State<OwnerKhoHome> createState() => _OwnerKhoHomeState();
}

class _OwnerKhoHomeState extends State<OwnerKhoHome> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<InvOverview> _data = AsyncData(_repo.overview)..load();

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
          final o = _data.data;
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
                widget.header,
                const SizedBox(height: 12),
                Text('Kho', style: AppTextStyles.pageTitle),
                const SizedBox(height: 2),
                Text(
                  o == null
                      ? 'Một vòng quanh kho'
                      : 'Cập nhật ${formatHm(o.updatedAt)} · ${formatDmy(o.updatedAt)}',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                if (o == null && _data.failure != null)
                  KhoNote(_data.failure!.userMessage,
                      icon: Icons.cloud_off_outlined)
                else if (o == null)
                  const SizedBox(height: 240, child: KhoSkeleton())
                else
                  ..._content(o),
                if (widget.footer != null) ...[
                  const SizedBox(height: 16),
                  widget.footer!,
                ],
              ],
            ),
          );
        },
      );

  List<Widget> _content(InvOverview o) {
    final low = o.lowItems;
    final soonest = low.isEmpty ? null : low.first;
    return [
      HeroCard(
        title: 'Tiền đang ở trong kho',
        primaryLabel: o.suggestionCount > 0
            ? 'Xem gợi ý nhập · ${o.suggestionCount}'
            : 'Nhập hàng mới',
        onPrimary: () => _go(o.suggestionCount > 0
            ? const SuggestionsScreen()
            : const PoFormScreen(isOwner: true)),
        secondaryLabel: 'Đổi quán đang xem',
        onSecondary: () => showShopCompareSheet(context),
        child: BigFigure(
          label: 'Giá trị tồn',
          value: formatVnd(o.stockValue),
          caption: _valueCaption(o),
          dark: true,
        ),
      ),
      const SizedBox(height: 16),
      const KhoSectionTitle('Ưu tiên hôm nay'),
      if (o.pendingStocktakes.isNotEmpty)
        for (final k in o.pendingStocktakes)
          _PriorityTile(
            icon: Icons.fact_check_outlined,
            title: 'Duyệt kiểm kê ${k.code}',
            subtitle:
                '${k.staffName} gửi ${k.submittedAt == null ? '' : formatDateTimeShort(k.submittedAt!)} · ${k.varianceLines == 0 ? 'Không lệch' : '${k.varianceLines} dòng lệch'}',
            onTap: () => _go(StocktakeReviewScreen(stocktakeId: k.id)),
          ),
      if (soonest != null)
        _PriorityTile(
          icon: Icons.hourglass_bottom_rounded,
          title: '${soonest.name} còn ${formatDaysLeft(soonest.daysLeft)}',
          subtitle: low.length > 1
              ? '+${low.length - 1} nguyên liệu khác sắp hết'
              : 'Xem gợi ý nhập',
          onTap: () => _go(const SuggestionsScreen()),
        ),
      if (o.needsPricingCount > 0)
        _PriorityTile(
          icon: Icons.sell_outlined,
          title: '${o.needsPricingCount} phiếu nhận hàng chờ bổ sung giá',
          subtitle: 'Nhân viên đã nhận hàng, giá vốn chưa cập nhật',
          onTap: () => _go(const OrdersScreen(initialTab: 1)),
        ),
      if (o.expiringLots.isNotEmpty)
        _PriorityTile(
          icon: Icons.event_busy_outlined,
          title:
              'Lô ${o.expiringLots.first.code} (${o.expiringLots.first.name}) gần hết hạn',
          subtitle:
              'HSD ${formatShortDate(o.expiringLots.first.expiry)} · ưu tiên dùng trước',
          onTap: () => _go(IngredientListScreen(
              initialSearch: o.expiringLots.first.name)),
        ),
      if (o.openRequestCount > 0)
        _PriorityTile(
          icon: Icons.mark_email_unread_outlined,
          title: '${o.openRequestCount} yêu cầu sửa phiếu từ nhân viên',
          subtitle: 'Ghi nhầm hao hụt hoặc phiếu nhập',
          onTap: () => _go(const InventoryRequestsScreen()),
        ),
      if (o.pendingStocktakes.isEmpty &&
          soonest == null &&
          o.needsPricingCount == 0 &&
          o.expiringLots.isEmpty &&
          o.openRequestCount == 0)
        const KhoNote('Không có việc gấp. Kho đang ổn.',
            icon: Icons.check_circle_outline_rounded),
      const SizedBox(height: 8),
      const KhoSectionTitle('Một vòng quanh kho'),
      KhoCard(
        onTap: () => _go(const WasteOverviewScreen()),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KhoEyebrow('Hao hụt đã ghi · 7 ngày qua'),
                const SizedBox(height: 6),
                Text(formatVnd(o.waste7d), style: AppTextStyles.metric),
                const SizedBox(height: 2),
                Text(_wasteCaption(o), style: AppTextStyles.caption),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded),
        ]),
      ),
      if (o.topItems.isNotEmpty) ...[
        const SizedBox(height: 12),
        KhoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KhoEyebrow('Tiền nằm ở nguyên liệu nào'),
              const SizedBox(height: 8),
              for (final t in o.topItems)
                LabelValueRow(
                  t.name,
                  '${formatVnd(t.value)} · ${o.stockValue <= 0 ? 0 : (t.value * 100 / o.stockValue).toStringAsFixed(1).replaceAll('.', ',')}%',
                ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      const KhoSectionTitle('Quản lý'),
      _MenuTile(
        icon: Icons.inventory_2_outlined,
        title: 'Nguyên liệu',
        subtitle: '${o.ingredientCount} nguyên liệu · tồn, giá, lô hàng',
        onTap: () => _go(const IngredientListScreen()),
      ),
      _MenuTile(
        icon: Icons.local_shipping_outlined,
        title: 'Nhà cung cấp',
        subtitle: 'Người giao hàng, lịch giao, giá gần nhất',
        onTap: () => _go(const SupplierListScreen()),
      ),
      _MenuTile(
        icon: Icons.receipt_long_outlined,
        title: 'Phiếu nhập hàng',
        subtitle: o.draftOrderCount > 0
            ? '${o.draftOrderCount} phiếu nháp đang chờ'
            : 'Nhập mới, xem lại các phiếu đã ghi',
        onTap: () => _go(const OrdersScreen()),
      ),
      _MenuTile(
        icon: Icons.fact_check_outlined,
        title: 'Kiểm kê',
        subtitle: 'Đếm & đối chiếu, duyệt điều chỉnh',
        onTap: () => _go(const StocktakeListScreen()),
      ),
      _MenuTile(
        icon: Icons.auto_graph_rounded,
        title: 'Nhìn lại tuần',
        subtitle: 'Kho ổn, hao hụt, kiểm kê thường lệ',
        onTap: () => _go(const WeekReviewScreen()),
      ),
    ];
  }

  String _valueCaption(InvOverview o) {
    if (o.unpricedCount > 0) {
      return '${o.unpricedCount} nguyên liệu chưa có giá nên chưa được tính vào.';
    }
    return 'Tính theo giá bình quân của từng nguyên liệu.';
  }

  String _wasteCaption(InvOverview o) {
    final pct = o.wasteChangePct;
    if (pct == null) {
      return o.waste7d == 0 ? 'Chưa ghi hao hụt nào.' : 'Chưa có kỳ trước để so.';
    }
    return '${pct >= 0 ? 'Tăng' : 'Giảm'} ${pct.abs().round()}% so với 7 ngày trước';
  }
}

class _PriorityTile extends StatelessWidget {
  const _PriorityTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: KhoCard(
          onTap: onTap,
          child: Row(children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.statusAttentionTint,
                borderRadius: BorderRadius.circular(AppSizes.radiusTile),
              ),
              child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icon, color: AppColors.statusAttention)),
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

class _MenuTile extends StatelessWidget {
  const _MenuTile(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: KhoCard(
          onTap: onTap,
          child: Row(children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.tint,
                borderRadius: BorderRadius.circular(AppSizes.radiusTile),
              ),
              child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(icon, color: AppColors.brand)),
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

/// Danh sách yêu cầu sửa phiếu nhân viên gửi lên.
class InventoryRequestsScreen extends StatefulWidget {
  const InventoryRequestsScreen({super.key});

  @override
  State<InventoryRequestsScreen> createState() =>
      _InventoryRequestsScreenState();
}

class _InventoryRequestsScreenState extends State<InventoryRequestsScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<List<InventoryRequest>> _data =
      AsyncData(_repo.requests)..load();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Yêu cầu sửa phiếu',
        subtitle: 'Nhân viên ghi nhầm và nhờ bạn sửa',
        body: AsyncView<List<InventoryRequest>>(
          source: _data,
          builder: (context, list) => [
            if (list.isEmpty)
              const KhoNote('Không có yêu cầu nào đang chờ.',
                  icon: Icons.check_circle_outline_rounded),
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KhoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${r.kind == 'waste' ? 'Hao hụt' : 'Phiếu nhập'} ${r.refCode ?? ''}',
                          style: AppTextStyles.cardTitle),
                      const SizedBox(height: 4),
                      Text('${r.staffName}: ${r.note}',
                          style: AppTextStyles.body),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () async {
                            final ok = await guarded(context, () async {
                              await _repo.resolveRequest(r.id);
                              return true;
                            });
                            if (ok == true) _data.load(silent: true);
                          },
                          child: const Text('Đã xử lý'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
