part of 'owner_home_screen.dart';

extension _OwnerCatalog on _OwnerHomeContentState {
  Widget _menu(OwnerDashboardData data) => ChangeNotifierProvider<MenuStore>.value(
        value: _menuStoreForShop(),
        child: MenuHomeView(header: _pageHeader()),
      );

  Widget _stock(OwnerDashboardData data) => OwnerKhoHome(
        header: _pageHeader(),
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
                      body: row['expected_qty'] == null
                          ? 'Chưa có lần kiểm kê · ${row['unit'] ?? ''}'
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
