import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/app_routes.dart';
import '../../core/data/rpc_client.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/failure_messages.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/fore_bottom_nav.dart';
import '../../core/widgets/fore_header.dart';
import '../../core/widgets/ops_icon.dart';
import '../../core/format.dart';
import '../auth/application/session_controller.dart';
import '../auth/domain/auth_models.dart';
import '../inventory/data/rpc_inventory_repository.dart';
import '../inventory/presentation/cash_screen.dart';
import '../inventory/presentation/inventory_hub_view.dart';
import '../inventory/presentation/purchase_screen.dart';
import '../inventory/presentation/waste_screen.dart';
import '../more/more_view.dart';
import '../sales/application/table_map_controller.dart';
import '../sales/application/takeaway_controller.dart';
import '../sales/data/rpc_sales_repository.dart';
import '../sales/presentation/bill_screen.dart';
import '../sales/presentation/shift_bills_screen.dart';
import '../sales/presentation/tables_view.dart';
import '../sales/presentation/takeaway_view.dart';
import '../ops/shift/application/shift_controller.dart';
import '../ops/shift/data/rpc_shift_repository.dart';
import '../ops/shift/presentation/close_shift_view.dart';
import '../ops/shift/presentation/no_shift_view.dart';
import '../shop/presentation/shop_switcher.dart';
import '../stocktake/data/rpc_stocktake_repository.dart';
import '../stocktake/domain/stocktake_models.dart';
import '../stocktake/presentation/stocktake_screen.dart';

/// Khung chính sau khi đăng nhập: đầu trang (tên quán, người dùng, trạng thái ca), 5 tab và thanh điều hướng.
///   0 Trang chủ (bản đồ bàn, hoặc "Chưa mở ca")   1 Mang đi   2 Kho   3 Đóng ca   4 Thêm
/// Chưa có ca thì Mang đi, Kho, Đóng ca bị khóa.
///
/// Giữ nguyên chữ ký `HomeScreen({super.key})` nên không cần sửa route. `rpc` chỉ để thay thế khi cần thử.
class OpsHomeScreen extends StatefulWidget {
  const OpsHomeScreen({super.key, this.rpc, this.onBackToManagement});

  final RpcClient? rpc;
  final VoidCallback? onBackToManagement;

  @override
  State<OpsHomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<OpsHomeScreen>
    with WidgetsBindingObserver {
  static const _tablesRefresh = Duration(seconds: 15);
  static const _shiftRefresh = Duration(seconds: 30);

  late final RpcClient _rpc =
      widget.rpc ?? SupabaseRpcClient(Supabase.instance.client);
  late final _shiftRepo = RpcOpsShiftRepository(_rpc);
  late final _salesRepo = RpcSalesRepository(_rpc);
  late final _stockRepo = RpcStocktakeRepository(_rpc);
  late final _inventoryRepo = RpcInventoryRepository(_rpc);

  late final OpsShiftController _shift = OpsShiftController(_shiftRepo);
  late final TableMapController _tables = TableMapController(_salesRepo);
  late final TakeawayController _takeaway = TakeawayController(_salesRepo);

  int _tab = 2;
  bool _hadShift = false;
  Timer? _shiftTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _shift.addListener(_onShiftChanged);
    _shift.load();
    _shiftTimer = Timer.periodic(_shiftRefresh, (_) {
      if (!_shift.busy) _shift.load();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shiftTimer?.cancel();
    _shift.removeListener(_onShiftChanged);
    _shift.dispose();
    _tables.dispose();
    _takeaway.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _shift.load();
      if (_shift.hasOpenShift) {
        _tables.load();
        _takeaway.load();
      }
    }
  }

  /// Ca vừa mở (ở máy này hoặc máy khác) thì tải bàn và đơn; ca vừa đóng thì về tab an toàn và dừng làm mới.
  void _onShiftChanged() {
    final has = _shift.hasOpenShift;
    if (has == _hadShift) return;
    _hadShift = has;
    if (has) {
      _tables.load();
      _takeaway.load();
    } else if (_tab != 4) {
      _tab = 2; // Về Trang chủ (ở giữa, index 2)
    }
    _syncTimers();
    if (mounted) setState(() {});
  }

  void _syncTimers() {
    if (_shift.hasOpenShift && _tab == 2) {
      _tables.startAutoRefresh(_tablesRefresh);
    } else {
      _tables.stopAutoRefresh();
    }
    if (_shift.hasOpenShift && _tab == 0) {
      _takeaway.startAutoRefresh(_tablesRefresh);
    } else {
      _takeaway.stopAutoRefresh();
    }
  }

  void _select(int tab) {
    setState(() => _tab = tab);
    _syncTimers();
    if (tab == 2 && _shift.hasOpenShift) _tables.load();
    if (tab == 0) _takeaway.load();
  }

  // ---------------------------------------------------------------- điều hướng sang màn phụ
  Future<void> _push(Widget screen) => Navigator.of(context)
      .push<void>(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _openBill(String billId) async {
    await _push(BillScreen(
        repository: _salesRepo,
        billId: billId,
        servingLabel: _shift.servingLabel));
    if (!mounted) return;
    _tables.load();
    _takeaway.load();
    _shift.loadCloseStatus();
  }

  Future<void> _openCount(CountKind kind) async {
    await _push(StocktakeScreen(repository: _stockRepo, kind: kind));
    if (mounted) _shift.loadCloseStatus();
  }

  Future<void> _signOut() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final failure = await context.read<SessionController>().signOut();
    if (failure != null) {
      messenger.showSnackBar(SnackBar(content: Text(failure.userMessage)));
      return;
    }
    navigator.pushNamedAndRemoveUntil(AppRoutes.welcome, (_) => false);
  }

  // ---------------------------------------------------------------- giao diện
  @override
  Widget build(BuildContext context) {
    final state = context.watch<SessionController>().state;
    final profile = state is SessionSignedIn ? state.profile : null;
    return ListenableBuilder(
      listenable: _shift,
      builder: (context, _) {
        final hasShift = _shift.hasOpenShift;
        final ready = _shift.phase == OpsShiftPhase.ready;
        final tab = hasShift || _tab == 4 ? _tab : 2;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              ForeHeader(
                shopName: _shift.shop?.name ??
                    (profile?.shopName.isNotEmpty == true
                        ? profile!.shopName
                        : _shift.shopName),
                subtitle: profile == null
                    ? ''
                    : '${profile.role == StaffRole.owner ? 'Chủ quán' : 'Nhân viên'} · ${profile.fullName}',
                onBack: widget.onBackToManagement,
                pill: ready
                    ? ShiftPill(
                        label: hasShift
                            ? 'Ca của ${_shift.shift!.openedByName}, mở lúc ${formatHm(_shift.shift!.openedAt)}'
                            : 'Chưa mở ca',
                        active: hasShift,
                      )
                    : null,
              ),
              Expanded(child: _content(tab, profile)),
            ],
          ),
          bottomNavigationBar: ForeBottomNav(
            selected: tab,
            onSelect: _select,
            items: [
              NavItem(label: 'Mang đi', icon: ForeIcons.bag, enabled: hasShift),
              NavItem(label: 'Kho', icon: ForeIcons.package, enabled: hasShift),
              const NavItem(label: 'Trang chủ', icon: ForeIcons.home),
              NavItem(
                  label: 'Đóng ca', icon: ForeIcons.lock, enabled: hasShift),
              const NavItem(label: 'Thêm', icon: ForeIcons.plus),
            ],
          ),
        );
      },
    );
  }

  Widget _content(int tab, Profile? profile) {
    if (_shift.phase == OpsShiftPhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_shift.phase == OpsShiftPhase.error) {
      final failure = _shift.failure;
      if (failure != null && failure.isSessionProblem) {
        return EmptyState(
          icon: ForeIcons.lock,
          title: 'Cần đăng nhập lại',
          message: failure.userMessage,
          actionLabel: 'Đăng xuất',
          onAction: _signOut,
        );
      }
      var diagnostic = '';
      if (failure is DatabaseFailure) {
        diagnostic = '\n\nMã lỗi: ${failure.code}';
      } else if (kDebugMode && failure is UnknownFailure) {
        diagnostic = '\n\nChi tiết kỹ thuật: ${failure.detail}';
      }
      return ErrorRetry(
          message:
              '${failure?.userMessage ?? 'Không tải được trạng thái ca.'}$diagnostic',
          onRetry: _shift.load);
    }
    final more = MoreView(
      personName: profile?.fullName ?? '',
      roleLabel: profile?.role == StaffRole.owner ? 'Chủ quán' : 'Nhân viên',
      shopName: _shift.shop?.name ??
          (profile?.shopName.isNotEmpty == true
              ? profile!.shopName
              : _shift.shopName),
      hasOpenShift: _shift.hasOpenShift,
      isOwner: profile?.role.isOwner ?? false,
      onShiftBills: () => _push(
        ShiftBillsScreen(
          repository: _salesRepo,
          servingLabel: _shift.servingLabel,
        ),
      ),
      onWaste: () => _push(WasteScreen(repository: _inventoryRepo)),
      onCash: () => _push(CashScreen(repository: _inventoryRepo)),
      onSwitchShop: () => showShopSwitcher(context),
      onInbox: () => Navigator.of(context).pushNamed(AppRoutes.inbox),
      onTeam: () => Navigator.of(context).pushNamed(AppRoutes.team),
      onSignOut: _signOut,
    );
    if (!_shift.hasOpenShift) {
      return tab == 4
          ? more
          : NoShiftView(
              shift: _shift,
              onCountOpening: () => _openCount(CountKind.open),
            );
    }
    return switch (tab) {
      0 => TakeawayView(
          takeaway: _takeaway,
          servingLabel: _shift.servingLabel,
          onOpenBill: _openBill),
      1 => InventoryHubView(
          shift: _shift,
          onPurchase: () => _push(PurchaseScreen(repository: _inventoryRepo)),
          onCount: _openCount,
        ),
      2 => TablesView(
          tables: _tables,
          servingLabel: _shift.servingLabel,
          onOpenBill: _openBill),
      3 => CloseShiftView(
          shift: _shift,
          onViewBills: () => _select(2),
          onCountStock: () => _openCount(CountKind.close),
        ),
      _ => more,
    };
  }
}
