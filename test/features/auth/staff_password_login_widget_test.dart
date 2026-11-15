import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/application/staff_login_controller.dart';
import 'package:fore/features/auth/presentation/staff_login_panel.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  testWidgets('nhân viên đăng nhập bằng số điện thoại và mật khẩu',
      (tester) async {
    final repo = FakeAuthRepository()
      ..staffAccounts['+84901234567'] = 'matkhau123';
    var enteredApp = false;

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => StaffLoginController(repo),
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StaffLoginPanel(onSignedIn: () async => enteredApp = true),
            ),
          ),
        ),
      ),
    );

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '0901 234 567');
    await tester.enterText(fields.at(1), 'matkhau123');
    await tester.tap(find.text('Đăng nhập'));
    await tester.pumpAndSettle();

    expect(enteredApp, isTrue);
    expect(find.text('Mã xác nhận'), findsNothing);
  });
}
