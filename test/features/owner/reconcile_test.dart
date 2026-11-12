import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/features/owner/domain/owner_dashboard_models.dart';
import 'package:fore/features/owner/reconcile/reconcile_detail_view.dart';
import 'package:fore/features/owner/reconcile/reconcile_format.dart';
import 'package:fore/features/owner/reconcile/reconcile_list_controller.dart';
import 'package:fore/features/owner/reconcile/reconcile_list_view.dart';
import 'package:fore/features/owner/reconcile/reconcile_models.dart';
import 'package:fore/features/owner/reconcile/reconcile_widgets.dart';

OwnerShiftReport _lanReport({bool handled = false}) => OwnerShiftReport(
      shift: const {
        'id': 'shift-lan',
        'opened_at': '2026-10-28T01:02:00.000Z',
        'closed_at': '2026-10-28T09:10:00.000Z',
        'opened_by_name': 'Lan',
        'closed_by_name': 'Lan',
      },
      report: const {
        'summary': {'overall': 'alert', 'opening_diff_flag': true},
        'warnings': {'items_without_recipe': 3},
        'ingredients': [
          {
            'ingredient_name': 'Sữa tươi',
            'unit': 'ml',
            'importance': 'important',
            'status': 'alert',
            'opening_qty': 2000,
            'purchased_qty': 1000,
            'closing_qty': 1760,
            'actual_used': 1240,
            'theoretical_used': 1100,
            'variance': 140,
            'variance_pct': 12.7,
            'justified_waste': 20,
            'adjusted_variance': 120,
            'adjusted_pct': 10.9,
            'equiv_cups': 8.0,
            'equiv_revenue': 64000,
            'streak_count': 3,
            'streak_flag': true,
          },
          {
            'ingredient_name': 'Cà phê hạt',
            'unit': 'g',
            'importance': 'important',
            'status': 'ok',
            'actual_used': 400,
            'theoretical_used': 400,
            'adjusted_variance': 0,
            'justified_waste': 0,
            'streak_count': 0,
            'streak_flag': false,
          },
        ],
        'cash': {
          'status': 'warn',
          'opening_cash': 500000,
          'prev_closing_cash': 498000,
          'opening_diff': 2000,
          'cash_sales': 1015000,
          'transfer_sales': 480000,
          'cash_in': 100000,
          'cash_out': 200000,
          'expected_cash': 1415000,
          'closing_cash': 1380000,
          'variance': -35000,
          'cancelled_after_paid_count': 2,
          'cancelled_after_paid_amount': 240000,
          'opening_diff_flag': true,
        },
        'cancelled_bills': [
          {
            'bill_no': 41,
            'amount': 140000,
            'payment_method': 'cash',
            'cancelled_at': '2026-10-28T04:00:00.000Z',
            'reason': 'Khách đổi ý',
            'cancelled_by_name': 'Lan',
            'approved_by_name': 'Chủ quán',
          },
        ],
        'purchases': [
          {
            'id': 'purchase-1',
            'ingredient_name': 'Sữa tươi',
            'unit': 'ml',
            'qty': 1000,
            'original_qty': 1200,
            'is_late_entry': false,
            'note': 'Nhập thêm giữa ca',
            'entered_at': '2026-10-28T03:00:00.000Z',
            'entered_by_name': 'Lan',
          },
        ],
        'waste_entries': [
          {
            'id': 'waste-1',
            'ingredient_name': 'Sữa tươi',
            'unit': 'ml',
            'qty': 20,
            'reason_label': 'Làm sai, đổ ly',
            'note': 'Đổ nhầm ly',
            'entered_at': '2026-10-28T05:30:00.000Z',
            'entered_by_name': 'Minh',
          },
        ],
        'waste': [
          {
            'ingredient_name': 'Sữa tươi',
            'unit': 'ml',
            'reason_label': 'Làm sai, đổ ly',
            'entries': 1,
            'qty': 20,
            'waste_total': 20,
            'theoretical_used': 1100,
            'waste_pct_total': 1.8,
            'flag': 'ok',
          },
        ],
        'cash_movements': [
          {
            'entered_at': '2026-10-28T03:15:00.000Z',
            'direction': 'out',
            'amount': 80000,
            'note': 'Mua đá',
            'entered_by_name': 'Lan',
          },
          {
            'entered_at': '2026-10-28T02:00:00.000Z',
            'direction': 'in',
            'amount': 100000,
            'note': 'Đổi tiền lẻ',
            'entered_by_name': 'Minh',
          },
        ],
      },
      review: {'handled': handled, 'note': handled ? 'Đã hỏi Lan' : ''},
    );

const _okReport = OwnerShiftReport(
  shift: {
    'id': 'shift-minh',
    'opened_at': '2026-10-27T01:00:00.000Z',
    'closed_at': '2026-10-27T05:00:00.000Z',
    'opened_by_name': 'Minh',
  },
  report: {
    'summary': {'overall': 'ok'},
    'ingredients': [],
    'cash': {
      'status': 'ok',
      'opening_cash': 500000,
      'expected_cash': 700000,
      'closing_cash': 700000,
      'variance': 0,
    },
    'waste': [],
    'cash_movements': [],
  },
  review: {'handled': true, 'note': ''},
);

Future<void> _useTallScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pumpDetail(
  WidgetTester tester,
  OwnerShiftReport source, {
  Future<bool> Function(bool, String)? onSave,
  Future<bool> Function(CorrectionKind, String, int, String)? onCorrect,
}) async {
  await _useTallScreen(tester);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReconcileDetailView(
          report: ReconcileReport.fromOwner(source),
          header: const SizedBox.shrink(),
          onBack: () {},
          onSaveReview: onSave ?? (handled, note) async => true,
          onOpenMenu: () {},
          onCorrect: onCorrect,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('mô hình và định dạng', () {
    test('ảnh hưởng ước tính = doanh thu nguyên liệu hụt + tiền mặt thiếu', () {
      final report = ReconcileReport.fromOwner(_lanReport());
      expect(report.overall, ReconcileStatus.alert);
      expect(report.ingredientLoss, 64000);
      expect(report.cashShortfall, 35000);
      expect(report.totalImpact, 99000);
      expect(report.streakIngredients.single.name, 'Sữa tươi');
      expect(report.itemsWithoutRecipe, 3);
    });

    test('doanh thu hụt lấy nguyên liệu lớn nhất, không cộng đôi', () {
      const source = OwnerShiftReport(
        shift: {'id': 's', 'opened_by_name': 'Hà'},
        report: {
          'summary': {'overall': 'alert'},
          'ingredients': [
            {
              'ingredient_name': 'Sữa',
              'status': 'alert',
              'adjusted_variance': 100,
              'equiv_revenue': 64000,
            },
            {
              'ingredient_name': 'Cà phê',
              'status': 'warn',
              'adjusted_variance': 30,
              'equiv_revenue': 50000,
            },
          ],
          'cash': {'status': 'ok', 'expected_cash': 1, 'closing_cash': 1, 'variance': 0},
        },
      );
      final report = ReconcileReport.fromOwner(source);
      expect(report.ingredientLoss, 64000);
      expect(report.totalImpact, 64000);
    });

    test('ca khớp không có ảnh hưởng', () {
      final report = ReconcileReport.fromOwner(_okReport);
      expect(report.totalImpact, 0);
      expect(reconcileImpactText(report), 'Khớp số');
      expect(reconcileProblemSummary(report), 'Mọi thứ khớp');
    });

    test('ca chỉ lệch tiền đầu ca vẫn nêu lý do cần xem', () {
      const source = OwnerShiftReport(
        shift: {'id': 's', 'opened_by_name': 'Hà'},
        report: {
          'summary': {'overall': 'warn', 'opening_diff_flag': true},
          'ingredients': [],
          'cash': {
            'status': 'ok',
            'opening_cash': 502000,
            'opening_diff': 2000,
            'opening_diff_flag': true,
            'expected_cash': 700000,
            'closing_cash': 700000,
            'variance': 0,
          },
        },
      );
      final report = ReconcileReport.fromOwner(source);
      expect(report.needsAttention, isTrue);
      expect(reconcileProblemSummary(report), 'Tiền đầu ca lệch');
      expect(report.cancelledBills, isEmpty);
      expect(report.wasteEntries, isEmpty);
    });

    test('đọc bill hủy và người ghi hao hụt từ báo cáo', () {
      final report = ReconcileReport.fromOwner(_lanReport());
      expect(report.closedByName, 'Lan');
      expect(report.cancelledBills.single.billNo, 41);
      expect(report.cancelledBills.single.approvedByName, 'Chủ quán');
      expect(report.wasteEntries.single.byName, 'Minh');
    });

    test('nguyên liệu dư không bị tính vào doanh thu hụt', () {
      const item = IngredientRecon(
        name: 'Siro',
        unit: 'ml',
        important: false,
        status: ReconcileStatus.warn,
        justifiedWaste: 0,
        streakCount: 0,
        streakFlag: false,
        adjusted: -10,
        equivRevenue: -5000,
      );
      expect(item.isShort, isFalse);
      expect(item.revenueLoss, 0);
    });

    test('tiền mặt thiếu khi chưa có trạng thái từ database', () {
      final cash = CashRecon.fromMap(const {
        'expected_cash': 700000,
        'closing_cash': 640000,
      });
      expect(cash.variance, -60000);
      expect(cash.status, ReconcileStatus.alert);
      expect(CashRecon.fromMap(const {}).hasData, isFalse);
    });

    test('chữ Hụt / Dư / Thiếu và phần trăm kiểu Việt Nam', () {
      expect(reconcileVarianceText(120, 'ml'), 'Hụt 120 ml');
      expect(reconcileVarianceText(-10, 'ml'), 'Dư 10 ml');
      expect(reconcileVarianceText(0, 'g'), 'Khớp');
      expect(reconcileVarianceText(null, 'g'), 'Chưa đối soát');
      expect(reconcileCashText(-35000), 'Thiếu 35.000đ');
      expect(reconcileCashText(20000), 'Dư 20.000đ');
      expect(reconcilePercent(10.9), '10,9%');
      expect(reconcileQty(3, 'piece'), '3 cái');
      expect(reconcileApprox(64000), '≈64.000đ');
    });
  });

  group('danh sách ca', () {
    ReconcileListController controllerFor(
      List<OwnerShiftReport> reports, {
      Map<String, Object?>? calls,
      bool openShift = false,
    }) =>
        ReconcileListController(
          loader: ({required from, required to, required filter, before}) async {
            calls?['filter'] = filter;
            calls?['from'] = from;
            final visible = reports.where((report) {
              if (filter == 'attention') {
                return ['warn', 'alert'].contains(report.overall);
              }
              if (filter == 'unhandled') return !report.handled;
              return true;
            }).toList();
            return OwnerShiftPage(
              items: visible,
              hasMore: false,
              openShift: openShift ? const {'id': 'open'} : null,
            );
          },
        );

    Widget list(
      ReconcileListController controller, {
      void Function(ReconcileReport)? onOpen,
      VoidCallback? onOverview,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: ReconcileListView(
              header: const SizedBox.shrink(),
              controller: controller,
              onOpen: onOpen ?? (_) {},
              onOpenOverview: onOverview ?? () {},
            ),
          ),
        );

    testWidgets('hiện trạng thái, số ước tính và dải xu hướng', (tester) async {
      await _useTallScreen(tester);
      await tester.pumpWidget(
          list(controllerFor([_lanReport(), _okReport])));
      await tester.pumpAndSettle();

      expect(find.text('Ca của Lan'), findsOneWidget);
      expect(find.text('Chênh lệch lớn'), findsOneWidget);
      expect(find.text('≈99.000đ'), findsOneWidget);
      expect(find.text('Sữa tươi lệch 3 ca liên tiếp'), findsOneWidget);
      expect(find.text('Ca của Minh'), findsOneWidget);
      expect(find.text('Khớp số'), findsOneWidget);
      expect(find.text('Đã xử lý'), findsOneWidget);
    });

    testWidgets('đang tải hiện khung chờ, xong hiện danh sách', (tester) async {
      await _useTallScreen(tester);
      final gate = Completer<OwnerShiftPage>();
      final controller = ReconcileListController(
        loader: ({required from, required to, required filter, before}) =>
            gate.future,
      );
      await tester.pumpWidget(list(controller));
      await tester.pump();
      expect(find.byType(SkeletonBox), findsWidgets);
      expect(find.text('Chưa có ca đã đóng'), findsNothing);

      gate.complete(OwnerShiftPage(items: [_okReport], hasMore: false));
      await tester.pumpAndSettle();
      expect(find.text('Ca của Minh'), findsOneWidget);
    });

    testWidgets('bộ lọc Cần xem gọi database và ẩn ca đã khớp', (tester) async {
      await _useTallScreen(tester);
      final calls = <String, Object?>{};
      await tester.pumpWidget(
          list(controllerFor([_lanReport(), _okReport], calls: calls)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Lọc ca'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cần xem').last);
      await tester.pumpAndSettle();
      expect(calls['filter'], 'attention');
      expect(find.text('Ca của Lan'), findsOneWidget);
      expect(find.text('Ca của Minh'), findsNothing);
    });

    testWidgets('chạm thẻ ca mở chi tiết', (tester) async {
      await _useTallScreen(tester);
      ReconcileReport? opened;
      await tester.pumpWidget(list(controllerFor([_lanReport()]),
          onOpen: (report) => opened = report));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ca của Lan'));
      expect(opened?.shiftId, 'shift-lan');
    });

    testWidgets('chưa có ca nào: nút Xem ca đang mở và Về tổng quan',
        (tester) async {
      await _useTallScreen(tester);
      var overview = 0;
      await tester.pumpWidget(list(controllerFor(const [], openShift: true),
          onOverview: () => overview++));
      await tester.pumpAndSettle();
      expect(find.text('Chưa có ca đã đóng'), findsOneWidget);
      expect(find.text('Chờ đóng ca'), findsOneWidget);
      await tester.tap(find.text('Xem ca đang mở'));
      await tester.tap(find.text('Về tổng quan'));
      expect(overview, 2);
    });

    testWidgets('không có ca đang mở thì không hiện Xem ca đang mở',
        (tester) async {
      await _useTallScreen(tester);
      await tester.pumpWidget(list(controllerFor(const [])));
      await tester.pumpAndSettle();
      expect(find.text('Xem ca đang mở'), findsNothing);
      expect(find.text('Về tổng quan'), findsOneWidget);
    });

    testWidgets('mất mạng hiện màn Không có kết nối', (tester) async {
      await _useTallScreen(tester);
      final controller = ReconcileListController(
        loader: ({required from, required to, required filter, before}) async =>
            throw Exception('SocketException: Failed host lookup'),
      );
      await tester.pumpWidget(list(controller));
      await tester.pumpAndSettle();
      expect(find.text('Không có kết nối'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('lỗi tải có nút thử lại', (tester) async {
      await _useTallScreen(tester);
      var attempts = 0;
      final controller = ReconcileListController(
        loader: ({required from, required to, required filter, before}) async {
          attempts++;
          if (attempts == 1) throw StateError('offline');
          return OwnerShiftPage(items: [_okReport], hasMore: false);
        },
      );
      await tester.pumpWidget(list(controller));
      await tester.pumpAndSettle();
      expect(find.text('Chưa tải được danh sách ca'), findsOneWidget);
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Ca của Minh'), findsOneWidget);
    });
  });

  group('ReconcileListController', () {
    test('chọn ngày gửi khoảng 6 giờ sáng đến 6 giờ sáng hôm sau', () async {
      DateTime? sentFrom;
      DateTime? sentTo;
      final controller = ReconcileListController(
        loader: ({required from, required to, required filter, before}) async {
          sentFrom = from;
          sentTo = to;
          return OwnerShiftPage(items: const [], hasMore: false);
        },
      );
      controller.setDate(DateTime(2026, 10, 28, 15));
      await Future<void>.delayed(Duration.zero);
      expect(controller.date, DateTime(2026, 10, 28));
      expect(sentFrom, DateTime(2026, 10, 28, 6));
      expect(sentTo, DateTime(2026, 10, 29, 6));
      controller.dispose();
    });

    test('tải thêm nối trang tiếp theo bằng con trỏ', () async {
      final seen = <DateTime?>[];
      final controller = ReconcileListController(
        loader: ({required from, required to, required filter, before}) async {
          seen.add(before);
          return before == null
              ? OwnerShiftPage(
                  items: [_lanReport()],
                  hasMore: true,
                  nextBefore: DateTime.utc(2026, 10, 28, 1),
                )
              : OwnerShiftPage(items: [_okReport], hasMore: false);
        },
      );
      await controller.reload();
      expect(controller.items, hasLength(1));
      expect(controller.hasMore, isTrue);
      await controller.loadMore();
      expect(controller.items.map((r) => r.shiftId), ['shift-lan', 'shift-minh']);
      expect(controller.hasMore, isFalse);
      expect(seen, [null, DateTime.utc(2026, 10, 28, 1)]);
      controller.dispose();
    });

    test('kết quả cũ bị bỏ khi đã đổi bộ lọc', () async {
      final first = Completer<OwnerShiftPage>();
      var call = 0;
      final controller = ReconcileListController(
        loader: ({required from, required to, required filter, before}) {
          call++;
          if (call == 1) return first.future;
          return Future.value(OwnerShiftPage(items: [_okReport], hasMore: false));
        },
      );
      final slow = controller.reload();
      controller.setFilter(ReconcileFilter.unhandled);
      await Future<void>.delayed(Duration.zero);
      first.complete(OwnerShiftPage(items: [_lanReport()], hasMore: false));
      await slow;
      expect(controller.items.map((r) => r.shiftId), ['shift-minh']);
      controller.dispose();
    });
  });

  group('chi tiết ca', () {
    testWidgets('tổng quan nêu kết luận, banner thiếu công thức và xu hướng',
        (tester) async {
      await _pumpDetail(tester, _lanReport());

      expect(find.text('Ca của Lan'), findsOneWidget);
      expect(find.text('Đóng ca bởi Lan'), findsOneWidget);
      expect(
        find.text('Tiền đầu ca lệch 2.000đ so với cuối ca trước.'),
        findsOneWidget,
      );
      expect(find.text('≈99.000đ'), findsOneWidget);
      expect(
        find.text('3 món chưa có công thức, đối soát chưa đầy đủ'),
        findsOneWidget,
      );
      expect(find.text('Xem món'), findsOneWidget);
      expect(find.text('Sữa tươi lệch 3 ca liên tiếp'), findsOneWidget);
      expect(find.text('Ghi chú & xử lý'), findsOneWidget);
    });

    testWidgets('tab Tiền mặt có thu chi, chuyển khoản và bill hủy',
        (tester) async {
      await _pumpDetail(tester, _lanReport());
      await tester.tap(find.text('Tiền mặt').first);
      await tester.pumpAndSettle();

      expect(find.text('Thiếu 35.000đ'), findsOneWidget);
      expect(find.text('Chuyển khoản trong ca'), findsOneWidget);
      expect(find.text('Mua đá'), findsOneWidget);
      expect(find.text('Đổi tiền lẻ'), findsOneWidget);
      expect(find.text('Lấy ra'), findsOneWidget);
      expect(find.text('Bỏ vào'), findsOneWidget);
      expect(find.text('2 bill đã thu rồi hủy · 240.000đ'), findsOneWidget);
      expect(find.text('Lệch 2.000đ so với cuối ca trước'), findsOneWidget);
    });

    testWidgets('phiếu tiền mặt là trang đầy đủ, quay lại về tab Tiền mặt',
        (tester) async {
      await _pumpDetail(tester, _lanReport());
      await tester.tap(find.text('Tiền mặt').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem phiếu tiền mặt'));
      await tester.pumpAndSettle();

      expect(find.text('Phiếu tiền mặt'), findsOneWidget);
      expect(find.text('+ Bán tiền mặt'), findsOneWidget);
      expect(find.text('+ Bỏ vào'), findsOneWidget);
      expect(find.text('− Lấy ra'), findsOneWidget);
      expect(find.text('Đáng ra có'), findsOneWidget);
      expect(find.text('Chênh lệch cần xem lại'), findsOneWidget);
      expect(find.text('Lệch 2.000đ so với cuối ca trước'), findsOneWidget);
      expect(find.text('Đóng ca bởi Lan'), findsOneWidget);

      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Phiếu tiền mặt'), findsNothing);
      expect(find.text('Xem phiếu tiền mặt'), findsOneWidget);
    });

    testWidgets('Xem bill mở danh sách bill đã thu rồi hủy', (tester) async {
      await _pumpDetail(tester, _lanReport());
      await tester.tap(find.text('Tiền mặt').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem bill'));
      await tester.pumpAndSettle();

      expect(find.text('Bill đã thu rồi hủy'), findsOneWidget);
      expect(find.text('Bill #41'), findsOneWidget);
      expect(find.text('Lý do: Khách đổi ý'), findsOneWidget);
      expect(find.text('Hủy bởi Lan · Duyệt bởi Chủ quán'), findsOneWidget);
    });

    testWidgets('tab Nguyên liệu nói Hụt và mở phiếu nguyên liệu',
        (tester) async {
      await _pumpDetail(tester, _lanReport());
      await tester.tap(find.text('Sữa tươi').first);
      await tester.pumpAndSettle();

      expect(find.text('Hụt 120 ml'), findsOneWidget);
      expect(find.text('Quan trọng'), findsWidgets);
      expect(find.text('Doanh thu ước tính bị hụt'), findsOneWidget);

      await tester.tap(find.text('Xem cách tính Sữa tươi'));
      await tester.pumpAndSettle();
      expect(find.text('Tồn đầu'), findsOneWidget);
      expect(find.text('Sau điều chỉnh'), findsOneWidget);
      expect(find.text('1.240 ml'), findsOneWidget);
      expect(find.text('Lệch 3 ca liên tiếp'), findsOneWidget);
      expect(find.text('Đóng ca bởi Lan'), findsOneWidget);

      await tester.tap(find.byTooltip('Quay lại'));
      await tester.pumpAndSettle();
      expect(find.text('Xem cách tính Sữa tươi'), findsOneWidget);
    });

    testWidgets('tab Hao hụt giải thích không trừ hai lần', (tester) async {
      await _pumpDetail(tester, _lanReport());
      await tester.tap(find.text('Hao hụt').first);
      await tester.pumpAndSettle();

      expect(find.text('Hao hụt đã ghi nhận'), findsOneWidget);
      expect(find.text('Làm sai, đổ ly'), findsOneWidget);
      expect(find.text('Không trừ hao hụt hai lần'), findsOneWidget);
      expect(find.text('Từng lần ghi'), findsOneWidget);
      expect(find.textContaining('Ghi bởi Minh'), findsOneWidget);
      expect(find.text('Đổ nhầm ly'), findsOneWidget);
    });

    testWidgets('nguyên liệu thiếu kiểm kê được nêu rõ, không báo lỗi',
        (tester) async {
      const source = OwnerShiftReport(
        shift: {
          'id': 'shift-ha',
          'opened_at': '2026-10-28T00:00:00.000Z',
          'closed_at': '2026-10-28T03:30:00.000Z',
          'opened_by_name': 'Hà',
        },
        report: {
          'summary': {'overall': 'ok'},
          'ingredients': [
            {'ingredient_name': 'Matcha', 'unit': 'g', 'status': 'no_data'},
          ],
          'cash': {
            'status': 'ok',
            'opening_cash': 500000,
            'expected_cash': 720000,
            'closing_cash': 720000,
            'variance': 0,
          },
        },
        review: {},
      );
      await _pumpDetail(tester, source);

      expect(
        find.text(
            '1 nguyên liệu chưa đối soát vì thiếu kiểm kê đầu ca hoặc cuối ca.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('lưu ghi chú gọi onSaveReview và đổi nhãn đã xử lý',
        (tester) async {
      final saved = <(bool, String)>[];
      await _pumpDetail(tester, _lanReport(), onSave: (handled, note) async {
        saved.add((handled, note));
        return true;
      });
      expect(find.text('Chưa xử lý'), findsOneWidget);

      await tester.tap(find.text('Ghi chú & xử lý'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Đã hỏi Lan');
      await tester.pump();
      await tester.tap(find.text('Đánh dấu đã xử lý'));
      await tester.pumpAndSettle();

      expect(saved, [(true, 'Đã hỏi Lan')]);
      expect(find.text('Đã xử lý'), findsOneWidget);
    });

    testWidgets('chủ sửa số lượng hao hụt kèm lý do', (tester) async {
      final calls = <(CorrectionKind, String, int, String)>[];
      await _pumpDetail(tester, _lanReport(), onCorrect: (kind, id, qty, why) async {
        calls.add((kind, id, qty, why));
        return true;
      });
      await tester.tap(find.text('Hao hụt').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sửa số lượng'));
      await tester.pumpAndSettle();

      // số lượng chưa đổi và chưa có lý do thì không lưu
      await tester.tap(find.text('Lưu số lượng mới'));
      await tester.pumpAndSettle();
      expect(find.text('Số lượng chưa thay đổi.'), findsOneWidget);
      expect(calls, isEmpty);

      await tester.enterText(find.byType(TextField).first, '15');
      await tester.tap(find.text('Lưu số lượng mới'));
      await tester.pumpAndSettle();
      expect(find.text('Hãy nhập lý do sửa.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Đếm lại ly đổ');
      await tester.tap(find.text('Lưu số lượng mới'));
      await tester.pumpAndSettle();
      expect(calls, [(CorrectionKind.waste, 'waste-1', 15, 'Đếm lại ly đổ')]);
      expect(find.text('Lưu số lượng mới'), findsNothing);
    });

    testWidgets('phiếu nguyên liệu có phiếu nhập và sửa được số lượng nhập',
        (tester) async {
      final calls = <(CorrectionKind, String, int, String)>[];
      await _pumpDetail(tester, _lanReport(), onCorrect: (kind, id, qty, why) async {
        calls.add((kind, id, qty, why));
        return false;
      });
      await tester.tap(find.text('Sữa tươi').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem cách tính Sữa tươi'));
      await tester.pumpAndSettle();

      expect(find.text('Phiếu nhập trong ca'), findsOneWidget);
      expect(find.text('Đã sửa từ 1.200 ml'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Sửa số lượng nhập'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Sửa số lượng nhập'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '900');
      await tester.enterText(find.byType(TextField).last, 'Nhập nhầm số');
      await tester.tap(find.text('Lưu số lượng mới'));
      await tester.pumpAndSettle();

      expect(calls.single.$1, CorrectionKind.purchase);
      expect(calls.single.$2, 'purchase-1');
      // database từ chối: sheet vẫn mở và báo lỗi tại chỗ
      expect(find.text('Chưa lưu được. Hãy kiểm tra kết nối và thử lại.'),
          findsOneWidget);
    });

    testWidgets('không có onCorrect thì không hiện nút sửa', (tester) async {
      await _pumpDetail(tester, _lanReport());
      await tester.tap(find.text('Hao hụt').first);
      await tester.pumpAndSettle();
      expect(find.text('Sửa số lượng'), findsNothing);
    });
  });
}
