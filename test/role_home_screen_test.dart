import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fore/app/app_routes.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/home/role_home_screen.dart';
import 'support/fake_auth_repository.dart';

void main() {
  test('chọn không gian chủ/nhân viên theo vai trò trong hồ sơ', () {
    expect(RoleHomeScreen.isOwnerRole(StaffRole.owner), isTrue);
    expect(RoleHomeScreen.isOwnerRole(StaffRole.staff), isFalse);
  });

  testWidgets('nhân viên không được hiển thị các tab chủ quán', (tester) async {
    final auth = FakeAuthRepository()
      ..user = const AuthUser(id: 'staff-1', email: 'staff@example.test')
      ..profile = const Profile(
        staffId: 'staff-1',
        fullName: 'Nhân viên QA',
        role: StaffRole.staff,
        hasPin: false,
        active: true,
      );
    final session = SessionController(auth, minVisible: Duration.zero);
    await tester.runAsync(session.refreshAfterSignIn);

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: MaterialApp(
          home: RoleHomeScreen(
            staffHomeBuilder: (_) =>
                const Scaffold(body: Text('Giao diện nhân viên')),
          ),
        ),
      ),
    );

    expect(find.text('Giao diện nhân viên'), findsOneWidget);
    for (final label in ['Tổng quan', 'Đối soát', 'Thực đơn', 'Kho', 'Thêm']) {
      expect(find.text(label), findsNothing);
    }

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  testWidgets(
      'deep link trang chủ tự khôi phục phiên và có thể thử lại khi offline',
      (tester) async {
    final auth = FakeAuthRepository()
      ..user = const AuthUser(
        id: 'staff-1',
        email: 'staff@example.test',
        accountKind: AccountKind.staff,
      )
      ..profile = const Profile(
        staffId: 'staff-1',
        fullName: 'Nhân viên QA',
        role: StaffRole.staff,
        hasPin: false,
        active: true,
      )
      ..failure = const NoNetworkFailure();
    final session = SessionController(auth, minVisible: Duration.zero);

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: MaterialApp(
          home: RoleHomeScreen(
            staffHomeBuilder: (_) =>
                const Scaffold(body: Text('Giao diện nhân viên')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Chưa kết nối được với Fore'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    auth.failure = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Giao diện nhân viên'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });

  testWidgets('deep link trang chủ khi chưa đăng nhập chuyển về Welcome',
      (tester) async {
    final session =
        SessionController(FakeAuthRepository(), minVisible: Duration.zero);
    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: MaterialApp(
          home: const RoleHomeScreen(),
          routes: {
            AppRoutes.welcome: (_) =>
                const Scaffold(body: Text('Màn hình chào mừng')),
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Màn hình chào mừng'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
