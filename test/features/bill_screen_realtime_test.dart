import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/sales/presentation/bill_screen.dart';

import '../support/fakes.dart';

void main() {
  late FakeSalesRepository repo;
  late StreamController<Set<String>?> live;

  int billLoads() => repo.calls.where((c) => c == 'bill:b1').length;

  Future<void> pump(WidgetTester tester) async {
    repo = FakeSalesRepository()..menuItems = List.of(sampleMenu);
    live = StreamController<Set<String>?>.broadcast();
    addTearDown(live.close);
    await tester.pumpWidget(MaterialApp(
      home: BillScreen(
        repository: repo,
        billId: 'b1',
        servingLabel: 'phần',
        liveUpdates: live.stream,
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('bill này đổi ở máy khác: tải lại; bill khác đổi: bỏ qua',
      (tester) async {
    await pump(tester);
    final before = billLoads();

    live.add({'b-khac'});
    await tester.pumpAndSettle();
    expect(billLoads(), before);

    live.add({'b1', 'b-khac'});
    await tester.pumpAndSettle();
    expect(billLoads(), before + 1);

    live.add(null); // vừa kết nối lại: tải lại mọi bill
    await tester.pumpAndSettle();
    expect(billLoads(), before + 2);
  });

  testWidgets('tải lại theo realtime bị lỗi mạng: giữ giao diện, không crash',
      (tester) async {
    await pump(tester);
    repo.failNext('bill', const NoNetworkFailure());
    live.add({'b1'});
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Cà phê sữa'), findsWidgets);
  });

  testWidgets('đóng màn bill: gỡ lắng nghe', (tester) async {
    await pump(tester);
    expect(live.hasListener, isTrue);
    await tester.pumpWidget(const SizedBox());
    expect(live.hasListener, isFalse);
  });
}
