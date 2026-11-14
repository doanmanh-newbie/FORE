import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/sales/application/takeaway_controller.dart';
import 'package:fore/features/sales/application/table_map_controller.dart';
import 'package:fore/features/sales/presentation/tables_view.dart';
import 'package:fore/features/sales/presentation/takeaway_view.dart';
import 'package:fore/features/shift/operations/application/ops_shift_controller.dart';
import 'package:fore/features/shift/operations/domain/ops_shift_models.dart';
import 'package:fore/features/shift/operations/presentation/close_shift_view.dart';
import 'package:fore/features/inventory/presentation/inventory_hub_view.dart';
import 'package:fore/features/more/more_view.dart';
import 'package:fore/features/stocktake/domain/stocktake_models.dart';
import 'package:fore/features/stocktake/presentation/stocktake_screen.dart';

import '../support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Giao diện Mang đi', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('không tràn ở 360x800, cỡ chữ $scale', (tester) async {
        final semantics = tester.ensureSemantics();
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = FakeSalesRepository()
          ..takeaways = [
            order('first', 101, items: 'Cà phê sữa, Trà đào, Bánh mì trứng'),
            order('second', 102),
          ];
        final controller = TakeawayController(repository);
        addTearDown(controller.dispose);
        await controller.load();

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: TakeawayView(
                    takeaway: controller,
                    servingLabel: 'phần',
                    onOpenBill: (_) async {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Đơn chưa xong'), findsOneWidget);
        expect(find.text('Chờ lâu nhất'), findsOneWidget);
        expect(
          find.byWidgetPredicate((widget) =>
              widget is Semantics &&
              widget.properties.button == true &&
              widget.properties.label == 'Mở đơn mang đi #101'),
          findsOneWidget,
        );
        semantics.dispose();
      });
    }

    testWidgets('nút Xong lưu thao tác và bỏ đơn khỏi hàng chờ',
        (tester) async {
      final repository = FakeSalesRepository()
        ..takeaways = [order('first', 101)];
      final controller = TakeawayController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TakeawayView(
            takeaway: controller,
            servingLabel: 'phần',
            onOpenBill: (_) async {},
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xong'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('markPrepDone:first'));
      expect(find.text('Không có đơn nào đang chờ'), findsOneWidget);
    });
  });

  group('Bản đồ bàn', () {
    testWidgets('không tràn ở 360x800 và mở bàn theo đúng thao tác',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final repository = FakeSalesRepository()..tables = [slot('Bàn 1')];
      final controller = TableMapController(repository);
      addTearDown(controller.dispose);
      await controller.load();
      final openedBills = <String>[];

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: Scaffold(
              body: TablesView(
                tables: controller,
                servingLabel: 'phần',
                onOpenBill: (id) async => openedBills.add(id),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Bàn 1'), findsOneWidget);
      await tester.tap(find.text('Bàn 1'));
      await tester.pumpAndSettle();
      expect(find.text('Mở bill cho bàn này. Số khách không bắt buộc.'),
          findsOneWidget);
      expect(find.byTooltip('Tăng số khách'), findsOneWidget);

      await tester.tap(find.byTooltip('Tăng số khách'));
      await tester.tap(find.text('Mở bàn'));
      await tester.pumpAndSettle();

      expect(repository.calls, contains('openBill:t-Bàn 1:dine_in:1'));
      expect(openedBills, ['b100']);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('Kho thích ứng chữ lớn và gửi đúng loại kiểm kê', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = FakeShiftRepository()
      ..shift = OpsCurrentShift(
        id: 'shift-1',
        openedAt: DateTime(2026, 10, 30, 7),
        openedByName: 'An',
        openedByMe: true,
      )
      ..status = const CloseStatus(openBills: 0, missingCounts: 2);
    final shift = OpsShiftController(repository);
    addTearDown(shift.dispose);
    await shift.load();
    await shift.loadCloseStatus();

    var purchases = 0;
    final counts = <CountKind>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: Scaffold(
            body: InventoryHubView(
              shift: shift,
              onPurchase: () => purchases++,
              onCount: counts.add,
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Còn 2'), findsOneWidget);
    await tester.tap(find.text('Nhập hàng'));
    await tester.tap(find.text('Kiểm kê đầu ca'));
    await tester.tap(find.text('Kiểm kê cuối ca'));

    expect(purchases, 1);
    expect(counts, [CountKind.open, CountKind.close]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Thêm không lộ màn chủ cho nhân viên và khóa thao tác ngoài ca',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    var inboxOpens = 0;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: Scaffold(
            body: MoreView(
              personName: 'Lan',
              roleLabel: 'Nhân viên',
              shopName: 'Quán đồ uống có tên dài để thử khả năng xuống dòng',
              hasOpenShift: false,
              isOwner: false,
              onWaste: () {},
              onCash: () {},
              onSwitchShop: () {},
              onInbox: () => inboxOpens++,
              onTeam: () {},
              onSignOut: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Nhân viên'), findsNothing);
    expect(find.text('Tài khoản'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Semantics &&
          widget.properties.label == 'Ghi hao hụt' &&
          widget.properties.enabled == false),
      findsOneWidget,
    );
    await tester.tap(find.text('Hộp thư'));

    expect(inboxOpens, 1);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('Đóng ca vừa màn 360x800, đếm mù và xác nhận hai bước',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = FakeShiftRepository()
      ..shift = OpsCurrentShift(
        id: 'shift-1',
        openedAt: DateTime(2026, 10, 30, 7),
        openedByName: 'An',
        openedByMe: true,
      );
    final shift = OpsShiftController(repository);
    addTearDown(shift.dispose);
    await shift.load();
    await shift.loadCloseStatus();

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: Scaffold(
            body: CloseShiftView(
              shift: shift,
              onViewBills: () {},
              onCountStock: () {},
            ),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tiền đếm được'), findsOneWidget);
    expect(find.textContaining('Kỳ vọng'), findsNothing);
    expect(find.textContaining('doanh thu'), findsNothing);

    await tester.enterText(find.byType(TextField), '100000');
    await tester.pump();
    expect(find.text('Xác nhận đóng ca'), findsOneWidget);
    await tester.tap(find.text('Xác nhận đóng ca'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bạn đã đếm 100.000đ'), findsOneWidget);
    expect(find.text('Kiểm tra lại'), findsOneWidget);
    await tester.tap(find.text('Kiểm tra lại'));
    await tester.pumpAndSettle();

    expect(repository.calls.where((call) => call.startsWith('closeShift')),
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  group('Giao diện kiểm kê đếm mù', () {
    for (final scale in [1.0, 1.3]) {
      testWidgets('không tràn ở 360x800, cỡ chữ $scale', (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repository = FakeStocktakeRepository()
          ..items = [
            for (var i = 0; i < 40; i++) countItem('ingredient-$i'),
            countItem('weekly', weekly: true),
          ];
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: StocktakeScreen(
                  repository: repository,
                  kind: CountKind.close,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Kiểm kê cuối ca'), findsOneWidget);
        expect(find.text('Đã đếm 0/40'), findsOneWidget);
        expect(find.text('NL ingredient-39'), findsNothing,
            reason: 'Danh sách dài cần dựng lười, không tạo sẵn mọi dòng.');
      });
    }

    testWidgets('sau khi lưu, số đếm không còn hiển thị trên màn',
        (tester) async {
      final repository = FakeStocktakeRepository()..items = [countItem('milk')];
      await tester.pumpWidget(MaterialApp(
        home: StocktakeScreen(repository: repository, kind: CountKind.close),
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '1250');
      await tester.pump();
      await tester.tap(find.text('Lưu 1 dòng'));
      await tester.pumpAndSettle();

      expect(repository.saved, ['milk=1250']);
      expect(find.text('Đã đếm'), findsOneWidget);
      expect(find.text('1250'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
