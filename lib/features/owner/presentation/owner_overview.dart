part of 'owner_home_screen.dart';

extension _OwnerOverview on _OwnerHomeContentState {
  Widget _overview(OwnerDashboardData data) {
    final negativeStock = data.lowStock
        .where((item) => _number(item['expected_qty']) < 0)
        .toList(growable: false);
    final belowThreshold = data.lowStock
        .where((item) => _number(item['expected_qty']) >= 0)
        .toList(growable: false);
    final reports = data.reports
        .map(ReconcileReport.fromOwner)
        .toList(growable: false);
    ReconcileReport? needsReview;
    for (final report in reports) {
      if (report.needsAttention && !report.handled) {
        needsReview = report;
        break;
      }
    }
    final featured = needsReview;
    final otherPending = data.pendingReviewCount - (featured == null ? 0 : 1);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: PageScaffold(
        header: _pageHeader(),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Tổng quan', style: AppTextStyles.display),
              ),
              IconButton(
                tooltip: 'Làm mới',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Hôm nay, ${_shortDate(data.updatedAt)} · cập nhật ${formatHm(data.updatedAt)}',
              style: AppTextStyles.caption,
              textAlign: TextAlign.right,
            ),
          ),
          Text(_businessDayLabel(data), style: AppTextStyles.caption),
          if (data.shifts.isEmpty &&
              data.menu.isEmpty &&
              data.expectedStock.isEmpty &&
              data.billCount == 0) ...[
            const SizedBox(height: 14),
            _NewShopChecklist(
              onMenu: () => _updateState(() => _tab = 2),
              onStock: () => _updateState(() => _tab = 3),
              onInvite: () => Navigator.of(context).pushNamed(AppRoutes.team),
            ),
          ],
          const SizedBox(height: 14),
          _ShiftCard(
            shift: data.openShift,
            onOpenOps: () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => OpsHomeScreen(
                  onBackToManagement: _returnToManagement,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _RevenueCard(data: data),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Bill đã thanh toán',
                  value: '${data.billCount}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  label: 'Doanh thu / bill',
                  value: data.billCount == 0
                      ? '—'
                      : formatVnd(data.totalSales ~/ data.billCount),
                  icon: Icons.trending_up_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Mời nhân viên',
                  subtitle: 'Thêm người vào quán',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.team),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickActionTile(
                  icon: Icons.groups_2_outlined,
                  title: 'Nhân viên',
                  subtitle: data.openShift == null
                      ? 'Quản lý đội ngũ'
                      : '${data.activeStaffCount} người đã tạo bill trong ca',
                  onTap: () => Navigator.of(context).pushNamed(AppRoutes.team),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          _SectionTitle(
            title: 'Đối soát',
            trailing: TextButton(
              onPressed: () => _updateState(() => _tab = 1),
              child: const Text('Xem tất cả'),
            ),
          ),
          if (featured != null)
            _FeaturedReportCard(
              report: featured,
              onTap: () => _updateState(() {
                _tab = 1;
                _selectedReport = featured.source;
              }),
              onCheckStock: () => _updateState(() {
                _tab = 3;
                _selectedReport = null;
              }),
            ),
          if (otherPending > 0)
            _InfoCard(
              icon: Icons.fact_check_outlined,
              iconColor: AppColors.statusWatch,
              title: featured == null
                  ? '${data.pendingReviewCount} ca cần xử lý'
                  : '$otherPending ca khác cần xử lý',
              status: const StatusChip(
                label: 'Chưa xử lý',
                severity: StatusSeverity.attention,
                compact: true,
              ),
              body: 'Các ca có chênh lệch trong 7 ngày gần đây mà bạn chưa đánh dấu đã xử lý.',
              onTap: () {
                _reconcile.setFilter(ReconcileFilter.pending);
                _updateState(() {
                  _tab = 1;
                  _selectedReport = null;
                });
              },
              showArrow: true,
            )
          else if (featured == null && reports.isNotEmpty)
            reports.any((report) => report.overall == ReconcileStatus.noData)
                ? const _InfoCard(
                    icon: Icons.info_outline,
                    iconColor: AppColors.textSecondary,
                    title: 'Có ca chưa đủ dữ liệu',
                    status: StatusChip(
                      label: 'Chưa đối soát',
                      severity: StatusSeverity.neutral,
                      compact: true,
                    ),
                    body:
                        'Ca thiếu kiểm kê đầu ca hoặc tiền đếm cuối ca nên chưa đối soát được.',
                  )
                : const _InfoCard(
                    icon: Icons.check_circle_outline,
                    iconColor: AppColors.statusOk,
                    title: 'Không có ca cần xử lý',
                    status: StatusChip(
                      label: 'Khớp',
                      severity: StatusSeverity.healthy,
                      compact: true,
                    ),
                    body: 'Các ca gần đây đều khớp hoặc bạn đã xử lý.',
                  )
          else if (featured == null)
            const _InfoCard(
              icon: Icons.fact_check_outlined,
              iconColor: AppColors.textSecondary,
              title: 'Chưa có dữ liệu đối soát',
              status: StatusChip(
                label: 'Chưa có dữ liệu',
                severity: StatusSeverity.neutral,
                compact: true,
              ),
              body: 'Báo cáo sẽ xuất hiện sau khi đóng ca và hoàn tất kiểm kê.',
            ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Cần chú ý'),
          if (data.missingRecipeCount > 0)
            _InfoCard(
              icon: Icons.menu_book_outlined,
              iconColor: AppColors.statusWatch,
              title: '${data.missingRecipeCount} size chưa có công thức',
              status: const StatusChip(
                label: 'Thiếu công thức',
                severity: StatusSeverity.attention,
                compact: true,
              ),
              body: 'Đối soát nguyên liệu có thể chưa tính đủ phần tiêu hao.',
              onTap: () => _updateState(() => _tab = 2),
            ),
          if (negativeStock.isNotEmpty)
            _InfoCard(
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.statusOff,
              title: '${negativeStock.length} nguyên liệu tồn âm',
              status: const StatusChip(
                label: 'Cần kiểm tra',
                severity: StatusSeverity.critical,
                compact: true,
              ),
              body:
                  '${_stockNames(negativeStock)}. Kiểm tra sổ kho và kiểm kê.',
              onTap: () => _updateState(() => _tab = 3),
            ),
          if (belowThreshold.isNotEmpty)
            _InfoCard(
              icon: Icons.inventory_2_outlined,
              iconColor: AppColors.statusWatch,
              title: '${belowThreshold.length} nguyên liệu dưới ngưỡng',
              status: const StatusChip(
                label: 'Chú ý',
                severity: StatusSeverity.attention,
                compact: true,
              ),
              body: '${_stockNames(belowThreshold)}. Nên kiểm tra mức tồn.',
              onTap: () => _updateState(() => _tab = 3),
            ),
          if (data.pendingInvites > 0)
            _InfoCard(
              icon: Icons.person_add_alt_1_outlined,
              title: '${data.pendingInvites} lời mời đang chờ',
              body: 'Mở hộp thư để xem trạng thái lời mời nhân viên.',
              onTap: () => Navigator.of(context).pushNamed(AppRoutes.inbox),
            ),
          if (data.missingRecipeCount == 0 &&
              negativeStock.isEmpty &&
              belowThreshold.isEmpty &&
              data.pendingInvites == 0)
            const _InfoCard(
              icon: Icons.check_circle_outline,
              iconColor: AppColors.statusOk,
              title: 'Không có nhắc việc mới',
              status: StatusChip(
                label: 'Ổn',
                severity: StatusSeverity.healthy,
                compact: true,
              ),
              body: 'Các cảnh báo sẽ hiện ở đây khi có dữ liệu cần xem.',
            ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Ca gần đây'),
          if (data.reports.isEmpty)
            const _InfoCard(
              icon: Icons.history_rounded,
              title: 'Chưa có ca đã đóng',
              body: 'Lịch sử ca sẽ xuất hiện ở đây sau khi đóng ca.',
            )
          else
            ...reports.take(3).map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: AppSizes.cardGap),
                child: ReconcileShiftCard(
                  report: report,
                  onTap: () => _updateState(() {
                    _tab = 1;
                    _selectedReport = report.source;
                  }),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Cập nhật lúc ${formatHm(data.updatedAt)} · ngày kinh doanh 06:00–05:59',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

String _stockNames(List<Map<String, dynamic>> items) {
  final names = items.take(3).map((item) => '${item['name']}').toList();
  final remaining = items.length - names.length;
  return remaining > 0
      ? '${names.join(', ')} và $remaining mục khác'
      : names.join(', ');
}
