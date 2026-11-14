import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/design/gallery_screen.dart';
import 'package:fore/core/design/typography.dart';

void main() {
  test('kiểu chữ dùng font offline và chữ số tabular', () {
    expect(AppFonts.display, 'ForeNewsreader');
    expect(AppFonts.body, 'ForeInter');
    expect(AppTextStyles.kpi.fontFeatures, isNotEmpty);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('gallery không lỗi layout ở cỡ chữ $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const MaterialApp(home: DesignGalleryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thư viện giao diện'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
