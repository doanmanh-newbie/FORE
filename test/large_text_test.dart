import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/widgets/adaptive_nav.dart';
import 'package:fore/core/widgets/fore_segmented.dart';
import 'package:fore/core/widgets/status_chip.dart';

/// Điện thoại hẹp (360 dp) với cỡ chữ hệ thống gấp đôi: không thành phần nào được tràn.
Widget _host(Widget child) => MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(360, 720),
          textScaler: const TextScaler.linear(2),
        ),
        child: c!,
      ),
      home: Scaffold(
        body: Center(child: SizedBox(width: 328, child: child)),
      ),
    );

void main() {
  testWidgets('thanh phân đoạn không tràn khi chữ to', (tester) async {
    await tester.pumpWidget(_host(ForeSegmented(
      labels: const ['Số điện thoại', 'Email'],
      selected: 0,
      onChanged: (_) {},
    )));
    expect(tester.takeException(), isNull);
  });

  testWidgets('chip trạng thái cắt chữ thay vì tràn', (tester) async {
    await tester.pumpWidget(_host(const Row(children: [
      Expanded(child: Text('Sữa tươi không đường', maxLines: 1)),
      Flexible(
        child: StatusChip(
          label: 'Cần xem lại ngay',
          severity: StatusSeverity.attention,
          compact: true,
        ),
      ),
    ])));
    expect(tester.takeException(), isNull);
  });

  testWidgets('thanh điều hướng 5 tab không tràn khi chữ to', (tester) async {
    await tester.pumpWidget(MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          size: const Size(360, 720),
          textScaler: const TextScaler.linear(2),
        ),
        child: c!,
      ),
      home: AdaptiveNavScaffold(
        selected: 0,
        onSelect: (_) {},
        body: const SizedBox.expand(),
        items: const [
          AdaptiveNavItem(label: 'Tổng quan', icon: Icon(Icons.home)),
          AdaptiveNavItem(label: 'Đối soát', icon: Icon(Icons.fact_check)),
          AdaptiveNavItem(label: 'Thực đơn', icon: Icon(Icons.menu_book)),
          AdaptiveNavItem(label: 'Kho', icon: Icon(Icons.inventory_2)),
          AdaptiveNavItem(label: 'Thêm', icon: Icon(Icons.more_horiz)),
        ],
      ),
    ));
    expect(tester.takeException(), isNull);
  });
}
