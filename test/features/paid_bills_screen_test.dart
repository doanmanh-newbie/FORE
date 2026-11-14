import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/sales/domain/sales_models.dart';
import 'package:fore/features/sales/presentation/paid_bills_screen.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('hủy bill đã thu: nhập lý do + PIN chủ thì bill biến mất',
      (tester) async {
    final repo = FakeSalesRepository()
      ..paid = [
        PaidBill(
            billId: 'b9',
            billNo: 9,
            paidAt: DateTime(2026, 11, 14, 9, 30),
            total: 58000,
            method: 'cash',
            tableName: 'Bàn 1'),
      ];
    await tester
        .pumpWidget(MaterialApp(home: PaidBillsScreen(repository: repo)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hủy bill'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Thu nhầm bàn');
    await tester.pump();
    await tester.tap(find.text('Tiếp tục'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1234');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Hủy bill'));
    await tester.pumpAndSettle();

    expect(repo.calls, contains('cancelPaidBill:b9:1234:Thu nhầm bàn'));
    expect(find.text('Chưa có bill nào'), findsOneWidget);
  });
}
