import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/widgets/adaptive_nav.dart';

Widget _host({
  required List<int> selected,
  bool disableAnimations = false,
  Size size = const Size(400, 800),
}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: disableAnimations,
          size: size,
        ),
        child: child!,
      ),
      home: AdaptiveNavScaffold(
        items: const [
          AdaptiveNavItem(label: 'Tổng quan', icon: Icon(Icons.home)),
          AdaptiveNavItem(label: 'Kho', icon: Icon(Icons.inventory_2)),
          AdaptiveNavItem(
              label: 'Đóng ca', icon: Icon(Icons.lock), enabled: false),
        ],
        selected: 0,
        onSelect: selected.add,
        body: const SizedBox.expand(),
      ),
    );

void main() {
  testWidgets('chọn tab đang hoạt động gọi callback đúng chỉ số',
      (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(selected: selected));

    await tester.tap(find.text('Kho'));
    await tester.pumpAndSettle();

    expect(selected, [1]);
  });

  testWidgets('tab bị khóa không gọi callback và vẫn được đọc', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(_host(selected: selected));

    await tester.tap(find.text('Đóng ca'));
    await tester.pump();

    expect(selected, isEmpty);
    // NavigationBar đọc kèm vị trí tab, nên khớp theo chứa.
    expect(find.bySemanticsLabel(RegExp('Đóng ca')), findsOneWidget);
  });

  testWidgets('tôn trọng cài đặt giảm chuyển động', (tester) async {
    await tester.pumpWidget(_host(selected: [], disableAnimations: true));

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.animationDuration, Duration.zero);
  });

  testWidgets('màn rộng (máy tính bảng) dùng rail bên trái', (tester) async {
    final selected = <int>[];
    await tester.pumpWidget(
        _host(selected: selected, size: const Size(1024, 768)));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.text('Kho'));
    await tester.pumpAndSettle();
    expect(selected, [1]);
  });
}
