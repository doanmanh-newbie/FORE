import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fore/core/widgets/fore_action_icons.dart';
import 'package:fore/core/widgets/status_chip.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/inventory/domain/inventory_models.dart';
import 'package:fore/features/inventory/domain/inventory_repository.dart';
import 'package:fore/features/owner/owner_dashboard_models.dart';
import 'package:fore/features/owner/owner_dashboard_repository.dart';
import 'package:fore/features/owner/owner_home_screen.dart';

void main() {
  final cases = <({String tab, String content})>[
    (tab: 'Tổng quan', content: 'Doanh thu hôm nay'),
    (tab: 'Đối soát', content: 'Chưa có ca để đối soát'),
    (tab: 'Thực đơn', content: 'QA-Trà · Vừa'),
    (tab: 'Kho', content: 'Tồn dự kiến 150 g'),
    (tab: 'Thêm', content: 'Quản lý quán'),
  ];

  testWidgets('không so doanh thu ca đang mở với cả ngày hôm trước',
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
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Chưa so sánh: ngày kinh doanh chưa kết thúc.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('% so với ngày kinh doanh trước'), findsNothing);
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

      expect(find.text(item.content), findsOneWidget);
    });
  }

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
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kho').last);
    await tester.pumpAndSettle();

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
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    for (final tab in ['Kho', 'Thêm']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(find.byIcon(ForeActionIcons.waste), findsOneWidget);
      expect(find.byIcon(ForeActionIcons.cashMovement), findsOneWidget);
    }
  });

  testWidgets('đối soát mở chi tiết, lưu ghi chú và đổi trạng thái xử lý',
      (tester) async {
    final dashboard = _FakeOwnerDashboardDataSource(reports: [_sampleReport]);
    final inventory = _FakeInventoryRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<OwnerDashboardDataSource>.value(value: dashboard),
          Provider<InventoryRepository>.value(value: inventory),
          Provider<CashRepository>.value(value: inventory),
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Đối soát').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('ước tính ≈ 300.682đ'), findsOneWidget);
    await tester.tap(find.text('Xem chi tiết').first);
    await tester.pumpAndSettle();
    expect(find.text('Chi tiết đối soát'), findsOneWidget);
    expect(
      tester
          .widget<StatusChip>(find.widgetWithText(StatusChip, 'Thiếu'))
          .severity,
      StatusSeverity.critical,
    );

    await tester.enterText(find.byType(TextField), 'QA đã kiểm tra chứng từ');
    await tester.pump();
    final markHandled = find.text('Đánh dấu đã xử lý');
    await tester.scrollUntilVisible(
      markHandled,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(markHandled);
    await tester.pumpAndSettle();

    expect(dashboard.reviewWrites, hasLength(1));
    expect(dashboard.reviewWrites.single.$1, 'shift-qa-1');
    expect(dashboard.reviewWrites.single.$2, isTrue);
    expect(dashboard.reviewWrites.single.$3, 'QA đã kiểm tra chứng từ');
    expect(find.text('Đánh dấu chưa xử lý'), findsOneWidget);
  });

  testWidgets('đối soát báo lỗi khi lưu thất bại và giữ trạng thái cũ',
      (tester) async {
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
        ],
        child: const MaterialApp(home: OwnerHomeScreen(profile: _ownerProfile)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đối soát').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xem chi tiết').first);
    await tester.pumpAndSettle();

    final action = find.widgetWithText(FilledButton, 'Đánh dấu đã xử lý');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.text('Không lưu được trạng thái đối soát. Vui lòng thử lại.'),
        findsOneWidget);
    expect(find.text('Trạng thái xử lý'), findsOneWidget);
    expect(find.text('Chưa xử lý'), findsOneWidget);
    expect(find.text('Đánh dấu đã xử lý'), findsOneWidget);
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
  });

  final List<OwnerShiftReport> reports;
  final bool failReviewSave;
  int loadCalls = 0;
  final List<(String, bool, String?)> reviewWrites = [];

  @override
  Future<OwnerDashboardData> load() async {
    loadCalls++;
    final start = DateTime.now();
    return OwnerDashboardData(
      shifts: reports.map((report) => report.shift).toList(),
      reports: reports,
      openShift: null,
      cashSales: 29000,
      transferSales: 0,
      yesterdaySales: 100000,
      billCount: 1,
      pendingInvites: 0,
      activeStaffCount: 0,
      menu: const [
        {'item_name': 'QA-Trà', 'size_name': 'Vừa', 'price': 29000},
      ],
      expectedStock: const [
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
      lowStock: const [],
      missingRecipeCount: 0,
      notifications: const [],
      updatedAt: start,
      businessStart: start,
      businessEnd: start.add(const Duration(days: 1)),
    );
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
  Future<void> addPurchase({
    required String ingredientId,
    required int qty,
    bool late = false,
    String? note,
    String? requestId,
  }) async {}

  @override
  Future<void> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
    String? requestId,
  }) async {}

  @override
  Future<List<IngredientOption>> ingredients() async => const [];

  @override
  Future<List<WasteTypeOption>> wasteTypes() async => const [];
}
