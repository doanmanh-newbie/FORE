import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/application/staff_login_controller.dart';
import 'package:fore/features/auth/presentation/staff_login_panel.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  testWidgets('employee login requests then verifies a six-digit code',
      (tester) async {
    final repo = FakeAuthRepository()
      ..staffAccounts.add('+84901234567');
    final controller = StaffLoginController(
      repo,
      resendDelay: Duration.zero,
    );
    var enteredApp = false;

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<StaffLoginController>.value(value: controller),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StaffLoginPanel(
                onSignedIn: () async => enteredApp = true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, '0901 234 567');
    await tester.tap(find.text('Gửi mã đăng nhập'));
    await tester.pumpAndSettle();
    expect(find.text('Mã xác nhận'), findsOneWidget);
    expect(enteredApp, isFalse);

    await tester.enterText(find.byType(TextField).last, '123456');
    await tester.tap(find.text('Xác nhận mã'));
    await tester.pumpAndSettle();
    expect(enteredApp, isTrue);
  });
}
