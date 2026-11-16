import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/widgets/fore_action_icons.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/inventory/domain/inventory_models.dart';
import 'package:fore/features/inventory/domain/inventory_repository.dart';
import 'package:fore/features/owner/domain/owner_dashboard_models.dart';
import 'package:fore/features/owner/data/owner_dashboard_repository.dart';
import 'package:fore/features/owner/menu/menu_repository.dart';
import 'package:fore/features/owner/presentation/owner_home_screen.dart';

import '../../support/fake_menu_repository.dart';
import '../../support/fake_kho_repository.dart';
import '../../support/fake_settings_repository.dart';
import '../../support/fake_shop_repository.dart';
import 'package:fore/app/app_routes.dart';
import 'package:fore/features/shop/domain/shop_repository.dart';
import 'package:fore/features/settings/domain/settings_repository.dart';
import 'package:fore/features/inventory/domain/kho_repository.dart';

void main() {
  final cases = <({String tab, String content})>[
    (tab: 'Tổng quan', content: 'Doanh thu hôm nay'),
    (tab: 'Đối soát', content: 'Chưa có ca đã đóng'),
    (tab: 'Thực đơn', content: 'QA-Trà'),
    (tab: 'Kho', content: 'Tồn dự kiến 150 g'),
    (tab: 'Thêm', content: 'Chăm quán, từ những điều nhỏ'),
  ];

  testWidgets('so doanh thu với hôm qua tính đến cùng giờ', (tester) async {
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('-71% so với hôm qua cùng giờ'), findsOneWidget);
    expect(find.textContaining('Chưa so sánh'), findsNothing);
  });

  testWidgets('quán mới có checklist thao tác thiết lập', (tester) async {
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(newShop: true),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chào mừng quán của bạn!'), findsOneWidget);
    expect(find.text('Thiết lập thực đơn'), findsOneWidget);
    expect(find.text('Thêm nguyên liệu đầu tiên'), findsOneWidget);
    expect(find.text('Mời nhân viên'), findsWidgets);
  });

  testWidgets('tổng quan có hai thao tác nhanh và hero ca cần chú ý',
      (tester) async {
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(reports: [_sampleReport]),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Mời nhân viên'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Mời nhân viên'), findsOneWidget);
    expect(find.text('Nhân viên'), findsWidgets);
    final heroAction = find.text('Kiểm tra kho & hao hụt');
    await tester.scrollUntilVisible(
      heroAction,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(heroAction, findsOneWidget);
    expect(find.text('Ca của Nhân viên QA'), findsWidgets);
    expect(find.text('≈420.682đ'), findsWidgets);
    expect(find.text('QA-Trân châu · Hụt 450 g'), findsOneWidget);
    expect(find.text('Tiền mặt · thiếu 120.000đ'), findsOneWidget);
    expect(find.text('Lý thuyết 1.000 g · Thực dùng 1.450 g'), findsOneWidget);
    await tester.tap(heroAction);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Thao tác kho'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Thao tác kho'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dashboard_outlined));
    await tester.pumpAndSettle();
    final detailAction = find.text('Xem chi tiết đối soát');
    await tester.scrollUntilVisible(
      detailAction,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(detailAction);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết đối soát'), findsOneWidget);
  });

  testWidgets('ca cũ chưa xử lý vẫn hiện ở Tổng quan và mở danh sách lọc',
      (tester) async {
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(
              reports: [_handledOkReport],
              pendingOverride: 2,
            ),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    final card = find.text('2 ca cần xử lý');
    await tester.scrollUntilVisible(card, 250,
        scrollable: find.byType(Scrollable).first);
    expect(card, findsOneWidget);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Đối soát ca'), findsOneWidget);
    expect(find.text('Cần xử lý'), findsWidgets);
  });

  testWidgets('Tổng quan gom cảnh báo tồn theo mức độ thay vì lặp từng món',
      (tester) async {
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(lowStock: [
              {'name': 'Trân châu', 'expected_qty': -200},
              {'name': 'Đào', 'expected_qty': -100},
              {'name': 'Trà', 'expected_qty': 500},
            ]),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();

    expect(find.text('2 nguyên liệu tồn âm'), findsOneWidget);
    expect(find.text('1 nguyên liệu dưới ngưỡng'), findsOneWidget);
    expect(find.textContaining('Trân châu'), findsOneWidget);
    expect(find.textContaining('Đào'), findsOneWidget);
    expect(find.textContaining('Trà'), findsWidgets);
  });

  testWidgets('tổng quan dùng skeleton khi đang tải thay vì spinner trơn',
      (tester) async {
    final inventory = _FakeInventoryRepository();
    final gate = Completer<OwnerDashboardData>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(loadGate: gate),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);

    gate.complete(await _FakeOwnerDashboardDataSource().load());
    await tester.pumpAndSettle();
    expect(find.text('Doanh thu hôm nay'), findsOneWidget);
  });

  for (final item in cases) {
    testWidgets('tab ${item.tab} hiển thị nội dung từ repository',
        (tester) async {
      final inventory = _FakeInventoryRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<OwnerDashboardDataSource>.value(
              value: _FakeOwnerDashboardDataSource(),
            ),
            Provider<InventoryRepository>.value(value: inventory),
            Provider<CashRepository>.value(value: inventory),
            Provider<MenuRepository>.value(value: FakeMenuRepository()),
            Provider<KhoRepository>.value(value: FakeKhoRepository()),
          ],
          child: const MaterialApp(
            home: OwnerHomeScreen(profile: _ownerProfile),
          ),
        ),
      );
      await tester.pumpAndSettle();

      if (item.tab != 'Tổng quan') {
        await tester.tap(find.text(item.tab).last);
        await tester.pumpAndSettle();
      }

      await tester.scrollUntilVisible(
        find.text(item.content),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(item.content), findsOneWidget);
    });
  }

  testWidgets('các tab chủ quán không tràn ở 360x800 với chữ 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final inventory = _FakeInventoryRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.3),
            ),
            child: child!,
          ),
          home: const OwnerHomeScreen(profile: _ownerProfile),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Tổng quan');

    for (final tab in ['Đối soát', 'Thực đơn', 'Kho', 'Thêm']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      final exception = tester.takeException();
      expect(exception, isNull, reason: tab);
    }
  });

  testWidgets('đối soát diễn đạt tiền mặt thiếu bằng ngôn ngữ rõ ràng',
      (tester) async {
    final dashboard = _FakeOwnerDashboardDataSource(reports: [_sampleReport]);
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(value: dashboard),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đối soát').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Tiền mặt thiếu 120.000đ'), findsOneWidget);
    expect(find.textContaining('Tiền mặt -120.000đ'), findsNothing);
  });

  testWidgets('tồn dự kiến âm được nêu rõ là cần kiểm tra', (tester) async {
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kho').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Tồn dự kiến âm 2.680 g'),
      240,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.textContaining('Tồn dự kiến âm 2.680 g'), findsOneWidget);
    expect(
      find.textContaining('Cần kiểm tra kiểm kê và hao hụt'),
      findsOneWidget,
    );
  });

  testWidgets('Kho và Thêm dùng cùng icon cho hao hụt và thu chi',
      (tester) async {
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(
            value: _FakeOwnerDashboardDataSource(),
          ),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ['Kho', 'Thêm']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byIcon(ForeActionIcons.waste),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byIcon(ForeActionIcons.waste), findsOneWidget);
      expect(find.byIcon(ForeActionIcons.cashMovement), findsOneWidget);
    }
  });

  // Smoke test luồng chủ quán: mỗi mục trong tab Thêm mở được, không lỗi dựng, rồi quay lại.
  const moreEntries = [
    'Hồ sơ và thông tin quán',
    'Khu vực và bàn',
    'Quản lý chi nhánh',
    'Nhân sự',
    'Vai trò và phân quyền',
    'Nhà cung cấp',
    'Phiếu nhập hàng',
    'Nguyên liệu',
    'Kiểm kê',
    'Nhật ký và dữ liệu',
    'Hỗ trợ và cập nhật',
    'Hộp thư',
    'Ghi hao hụt',
    'Thu / chi tiền mặt',
  ];
  for (final entry in moreEntries) {
    testWidgets('tab Thêm: mở "$entry" không lỗi và quay lại được',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final inventory = _FakeInventoryRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<OwnerDashboardDataSource>.value(
              // Có ca đang mở để bấm được Ghi hao hụt và Thu / chi.
              value: _FakeOwnerDashboardDataSource(
                openShift: const {
                  'id': 'shift-open',
                  'opened_by_name': 'Ngọc Lan',
                  'opened_at': '2026-11-14T06:30:00+07:00',
                },
              ),
            ),
            Provider<InventoryRepository>.value(value: inventory),
            Provider<CashRepository>.value(value: inventory),
            Provider<MenuRepository>.value(value: FakeMenuRepository()),
            Provider<KhoRepository>.value(value: FakeKhoRepository()),
            Provider<SettingsRepository>.value(value: FakeSettingsRepository()),
            Provider<ShopRepository>.value(value: FakeShopRepository()),
          ],
          child: const MaterialApp(
            home: OwnerHomeScreen(profile: _ownerProfile),
            onGenerateRoute: AppRoutes.generate,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm').last);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text(entry), 200,
          scrollable: find.byType(Scrollable).at(0));
      await tester.ensureVisible(find.text(entry).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(entry).last);
      await tester.pumpAndSettle();
      // Màn mới đẩy lên navigator gốc nên che thanh tab dưới.
      expect(find.text('Tổng quan'), findsNothing,
          reason: '"$entry" phải mở màn mới');

      await tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .maybePop();
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan'), findsOneWidget);
    });
  }

  testWidgets('đối soát mở chi tiết, lưu ghi chú và đổi trạng thái xử lý',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dashboard = _FakeOwnerDashboardDataSource(reports: [_sampleReport]);
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(value: dashboard),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đối soát').last);
    await tester.pumpAndSettle();
    // 300.682đ nguyên liệu + 120.000đ tiền mặt thiếu.
    expect(find.text('≈420.682đ'), findsOneWidget);
    await tester.tap(find.text('Ca của Nhân viên QA'));
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết đối soát'), findsOneWidget);
    expect(find.text('Chưa xử lý'), findsOneWidget);

    await tester.tap(find.text('Ghi chú & xử lý'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'QA đã kiểm tra chứng từ');
    await tester.pump();
    await tester.tap(find.text('Đánh dấu đã xử lý'));
    await tester.pumpAndSettle();

    expect(dashboard.reviewWrites, hasLength(1));
    expect(dashboard.reviewWrites.single.$1, 'shift-qa-1');
    expect(dashboard.reviewWrites.single.$2, isTrue);
    expect(dashboard.reviewWrites.single.$3, 'QA đã kiểm tra chứng từ');
    expect(find.text('Đã xử lý'), findsOneWidget);
    expect(find.text('Chưa xử lý'), findsNothing);
  });

  testWidgets('đối soát báo lỗi khi lưu thất bại và giữ trạng thái cũ',
      (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final dashboard = _FakeOwnerDashboardDataSource(
      reports: [_sampleReport],
      failReviewSave: true,
    );
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(value: dashboard),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
          Provider<MenuRepository>.value(value: FakeMenuRepository()),
          Provider<KhoRepository>.value(value: FakeKhoRepository()),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đối soát').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ca của Nhân viên QA'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ghi chú & xử lý'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đánh dấu đã xử lý'));
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được trạng thái đối soát. Vui lòng thử lại.'),
        findsOneWidget);
    expect(find.text('Chưa lưu được. Hãy kiểm tra kết nối và thử lại.'),
        findsOneWidget);
    expect(find.text('Đánh dấu đã xử lý'), findsOneWidget);
    expect(find.text('Chưa xử lý'), findsOneWidget);
    expect(dashboard.reviewWrites, isEmpty);
  });
}

const _ownerProfile = Profile(
  staffId: 'owner-1',
  fullName: 'Chủ quán QA',
  role: StaffRole.owner,
  hasPin: true,
  active: true,
  shopId: 'shop-1',
  shopName: 'Quán QA',
);

class _FakeOwnerDashboardDataSource implements OwnerDashboardDataSource {
  _FakeOwnerDashboardDataSource({
    this.reports = const [],
    this.failReviewSave = false,
    this.newShop = false,
    this.loadGate,
    this.lowStock = const [],
    this.pendingOverride,
    this.openShift,
  });

  final Map<String, dynamic>? openShift;
  final List<OwnerShiftReport> reports;
  final bool failReviewSave;
  final bool newShop;
  final Completer<OwnerDashboardData>? loadGate;
  final List<Map<String, dynamic>> lowStock;
  final int? pendingOverride;
  int loadCalls = 0;
  final List<(String, bool, String?)> reviewWrites = [];

  @override
  Future<OwnerDashboardData> load() async {
    loadCalls++;
    if (loadGate != null) return loadGate!.future;
    final start = DateTime.now();
    return OwnerDashboardData(
      shifts: reports.map((report) => report.shift).toList(),
      reports: reports,
      openShift: openShift,
      cashSales: 29000,
      transferSales: 0,
      yesterdaySales: 100000,
      billCount: newShop ? 0 : 1,
      pendingInvites: 0,
      activeStaffCount: 0,
      menu: newShop
          ? const []
          : const [
              {'item_name': 'QA-Trà', 'size_name': 'Vừa', 'price': 29000},
            ],
      expectedStock: newShop
          ? const []
          : const [
              {
                'ingredient_id': 'ingredient-1',
                'name': 'QA-Trà',
                'unit': 'g',
                'expected_qty': 150,
              },
              {
                'ingredient_id': 'ingredient-2',
                'name': 'QA-Trân châu',
                'unit': 'g',
                'expected_qty': -2680,
              },
            ],
      lowStock: lowStock,
      pendingReviewCount: pendingOverride ??
          reports
              .where((report) =>
                  ['warn', 'alert'].contains(report.overall) && !report.handled)
              .length,
      missingRecipeCount: 0,
      notifications: const [],
      updatedAt: start,
      businessStart: start,
      businessEnd: start.add(const Duration(days: 1)),
      recentSales: List.generate(
        7,
        (index) => DailySalesPoint(
          businessStart: DateTime(2026, 10, 24 + index),
          sales: 25000 + index * 1000,
        ),
      ),
    );
  }

  @override
  Future<OwnerShiftPage> loadShiftPage({
    required DateTime from,
    required DateTime to,
    String filter = 'all',
    int limit = 10,
    DateTime? before,
  }) async =>
      OwnerShiftPage(
        items: reports
            .where((report) => switch (filter) {
                  'attention' => ['warn', 'alert'].contains(report.overall),
                  'unhandled' => !report.handled,
                  'pending' => ['warn', 'alert'].contains(report.overall) &&
                      !report.handled,
                  _ => true,
                })
            .toList(),
        hasMore: false,
      );

  final List<(String, String, int, String)> corrections = [];

  @override
  Future<Map<String, dynamic>> loadShiftReport(String shiftId) async =>
      reports.firstWhere((report) => '${report.shift['id']}' == shiftId).report;

  @override
  Future<void> correctWaste(String wasteId, int newQty, String reason) async {
    corrections.add(('waste', wasteId, newQty, reason));
  }

  @override
  Future<void> correctPurchase(
      String purchaseId, int newQty, String reason) async {
    corrections.add(('purchase', purchaseId, newQty, reason));
  }

  @override
  Future<void> markNotificationsRead(List<String> keys) async {}

  @override
  Future<void> setShiftReview(
      String shiftId, bool handled, String? note) async {
    if (failReviewSave) {
      throw StateError('QA simulated save failure');
    }
    reviewWrites.add((shiftId, handled, note));
  }
}

const _handledOkReport = OwnerShiftReport(
  shift: {
    'id': 'shift-qa-ok',
    'status': 'closed',
    'opened_at': '2026-10-28T08:00:00.000Z',
    'closed_at': '2026-10-28T17:00:00.000Z',
    'opened_by_name': 'Nhân viên QA',
  },
  report: {
    'summary': {'overall': 'ok'},
    'ingredients': [],
    'cash': {
      'status': 'ok',
      'expected_cash': 1,
      'closing_cash': 1,
      'variance': 0
    },
  },
  review: {'handled': true, 'note': ''},
);

const _sampleReport = OwnerShiftReport(
  shift: {
    'id': 'shift-qa-1',
    'opened_at': '2026-10-29T08:00:00.000Z',
    'closed_at': '2026-10-29T17:00:00.000Z',
    'opened_by_name': 'Nhân viên QA',
  },
  report: {
    'summary': {'overall': 'warn'},
    'cash': {
      'variance': -120000,
      'opening_cash': 500000,
      'opening_diff': 0,
      'cash_sales': 200000,
      'transfer_sales': 0,
      'cash_in': 0,
      'cash_out': 0,
      'cancelled_after_paid_count': 0,
      'cancelled_after_paid_amount': 0,
      'expected_cash': 700000,
      'closing_cash': 580000,
    },
    'ingredients': [
      {
        'ingredient_name': 'QA-Trân châu',
        'status': 'warn',
        'theoretical_used': 1000,
        'actual_used': 1450,
        'adjusted_variance': 450,
        'unit': 'g',
        'equiv_revenue': 300682,
      },
    ],
    'cash_movements': [],
  },
  review: {'handled': false, 'note': ''},
);

class _FakeInventoryRepository implements InventoryRepository, CashRepository {
  @override
  Future<void> addMovement({
    required bool incoming,
    required int amount,
    String? note,
  }) async {}

  @override
  Future<void> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
  }) async {}

  @override
  Future<List<IngredientOption>> ingredients() async => const [];

  @override
  Future<List<WasteTypeOption>> wasteTypes() async => const [];
}
