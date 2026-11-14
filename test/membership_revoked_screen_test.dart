import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/auth/presentation/membership_revoked_screen.dart';

import 'support/fake_auth_repository.dart';

void main() {
  testWidgets('mất membership có thông báo, retry và lỗi tải lại rõ ràng',
      (tester) async {
    final repository = FakeAuthRepository()
      ..user = const AuthUser(
        id: 'staff-1',
        phone: '84901234567',
        accountKind: AccountKind.staff,
      )
      ..rememberedShopId = 'shop-removed';
    final session = SessionController(
      repository,
      minVisible: Duration.zero,
    );
    await tester.runAsync(() => session.restore(skipMinWait: true));
    repository.failure = const NoNetworkFailure();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: session,
        child: const MaterialApp(home: MembershipRevokedScreen()),
      ),
    );

    expect(find.text('Quyền vào quán đã thay đổi'), findsOneWidget);
    expect(find.textContaining('+84901234567'), findsOneWidget);
    expect(find.text('Kiểm tra lại'), findsOneWidget);
    expect(find.text('Đăng xuất'), findsOneWidget);

    await tester.tap(find.text('Kiểm tra lại'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Không có mạng. Kiểm tra kết nối rồi thử lại.'),
        findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    session.dispose();
  });
}
