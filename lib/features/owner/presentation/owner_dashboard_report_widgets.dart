part of 'owner_home_screen.dart';

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.data});
  final OwnerDashboardData data;

  @override
  Widget build(BuildContext context) {
    final change = data.salesChangePercent;
    final now = DateTime.now();
    final start = data.businessStart;
    final isToday = start.year == now.year &&
        start.month == now.month &&
        start.day == now.day;
    final changeLabel = change == null
        ? 'Chưa có doanh thu hôm qua để so sánh'
        : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(0)}% so với hôm qua cùng giờ';
    return ForeCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            isToday
                ? 'Doanh thu hôm nay'
                : 'Doanh thu ${start.day}/${start.month}',
            style: AppTextStyles.headline),
        const SizedBox(height: 8),
        Text(formatVnd(data.totalSales), style: AppTextStyles.metricXL),
        const SizedBox(height: 6),
        Text(
          'Tiền mặt ${formatVnd(data.cashSales)} · Chuyển khoản ${formatVnd(data.transferSales)}',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 12),
        Text('Doanh thu 7 ngày', style: AppTextStyles.captionStrong),
        const SizedBox(height: 6),
        if (data.unavailable.contains('trend'))
          Text('Chưa tải được biểu đồ 7 ngày. Kéo xuống để thử lại.',
              style: AppTextStyles.caption)
        else
          _SalesTrendBars(points: data.recentSales),
        const SizedBox(height: 4),
        Text(changeLabel, style: AppTextStyles.caption),
      ]),
    );
  }
}

class _SalesTrendBars extends StatelessWidget {
  const _SalesTrendBars({required this.points});

  final List<DailySalesPoint> points;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return Text('Chưa có dữ liệu 7 ngày.', style: AppTextStyles.caption);
    }
    final maxSales = points.fold<int>(1, (max, point) {
      return point.sales > max ? point.sales : max;
    });
    return SizedBox(
      height: 62,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final point in points)
            Expanded(
              child: Semantics(
                label:
                    '${point.businessStart.day}/${point.businessStart.month}, doanh thu ${formatVnd(point.sales)}',
                child: ExcludeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: point.sales == 0
                              ? 3
                              : 8 + 34 * point.sales / maxSales,
                          decoration: BoxDecoration(
                            // Cột cũ >= 3:1 với nền thẻ ở cả hai chế độ; hôm nay đậm nhất.
                            color: point.sales == 0
                                ? AppColors.border
                                : point == points.last
                                    ? AppColors.brand
                                    : AppColors.brandAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 12,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('${point.businessStart.day}',
                                style: AppTextStyles.micro),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  const _ShiftCard({required this.shift, required this.onOpenOps});
  final Map<String, dynamic>? shift;
  final VoidCallback onOpenOps;

  @override
  Widget build(BuildContext context) => _InfoCard(
        icon: shift == null ? Icons.schedule_outlined : Icons.circle,
        title: shift == null ? 'Chưa có ca đang mở' : 'Ca đang mở',
        body: shift == null
            ? 'Mở màn hình vận hành để bắt đầu ca.'
            : 'Ca của ${shift!['opened_by_name'] ?? 'nhân viên'} · mở lúc ${formatHm(DateTime.parse(shift!['opened_at'] as String).toLocal())}',
        onTap: onOpenOps,
        showArrow: true,
      );
}

/// Thẻ nổi bật cho ca cần chủ xử lý. Dùng cùng mô hình và chữ với màn Đối soát.
class _FeaturedReportCard extends StatelessWidget {
  const _FeaturedReportCard({
    required this.report,
    required this.onTap,
    this.onCheckStock,
  });

  final ReconcileReport report;
  final VoidCallback onTap;
  final VoidCallback? onCheckStock;

  @override
  Widget build(BuildContext context) {
    final shortItems = report.ingredients
        .where((item) => item.needsAttention && item.isShort)
        .toList(growable: false);
    final top = shortItems.isEmpty ? null : shortItems.first;
    final cash = report.cash;
    final cashLine = cash.hasData && cash.needsAttention
        ? 'Tiền mặt · ${reconcileCashText(cash.variance).toLowerCase()}'
        : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
      child: HeroCard(
        title: report.title,
        status: StatusChip(
          label: reconcileStatusLabel(report.overall),
          severity: reconcileSeverity(report.overall),
          compact: true,
        ),
        primaryLabel: 'Xem chi tiết đối soát',
        onPrimary: onTap,
        secondaryLabel: 'Kiểm tra kho & hao hụt',
        onSecondary: onCheckStock,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reconcileShiftTime(report.openedAt, report.closedAt),
              style: AppTextStyles.caption.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            // Chưa có số ước tính thì không in một tiêu đề lớn "Chưa ước tính": nói thẳng vấn đề.
            if (report.totalImpact > 0) ...[
              Text('Ảnh hưởng ước tính',
                  style: AppTextStyles.caption.copyWith(color: Colors.white70)),
              Text(
                reconcileImpactText(report),
                style: AppTextStyles.headline.copyWith(color: Colors.white),
              ),
            ],
            const SizedBox(height: 6),
            Text(reconcileProblemSummary(report),
                style: AppTextStyles.body.copyWith(color: Colors.white)),
            if (top != null) ...[
              const SizedBox(height: 4),
              Text(
                '${top.name} · ${reconcileVarianceText(top.adjusted, top.unit)}',
                style: AppTextStyles.body.copyWith(color: Colors.white),
              ),
              Text(
                'Lý thuyết ${reconcileQty(top.theoretical, top.unit)} · Thực dùng ${reconcileQty(top.actualUsed, top.unit)}',
                style: AppTextStyles.caption.copyWith(color: Colors.white70),
              ),
            ],
            if (cashLine != null) ...[
              const SizedBox(height: 4),
              Text(cashLine,
                  style: AppTextStyles.body.copyWith(color: Colors.white)),
            ],
            const SizedBox(height: 10),
            StatusChip(
              label: report.handled ? 'Đã xử lý' : 'Chưa xử lý',
              severity: report.handled
                  ? StatusSeverity.healthy
                  : StatusSeverity.attention,
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
