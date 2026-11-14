import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/shift/operations/application/ops_shift_controller.dart';
import 'package:fore/features/shift/operations/presentation/no_shift_view.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('nhắc kiểm kê đầu ca sau khi mở và cho phép đếm ngay',
      (tester) async {
    final shift = OpsShiftController(FakeShiftRepository());
    var countOpeningCalls = 0;
    await shift.load();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoShiftView(
          shift: shift,
          onCountOpening: () => countOpeningCalls++,
        ),
      ),
    ));

    await tester.tap(find.text('Mở ca').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100000');
    await tester.pumpAndSettle();
    final confirmOpening = find.descendant(
      of: find.byType(BottomSheet),
      matching: find.widgetWithText(FilledButton, 'Mở ca'),
    );
    expect(confirmOpening, findsOneWidget);
    expect(tester.widget<FilledButton>(confirmOpening).onPressed, isNotNull);
    await tester.tap(confirmOpening);
    await tester.pumpAndSettle();

    expect(shift.hasOpenShift, isTrue,
        reason: 'Nút xác nhận trong sheet phải mở ca trước khi hỏi kiểm kê.');
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Kiểm kê đầu ca'),
      ),
      findsOneWidget,
    );
    expect(find.text('Đếm ngay'), findsOneWidget);
    expect(find.text('Để sau'), findsOneWidget);
    await tester.tap(find.text('Đếm ngay'));
    await tester.pumpAndSettle();
    expect(countOpeningCalls, 1);
    shift.dispose();
  });
}
