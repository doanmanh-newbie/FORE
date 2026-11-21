import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/admin_app.dart';
import 'package:fore/admin/data/fake_admin_repositories.dart';
import 'package:fore/admin/domain/admin_models.dart';
import 'package:fore/admin/presentation/admin_login_screen.dart';
import 'package:fore/core/errors/app_failure.dart';

import 'admin_test_helpers.dart';

void main() {
  group('AdminLoginScreen', () {
    testWidgets('shows loading state while signing in and calls onSignedIn for super-admin',
        (tester) async {
      final auth = FakeAdminAuthRepository(
        delay: const Duration(milliseconds: 120),
      );
      AdminIdentity? signedIn;

      await pumpAdminScreen(
        tester,
        AdminLoginScreen(
          authRepository: auth,
          onSignedIn: (id) => signedIn = id,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('admin_email_field')),
        'admin@fore.vn',
      );
      await tester.enterText(
        find.byKey(const Key('admin_password_field')),
        'admin1234',
      );
      await tester.tap(find.byKey(const Key('admin_login_submit')));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
      expect(signedIn?.email, 'admin@fore.vn');
      expect(find.byKey(const Key('admin_login_error_banner')), findsNothing);
    });

    testWidgets('rejects non-admin account with FORBIDDEN message and signs out',
        (tester) async {
      final auth = FakeAdminAuthRepository();
      AdminIdentity? signedIn;

      await pumpAdminScreen(
        tester,
        AdminLoginScreen(
          authRepository: auth,
          onSignedIn: (id) => signedIn = id,
        ),
      );

      await tester.enterText(
        find.byKey(const Key('admin_email_field')),
        'user@fore.vn',
      );
      await tester.enterText(
        find.byKey(const Key('admin_password_field')),
        'user1234',
      );
      await tester.tap(find.byKey(const Key('admin_login_submit')));
      await tester.pumpAndSettle();

      expect(signedIn, isNull);
      expect(auth.signOutCount, 1);
      expect(find.byKey(const Key('admin_login_error_banner')), findsOneWidget);
      expect(find.textContaining('super-admin'), findsWidgets);
    });

    testWidgets('shows error banner on network failure', (tester) async {
      final auth = FakeAdminAuthRepository(
        signInFailure: const NoNetworkFailure(),
      );

      await pumpAdminScreen(
        tester,
        AdminLoginScreen(
          authRepository: auth,
          onSignedIn: (_) {},
        ),
      );

      await tester.enterText(
        find.byKey(const Key('admin_email_field')),
        'admin@fore.vn',
      );
      await tester.enterText(
        find.byKey(const Key('admin_password_field')),
        'admin1234',
      );
      await tester.tap(find.byKey(const Key('admin_login_submit')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Không có mạng'), findsOneWidget);
    });

    testWidgets('ForeAdminApp navigates into AdminShell after super-admin login and signs out cleanly',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ForeAdminApp(dependencies: AdminDependencies.fake()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập Admin'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('admin_email_field')),
        'admin@fore.vn',
      );
      await tester.enterText(
        find.byKey(const Key('admin_password_field')),
        'admin1234',
      );
      await tester.tap(find.byKey(const Key('admin_login_submit')));
      await tester.pumpAndSettle();

      expect(find.text('Danh sách quán'), findsOneWidget);
      expect(find.text('Cà Phê Sân Vườn Fore'), findsOneWidget);

      await tester.tap(find.byKey(const Key('admin_sign_out_button')));
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập Admin'), findsOneWidget);
    });
  });
}
