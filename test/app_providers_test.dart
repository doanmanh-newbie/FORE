// Dựng cây widget gốc ForeApp với ĐỦ các phần phụ của app thật (push, realtime, telemetry,
// cấu hình từ xa) để bắt lỗi thứ tự provider. Lỗi đã gặp: provider push đọc SessionController
// nhưng lại nằm TRÊN nó -> ProviderNotFoundException ngay lúc khởi động.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/app/app.dart';
import 'package:fore/core/push/push_registration_controller.dart';
import 'package:fore/core/remote_config/app_config_repository.dart';
import 'package:fore/core/telemetry/telemetry_repository.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:provider/provider.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_live_feed.dart';
import 'support/fake_push_notification_service.dart';
import 'support/fake_shift_repository.dart';
import 'support/fake_shop_repository.dart';
import 'support/fakes.dart' show FakeRpcClient;

Profile _profile(StaffRole role) => Profile(
      staffId: 's1',
      fullName: 'Nguyễn An',
      role: role,
      hasPin: false,
      active: true,
      shopId: 'shop-1',
      shopName: 'Quán A',
    );

class _App {
  final auth = FakeAuthRepository();
  final push = FakePushNotificationService();
  final rpc =
      FakeRpcClient({'register_fcm_token': null, 'unregister_fcm_token': null});
  late final PushRegistrationController pushController =
      PushRegistrationController(push, RpcPushTokenRepository(rpc));

  Widget build() => ForeApp(
        authRepository: auth,
        shiftRepository: FakeShiftRepository(),
        shopRepository: FakeShopRepository(),
        telemetryRepository: const NoopTelemetryRepository(),
        appConfigRepository: const StaticAppConfigRepository(),
        liveFeed: FakeLiveFeed(),
        pushController: pushController,
      );
}

void main() {
  testWidgets(
      'khởi động với đủ provider (push, realtime...): không lỗi provider',
      (tester) async {
    final app = _App();
    await tester.pumpWidget(app.build());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(ForeApp), findsOneWidget);

    // Chưa đăng nhập: không xin quyền thông báo.
    await tester.pump(const Duration(milliseconds: 200));
    expect(app.push.permissionCalls, 0);
    expect(app.pushController.state, PushState.idle);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  /// Khởi động khi chưa đăng nhập (dừng ở màn chào), rồi giả lập đăng nhập bằng cách khôi phục
  /// phiên qua đúng SessionController của cây provider. (Không đi qua màn mở đầu khi đã đăng nhập
  /// vì màn chính cần Supabase thật.)
  Future<void> signInThroughAppTree(
      WidgetTester tester, _App app, StaffRole role, String userId) async {
    await tester.pumpWidget(app.build());
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    final session = Provider.of<SessionController>(
        tester.element(find.byType(Navigator)),
        listen: false);
    app.auth
      ..user = AuthUser(
          id: userId,
          email: '$userId@quan.vn',
          accountKind:
              role == StaffRole.owner ? AccountKind.owner : AccountKind.staff)
      ..profile = _profile(role);
    await session.restore(skipMinWait: true);
    expect(session.state, isA<SessionReady>());
    await tester.pump();
    await tester.pump();
  }

  testWidgets(
      'chủ quán đăng nhập: provider push đọc được phiên và đăng ký token',
      (tester) async {
    final app = _App();
    await signInThroughAppTree(tester, app, StaffRole.owner, 'u-owner');
    expect(tester.takeException(), isNull);
    expect(app.push.permissionCalls, 1);
    expect(app.rpc.calls.map((c) => c.fn), contains('register_fcm_token'));
    expect(app.pushController.state, PushState.registered);
  });

  testWidgets('nhân viên đăng nhập: không xin quyền thông báo', (tester) async {
    final app = _App();
    await signInThroughAppTree(tester, app, StaffRole.staff, 'u-staff');
    expect(tester.takeException(), isNull);
    expect(app.push.permissionCalls, 0);
    expect(app.rpc.calls, isEmpty);
  });
}
