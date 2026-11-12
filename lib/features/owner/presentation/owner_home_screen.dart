import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../app/app_routes.dart';
import '../../../core/format.dart';
import '../../../core/design/app_header.dart';
import '../../../core/design/hero_card.dart';
import '../../../core/design/skeleton_box.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/fore_action_icons.dart';
import '../../../core/widgets/page_scaffold.dart';
import '../../../core/widgets/status_chip.dart';
import '../../auth/application/session_controller.dart';
import '../../auth/domain/auth_models.dart';
import '../../home/home_screen.dart';
import '../../inventory/domain/inventory_repository.dart';
import '../../inventory/presentation/cash_screen.dart';
import '../../inventory/presentation/owner_kho_home.dart';
import '../../inventory/presentation/waste_screen.dart';
import '../../inventory/presentation/ingredient_screens.dart';
import '../../inventory/presentation/purchase_screens.dart';
import '../../inventory/presentation/stocktake_screens.dart';
import '../../inventory/presentation/supplier_screens.dart';
import '../../more/owner_more_hub.dart';
import '../../settings/presentation/audit_screen.dart';
import '../../settings/presentation/floor_screen.dart';
import '../../settings/presentation/roles_screen.dart';
import '../../settings/presentation/shop_profile_screen.dart';
import '../../settings/presentation/support_screen.dart';
import '../../settings/presentation/team_screens.dart';
import '../../shop/presentation/shop_switcher.dart';
import '../data/owner_dashboard_repository.dart';
import '../application/owner_dashboard_controller.dart';
import '../domain/owner_dashboard_models.dart';
import '../../../core/errors/network_errors.dart';
import '../menu/menu_home_view.dart';
import '../menu/menu_repository.dart';
import '../menu/menu_store.dart';
import '../reconcile/reconcile_detail_view.dart';
import '../reconcile/reconcile_list_controller.dart';
import '../reconcile/reconcile_list_view.dart';
import '../reconcile/reconcile_format.dart';
import '../reconcile/reconcile_models.dart';
import '../reconcile/reconcile_widgets.dart' show CorrectionKind;
import 'owner_notifications_screen.dart';

part 'owner_dashboard_widgets.dart';
part 'owner_dashboard_report_widgets.dart';
part 'owner_dashboard_loading_widgets.dart';
part 'owner_dashboard_formatters.dart';
part 'owner_overview.dart';
part 'owner_reconciliation.dart';
part 'owner_catalog.dart';
part 'owner_actions.dart';

/// Trang chủ riêng của chủ quán. Số liệu mẫu trong file thiết kế không được dùng
/// ở đây; mọi chỉ số hiển thị đều lấy từ database hoặc hiện trạng thái trống/lỗi.
class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (context) =>
            OwnerDashboardController(context.read<OwnerDashboardDataSource>())
              ..load(),
        child: _OwnerHomeContent(profile: profile),
      );
}

class _OwnerHomeContent extends StatefulWidget {
  const _OwnerHomeContent({required this.profile});

  final Profile profile;

  @override
  State<_OwnerHomeContent> createState() => _OwnerHomeContentState();
}

class _OwnerHomeContentState extends State<_OwnerHomeContent>
    with WidgetsBindingObserver {
  int _tab = 0;
  OwnerShiftReport? _selectedReport;

  /// Chuyển tab từ trang "Thêm" (dùng trong extension nên không gọi setState ở ngoài State).
  void _openTab(int index) => setState(() {
        _tab = index;
        _selectedReport = null;
      });
  late final ReconcileListController _reconcile;
  MenuStore? _menuStore;
  String? _menuShopId;

  /// Thực đơn của quán đang chọn; tạo lại khi đổi quán để không lẫn dữ liệu.
  MenuStore _menuStoreForShop() {
    final shopId = widget.profile.shopId;
    final existing = _menuStore;
    if (existing != null && _menuShopId == shopId) return existing;
    existing?.dispose();
    _menuShopId = shopId;
    return _menuStore = MenuStore(
      context.read<MenuRepository>(),
      shopKey: shopId.isEmpty ? 'default' : shopId,
      cache: PreferencesMenuCache(),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final source = context.read<OwnerDashboardDataSource>();
    _reconcile = ReconcileListController(
      loader: ({required from, required to, required filter, before}) =>
          source.loadShiftPage(
        from: from,
        to: to,
        filter: filter,
        before: before,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconcile.dispose();
    _menuStore?.dispose();
    super.dispose();
  }

  /// Mở lại app sau một lúc: tự làm mới số liệu để chủ không xem số cũ.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final dashboard = context.read<OwnerDashboardController>();
    final data = dashboard.data;
    if (data == null) return;
    if (DateTime.now().difference(data.updatedAt) > const Duration(minutes: 2)) {
      dashboard.load(refresh: true);
      _reconcile.reload(silent: true);
    }
  }

  void _updateState(VoidCallback update) => setState(update);

  Future<void> _refresh() =>
      context.read<OwnerDashboardController>().load(refresh: true);

  Widget _pageHeader() {
    final data = context.watch<OwnerDashboardController>().data;
    return AppHeader(
      shopName:
          widget.profile.shopName.isEmpty ? 'Fore' : widget.profile.shopName,
      subtitle: 'Chủ quán · ${widget.profile.fullName}',
      onChooseShop: () => showShopSwitcher(context),
      onNotifications: data == null ? null : () => _openNotifications(data),
      unreadCount:
          data?.notifications.where((notice) => !notice.read).length ?? 0,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<OwnerDashboardController>();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Builder(
        builder: (context) {
          final data = dashboard.data;
          if (data == null && dashboard.loading) {
            return const _OwnerDashboardLoading();
          }
          if (data == null) {
            return _ErrorPanel(
              onRetry: _refresh,
              message: _errorMessage(dashboard.failure),
            );
          }
          final page = _page(data);
          if (dashboard.failure == null && data.unavailable.isEmpty) return page;
          if (dashboard.failure == null) {
            return Column(children: [
              MaterialBanner(
                content: Text(
                  'Chưa tải được: ${_unavailableNames(data.unavailable)}. '
                  'Các số liệu còn lại vẫn đúng.',
                ),
                leading: const Icon(Icons.cloud_off_outlined),
                actions: [
                  TextButton(onPressed: _refresh, child: const Text('Thử lại')),
                ],
              ),
              Expanded(child: page),
            ]);
          }
          return Column(children: [
            MaterialBanner(
              content: Text(_errorMessage(dashboard.failure)),
              leading: const Icon(Icons.cloud_off_outlined),
              actions: [
                TextButton(onPressed: _refresh, child: const Text('Thử lại')),
              ],
            ),
            Expanded(child: page),
          ]);
        },
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() {
          _tab = index;
          _selectedReport = null;
        }),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined), label: 'Tổng quan'),
          NavigationDestination(
              icon: Icon(Icons.fact_check_outlined), label: 'Đối soát'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), label: 'Thực đơn'),
          NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined), label: 'Kho'),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Thêm'),
        ],
      ),
    );
  }

  Widget _page(OwnerDashboardData data) {
    if (_tab == 4) return _more(data);
    if (_tab == 1) {
      final report = _selectedReport;
      return report == null ? _reconcileList() : _reconcileDetail(report);
    }
    if (_tab == 2) return _menu(data);
    if (_tab == 3) return _stock(data);
    return _overview(data);
  }
}
