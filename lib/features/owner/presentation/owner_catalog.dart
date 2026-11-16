part of 'owner_home_screen.dart';

extension _OwnerCatalog on _OwnerHomeContentState {
  Widget _menu(OwnerDashboardData data) => ChangeNotifierProvider<MenuStore>.value(
        value: _menuStoreForShop(),
        child: MenuHomeView(
          header: _pageHeader(),
          // Tiêu đề, "Quản lý danh mục" và ô tìm kiếm nằm trong header rêu.
          headerBuilder: ({required title, action, search}) => _mossHeader(
            title: title,
            titleAction: action,
            bottom: search,
          ),
        ),
      );

  Widget _stock(OwnerDashboardData data) => OwnerKhoHome(
        header: _pageHeader(),
        // Header rêu: "Kho", giờ cập nhật và 3 chỉ số nhanh (tồn âm, dưới ngưỡng, cần nhập).
        headerBuilder: (overview) => _mossHeader(
          title: 'Kho',
          caption: Text(overview == null
              ? 'Một vòng quanh kho'
              : 'Cập nhật ${formatHm(overview.updatedAt)} · ${formatDmy(overview.updatedAt)}'),
          bottom: _KhoStats(
            negative: data.lowStock
                .where((item) => _number(item['expected_qty']) < 0)
                .length,
            belowThreshold: data.lowStock
                .where((item) => _number(item['expected_qty']) >= 0)
                .length,
            toOrder: overview?.suggestionCount,
          ),
        ),
        footer: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              const _SectionTitle(title: 'Tồn dự kiến theo lần đếm gần nhất'),
              if (data.expectedStock.isEmpty)
                _InfoCard(
                  icon: Icons.inventory_2_outlined,
                  iconColor: AppColors.textSecondary,
                  title: 'Chưa có số liệu tồn kho',
                  status: const StatusChip(
                    label: 'Chưa có dữ liệu',
                    severity: StatusSeverity.neutral,
                    compact: true,
                  ),
                  body: 'Tồn dự kiến sẽ xuất hiện sau khi có kiểm kê.',
                )
              else
                ..._stockRowsBySeverity(data).map((row) => _InfoCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: row['expected_qty'] == null
                          ? AppColors.textSecondary
                          : _stockSeverity(_number(row['expected_qty'])) ==
                                  StatusSeverity.critical
                              ? AppColors.statusOff
                              : _isBelowThreshold(row, data)
                                  ? AppColors.statusWatch
                                  : AppColors.statusOk,
                      title: '${row['name'] ?? 'Nguyên liệu'}',
                      status: row['expected_qty'] == null
                          ? const StatusChip(
                              label: 'Chưa có số liệu',
                              severity: StatusSeverity.neutral,
                              compact: true,
                            )
                          : StatusChip(
                              label: _stockStatusLabel(row, data),
                              severity: _stockSeverity(
                                _number(row['expected_qty']),
                                belowThreshold: _isBelowThreshold(row, data),
                              ),
                              compact: true,
                            ),
                      level: row['expected_qty'] == null
                          ? null
                          : _stockLevel(row, data),
                      body: row['expected_qty'] == null
                          ? 'Chưa có lần kiểm kê · ${row['unit'] == 'piece' ? 'cái' : row['unit'] ?? ''}'
                          : _number(row['expected_qty']) < 0
                              ? 'Tồn dự kiến âm '
                                  '${formatQuantity(_number(row['expected_qty']).abs(), unit: '${row['unit'] ?? ''}')}. Cần kiểm tra kiểm kê và hao hụt.'
                              : 'Tồn dự kiến ${formatQuantity(_number(row['expected_qty']), unit: '${row['unit'] ?? ''}')}'
                                  '${_minimumStock(row, data)}',
                    )),
            const SizedBox(height: 12),
            const _SectionTitle(title: 'Thao tác kho'),
              Row(children: [
                Expanded(
                  child: _StockActionButton(
                    title: 'Ghi hao hụt',
                    icon: ForeActionIcons.waste,
                    enabled: data.openShift != null,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => WasteScreen(
                          repository: context.read<InventoryRepository>(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StockActionButton(
                    title: 'Thu / chi',
                    icon: ForeActionIcons.cashMovement,
                    enabled: data.openShift != null,
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => CashScreen(
                          repository: context.read<CashRepository>(),
                        ),
                      ),
                    ),
                  ),
                ),
              ]),
          ],
        ),
      );
}

/// Ba chỉ số nhanh trong header Kho. Số > 0 thì tô màu cảnh báo; "Cần nhập" chưa có
/// số liệu (kho chưa tải xong) thì hiện "—".
class _KhoStats extends StatelessWidget {
  const _KhoStats({
    required this.negative,
    required this.belowThreshold,
    required this.toOrder,
  });

  final int negative;
  final int belowThreshold;
  final int? toOrder;

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int? value, Color alert) => Expanded(
          child: Semantics(
            label: '$label: ${value ?? 'chưa có'}',
            child: ExcludeSemantics(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.roleCard),
                  border: Border.all(
                      color: AppColors.white.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value == null ? '—' : '$value',
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: (value ?? 0) > 0 ? alert : AppColors.white,
                      ),
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 12,
                        color: AppColors.onDarkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
    return Row(children: [
      // Màu cố định trên nền rêu: hồng nhạt cho tồn âm, vàng cho dưới ngưỡng / cần nhập.
      stat('Tồn âm', negative, const Color(0xFFFFB4AB)),
      const SizedBox(width: 8),
      stat('Dưới ngưỡng', belowThreshold, AppColors.onDarkWarning),
      const SizedBox(width: 8),
      stat('Cần nhập', toOrder, AppColors.mustard),
    ]);
  }
}
