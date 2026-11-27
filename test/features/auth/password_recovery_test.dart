import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/domain/auth_repository.dart';
import 'package:fore/features/auth/presentation/password_recovery_listener.dart';
import 'package:provider/provider.dart';

import '../../support/fake_auth_repository.dart';

void main() {
  testWidgets('mở từ link đặt lại mật khẩu: hiện hộp thoại và lưu mật khẩu mới',
      (tester) async {
    final repo = FakeAuthRepository();
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(Provider<AuthRepository>.value(
      value: repo,
      child: MaterialApp(
        navigatorKey: key,
        builder: (context, child) =>
            PasswordRecoveryListener(navigatorKey: key, child: child!),
        home: const Scaffold(body: Text('Trang chủ')),
      ),
    ));

    repo.emitPasswordRecovery();
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();
    expect(find.text('Đặt mật khẩu mới'), findsOneWidget);

    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(0), 'matkhaumoi1');
    await tester.enterText(fields.at(1), 'khac12345');
    await tester.tap(find.text('Lưu mật khẩu'));
    await tester.pump();
    expect(find.text('Hai mật khẩu chưa khớp.'), findsOneWidget);
    expect(repo.updatedPassword, isNull);

    await tester.enterText(fields.at(1), 'matkhaumoi1');
    await tester.tap(find.text('Lưu mật khẩu'));
    await tester.pumpAndSettle();
    expect(repo.updatedPassword, 'matkhaumoi1');
    expect(find.text('Đặt mật khẩu mới'), findsNothing);
  });
}
