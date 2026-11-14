import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/widgets/content_width.dart';

void main() {
  testWidgets('ôm chiều cao của con khi đặt ở thanh đáy, giới hạn bề rộng',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Text('nội dung'),
        bottomNavigationBar: ContentWidth(
          child: SizedBox(height: 56, child: Placeholder()),
        ),
      ),
    ));

    final bar = tester.getSize(find.byType(ContentWidth));
    expect(bar.height, 56, reason: 'không được chiếm hết màn hình');
    expect(tester.getSize(find.byType(Placeholder)).width, 720);
    expect(find.text('nội dung'), findsOneWidget);
  });
}
