import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/widgets/page_scaffold.dart';

void main() {
  testWidgets('PageScaffold cuộn được và chỉ dựng dòng đang hiện', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          Expanded(
            child: PageScaffold(
              header: const Text('Đầu trang'),
              children: [
                for (var i = 0; i < 40; i++)
                  SizedBox(height: 80, child: Text('dòng $i')),
              ],
            ),
          ),
          const SizedBox(height: 56, child: Text('thanh đáy')),
        ]),
      ),
    ));

    expect(find.text('dòng 0'), findsOneWidget);
    expect(find.text('dòng 39'), findsNothing, reason: 'chưa tới, chưa dựng');

    await tester.scrollUntilVisible(
      find.text('dòng 39'),
      200,
      scrollable: find.byType(Scrollable),
    );
    await tester.pumpAndSettle();

    expect(find.text('dòng 39'), findsOneWidget);
    expect(find.text('thanh đáy'), findsOneWidget);
  });
}
