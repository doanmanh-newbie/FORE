import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/core/widgets/pressable_scale.dart';
import 'package:fore/features/sales/presentation/bill_screen.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('đang tải bill dùng skeleton thay vì vòng xoay trơn',
      (tester) async {
    final repository = FakeSalesRepository()..menuItems = List.of(sampleMenu);
    final gate = Completer<void>();
    repository.gate = gate;

    await tester.pumpWidget(MaterialApp(
      home: BillScreen(
        repository: repository,
        billId: 'b1',
        servingLabel: 'phần',
      ),
    ));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byType(SkeletonBox), findsWidgets);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Cà phê sữa'), findsOneWidget);
  });

  testWidgets('lỗi tải bill có hướng thử lại', (tester) async {
    final repository = FakeSalesRepository()..menuItems = List.of(sampleMenu);
    repository.failNext('bill', const NoNetworkFailure());

    await tester.pumpWidget(MaterialApp(
      home: BillScreen(
        repository: repository,
        billId: 'b1',
        servingLabel: 'phần',
      ),
    ));
    await tester.pumpAndSettle();

    expect(
      find.text('Không có mạng. Kiểm tra kết nối rồi thử lại.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Cà phê sữa'), findsOneWidget);
  });

  testWidgets('nhân viên thêm món rồi xem bill', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = FakeSalesRepository()..menuItems = List.of(sampleMenu);

    await tester.pumpWidget(MaterialApp(
      home: BillScreen(
        repository: repository,
        billId: 'b1',
        servingLabel: 'phần',
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cà phê sữa'), findsOneWidget);
    expect(find.text('Chọn món để bắt đầu'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Tăng').first);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Thêm 1 phần'));
    await tester.pumpAndSettle();

    expect(repository.calls, contains('addLine:b1:bm-1:1'));
    expect(find.text('Đã thêm 1 phần vào bill.'), findsOneWidget);
    await tester.tap(find.textContaining('Bill (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Bánh mì trứng'), findsOneWidget);
    expect(find.text('Phải thu (1 phần)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('màn bill vừa màn 360px ở cỡ chữ $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repository = FakeSalesRepository()..menuItems = List.of(sampleMenu);

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: BillScreen(
            repository: repository,
            billId: 'b1',
            servingLabel: 'phần',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('PressableScale tắt animation khi hệ thống giảm chuyển động',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const Scaffold(
          body: PressableScale(child: Text('Nút kiểm tra')),
        ),
      ),
    );

    final animation = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(animation.duration, Duration.zero);
  });
}
