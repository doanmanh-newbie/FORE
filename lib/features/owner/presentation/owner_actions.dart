part of 'owner_home_screen.dart';

extension _OwnerActions on _OwnerHomeContentState {
  Widget _more(OwnerDashboardData data) {
    void push(Widget page) => Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    final hasShift = data.openShift != null;
    const dayGroup = 'Vận hành hằng ngày';
    const shopGroup = 'Quản lý quán';
    const teamGroup = 'Đội ngũ';
    const helpGroup = 'Tài khoản và trợ giúp';
    const stockGroup = 'Kho và nhập hàng';
    const jumpGroup = 'Đi nhanh đến nghiệp vụ';
    return OwnerMoreHub(
      header: _pageHeader(),
      personName: widget.profile.fullName,
      shopName: widget.profile.shopName,
      onSwitchShop: () => showShopSwitcher(context),
      onSignOut: _signOut,
      entries: [
        MoreEntry(
          id: 'waste',
          group: dayGroup,
          icon: ForeActionIcons.waste,
          title: 'Ghi hao hụt',
          subtitle: hasShift
              ? 'Đổ bỏ, làm sai, cho nhân viên, thử vị'
              : 'Mở ca để dùng',
          keywords: const ['hao hut', 'do bo'],
          onTap: hasShift
              ? () => push(
                  WasteScreen(repository: context.read<InventoryRepository>()))
              : null,
        ),
        MoreEntry(
          id: 'cash',
          group: dayGroup,
          icon: ForeActionIcons.cashMovement,
          title: 'Thu / chi tiền mặt',
          subtitle: hasShift ? 'Mua đá, chủ rút tiền...' : 'Mở ca để dùng',
          keywords: const ['thu chi', 'tien mat'],
          onTap: hasShift
              ? () =>
                  push(CashScreen(repository: context.read<CashRepository>()))
              : null,
        ),
        MoreEntry(
          id: 'shop-profile',
          group: shopGroup,
          icon: Icons.storefront_outlined,
          title: 'Hồ sơ và thông tin quán',
          subtitle: 'Tên, liên hệ, giờ mở cửa, thông tin hóa đơn',
          keywords: const ['ho so', 'dia chi', 'ma so thue', 'gio mo cua'],
          onTap: () => push(const ShopProfileScreen()),
        ),
        MoreEntry(
          id: 'floor',
          group: shopGroup,
          icon: Icons.table_restaurant_outlined,
          title: 'Khu vực và bàn',
          subtitle: 'Thêm, đổi tên, tạm ẩn khu vực và bàn',
          keywords: const ['ban', 'khu vuc', 'so do'],
          onTap: () => push(const FloorScreen()),
        ),
        MoreEntry(
          id: 'branches',
          group: shopGroup,
          icon: Icons.account_tree_outlined,
          title: 'Quản lý chi nhánh',
          subtitle: 'Các quán của bạn, chuyển nhanh giữa các quán',
          keywords: const ['chi nhanh', 'chuyen quan'],
          onTap: () => push(const BranchesScreen()),
        ),
        MoreEntry(
          id: 'team',
          group: teamGroup,
          icon: Icons.groups_outlined,
          title: 'Nhân sự',
          subtitle: 'Mời, đổi vai trò, thu hồi thành viên',
          keywords: const ['nhan vien', 'moi', 'thu hoi'],
          onTap: () => push(const TeamHubScreen()),
        ),
        MoreEntry(
          id: 'roles',
          group: teamGroup,
          icon: Icons.admin_panel_settings_outlined,
          title: 'Vai trò và phân quyền',
          subtitle: 'Quản lý, Thu ngân, Nhân viên được làm gì',
          keywords: const ['quyen', 'vai tro', 'phan quyen'],
          onTap: () => push(const RolesScreen()),
        ),
        MoreEntry(
          id: 'inbox',
          group: teamGroup,
          icon: Icons.mail_outline_rounded,
          title: 'Hộp thư',
          subtitle: 'Lời mời vào quán',
          keywords: const ['loi moi'],
          onTap: () => Navigator.of(context).pushNamed(AppRoutes.inbox),
        ),
        MoreEntry(
          id: 'suppliers',
          group: stockGroup,
          icon: Icons.local_shipping_outlined,
          title: 'Nhà cung cấp',
          subtitle: 'Người giao hàng, lịch giao, giá gần nhất',
          keywords: const ['giao hang'],
          onTap: () => push(const SupplierListScreen()),
        ),
        MoreEntry(
          id: 'orders',
          group: stockGroup,
          icon: Icons.receipt_long_outlined,
          title: 'Phiếu nhập hàng',
          subtitle: 'Nhập mới, xem lại các phiếu đã ghi',
          keywords: const ['nhap kho'],
          onTap: () => push(const OrdersScreen()),
        ),
        MoreEntry(
          id: 'ingredients',
          group: stockGroup,
          icon: Icons.inventory_2_outlined,
          title: 'Nguyên liệu',
          subtitle: 'Tồn, giá bình quân và lô hàng',
          keywords: const ['ton kho'],
          onTap: () => push(const IngredientListScreen()),
        ),
        MoreEntry(
          id: 'stocktake',
          group: stockGroup,
          icon: Icons.fact_check_outlined,
          title: 'Kiểm kê',
          subtitle: 'Đếm, đối chiếu, duyệt điều chỉnh',
          onTap: () => push(const StocktakeListScreen()),
        ),
        MoreEntry(
          id: 'tab-reconcile',
          group: jumpGroup,
          icon: Icons.fact_check_outlined,
          title: 'Đối soát · Ca làm',
          subtitle: 'Mở tab Đối soát',
          keywords: const ['doi soat', 'ca lam'],
          onTap: () => _openTab(1),
        ),
        MoreEntry(
          id: 'tab-menu',
          group: jumpGroup,
          icon: Icons.menu_book_outlined,
          title: 'Thực đơn · Danh mục món',
          subtitle: 'Mở tab Thực đơn',
          keywords: const ['mon', 'cong thuc'],
          onTap: () => _openTab(2),
        ),
        MoreEntry(
          id: 'tab-stock',
          group: jumpGroup,
          icon: Icons.inventory_outlined,
          title: 'Kho · Tổng quan',
          subtitle: 'Mở tab Kho',
          onTap: () => _openTab(3),
        ),
        MoreEntry(
          id: 'audit',
          group: helpGroup,
          icon: Icons.history_rounded,
          title: 'Nhật ký và dữ liệu',
          subtitle: 'Ai đã đổi gì, lúc nào; sao chép CSV',
          keywords: const ['nhat ky', 'xuat', 'csv', 'lich su'],
          onTap: () => push(const AuditScreen()),
        ),
        MoreEntry(
          id: 'support',
          group: helpGroup,
          icon: Icons.support_agent_outlined,
          title: 'Hỗ trợ và cập nhật',
          subtitle: 'Gửi yêu cầu, xem phiên bản ứng dụng',
          keywords: const ['ho tro', 'tro giup', 'phien ban'],
          onTap: () => push(const SupportScreen()),
        ),
      ],
    );
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

  Future<void> _returnToManagement() async {
    if (!mounted) return;
    Navigator.of(context).pop();
    await _refresh();
  }

  Future<bool> _saveShiftReview(
      OwnerShiftReport report, bool handled, String? note) async {
    try {
      await context.read<OwnerDashboardController>().saveReview(
            report,
            handled,
            note,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu trạng thái và ghi chú.')),
        );
        _reconcile.reload(silent: true);
      }
      return true;
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_errorMessage(error))),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Không lưu được trạng thái đối soát. Vui lòng thử lại.'),
          ),
        );
      }
      return false;
    }
  }

  /// Chủ sửa số lượng một phiếu nhập hoặc một lần ghi hao hụt, rồi báo cáo được tính lại.
  Future<bool> _correctReportEntry(
    OwnerShiftReport report,
    CorrectionKind kind,
    String id,
    int newQty,
    String reason,
  ) async {
    final source = context.read<OwnerDashboardDataSource>();
    final dashboard = context.read<OwnerDashboardController>();
    final messenger = ScaffoldMessenger.of(context);
    var saved = false;
    try {
      if (kind == CorrectionKind.waste) {
        await source.correctWaste(id, newQty, reason);
      } else {
        await source.correctPurchase(id, newQty, reason);
      }
      saved = true;
      final fresh = await source.loadShiftReport('${report.shift['id']}');
      if (!mounted) return true;
      _updateState(() {
        if (_selectedReport?.shift['id'] == report.shift['id']) {
          _selectedReport = OwnerShiftReport(
            shift: report.shift,
            report: fresh,
            review: report.review,
          );
        }
      });
      _reconcile.reload(silent: true);
      dashboard.load(refresh: true);
      messenger.showSnackBar(
        const SnackBar(
            content: Text('Đã lưu số lượng mới. Báo cáo được tính lại.')),
      );
      return true;
    } on PostgrestException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text(databaseMessages[error.message] ?? _errorMessage(error)),
        ),
      );
      return false;
    } catch (_) {
      // Đã lưu mà tải lại lỗi thì báo đã lưu, để chủ không bấm sửa lần nữa
      messenger.showSnackBar(SnackBar(
        content: Text(saved
            ? 'Đã lưu số lượng mới nhưng chưa tải lại được báo cáo. Mở lại báo cáo để xem số mới.'
            : 'Không lưu được số lượng mới. Kiểm tra kết nối rồi thử lại.'),
      ));
      return saved;
    }
  }

  Future<void> _openNotifications(OwnerDashboardData data) async {
    final navigator = Navigator.of(context);
    final result = await navigator.push<Object?>(
      MaterialPageRoute<Object?>(
        builder: (_) => OwnerNotificationsScreen(
          data: data,
          onMarkRead:
              context.read<OwnerDashboardController>().markNotificationsRead,
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      await _refresh();
      if (!mounted) return;
    }
    if (result == 'invites') {
      await navigator.pushNamed(AppRoutes.inbox);
    } else if (result is OwnerShiftReport) {
      _updateState(() {
        _tab = 1;
        _selectedReport = result;
      });
    }
  }
}
