import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/core/push/push_message_listener.dart';
import 'package:fore/core/push/push_notification_service.dart';
import 'package:fore/core/push/push_registration_controller.dart';
import 'package:provider/provider.dart';

import '../support/fake_push_notification_service.dart';
import '../support/fakes.dart';

/// Cho các microtask / stream chạy xong.
Future<void> flush() => Future<void>.delayed(Duration.zero);

void main() {
  late FakePushNotificationService push;
  late FakeRpcClient rpc;
  late PushRegistrationController c;

  List<Map<String, dynamic>?> callsTo(String fn) => [
        for (final x in rpc.calls)
          if (x.fn == fn) x.params
      ];

  setUp(() {
    push = FakePushNotificationService();
    rpc = FakeRpcClient(
        {'register_fcm_token': null, 'unregister_fcm_token': null});
    c = PushRegistrationController(push, RpcPushTokenRepository(rpc));
  });

  tearDown(() => c.dispose());

  group('đăng ký token', () {
    test('chủ quán đăng nhập: xin quyền, lấy token, gọi register_fcm_token',
        () async {
      await c.bindUser('owner-1');
      await flush();
      expect(push.permissionCalls, 1);
      expect(push.registerCalls, 1);
      expect(callsTo('register_fcm_token'), [
        {
          'p_token': 'fcm-token-1-aaaaaaaaaaaaaaaaaaaaaaaa',
          'p_platform': 'android'
        }
      ]);
      expect(c.state, PushState.registered);
    });

    test('FCM cấp token mới: lưu token mới', () async {
      await c.bindUser('owner-1');
      await flush();
      push.emitToken('fcm-token-2-bbbbbbbbbbbbbbbbbbbbbbbb');
      await flush();
      expect(callsTo('register_fcm_token').last, {
        'p_token': 'fcm-token-2-bbbbbbbbbbbbbbbbbbbbbbbb',
        'p_platform': 'android'
      });
    });

    test('gọi lại với cùng người: không xin quyền / đăng ký lại', () async {
      await c.bindUser('owner-1');
      await c.bindUser('owner-1');
      await flush();
      expect(push.permissionCalls, 1);
      expect(callsTo('register_fcm_token'), hasLength(1));
    });
  });

  group('xin quyền sau màn giải thích', () {
    test('chưa có quyền: không tự hỏi khi đăng nhập; bấm Bật thì hỏi và đăng ký',
        () async {
      var granted = false;
      final gated = PushRegistrationController(
        push,
        RpcPushTokenRepository(rpc),
        isPermissionGranted: () async => granted,
      );
      addTearDown(gated.dispose);

      await gated.bindUser('owner-1');
      await flush();
      expect(gated.state, PushState.awaitingPermission);
      expect(push.permissionCalls, 0);
      expect(callsTo('register_fcm_token'), isEmpty);

      granted = true;
      expect(await gated.enable(), isTrue);
      await flush();
      expect(push.permissionCalls, 1);
      expect(gated.state, PushState.registered);
      expect(callsTo('register_fcm_token'), hasLength(1));
    });
  });

  group('an toàn khi thiếu cấu hình / lỗi', () {
    test(
        'chưa có google-services.json: tắt push, không gọi server, không crash',
        () async {
      push.configured = false;
      await c.bindUser('owner-1');
      await flush();
      expect(c.state, PushState.unavailable);
      expect(push.permissionCalls, 0);
      expect(rpc.calls, isEmpty);
    });

    test('Firebase.initializeApp() ném lỗi: cũng chỉ tắt push', () async {
      push.initError = StateError('No Firebase App has been created');
      await expectLater(c.bindUser('owner-1'), completes);
      expect(c.state, PushState.unavailable);
    });

    test('người dùng từ chối quyền thông báo: không đăng ký', () async {
      push.permissionGranted = false;
      await c.bindUser('owner-1');
      await flush();
      expect(c.state, PushState.denied);
      expect(push.registerCalls, 0);
      expect(rpc.calls, isEmpty);
    });

    test('lưu token lỗi mạng: trạng thái failed, không ném ra ngoài', () async {
      rpc = FakeRpcClient({'register_fcm_token': const NoNetworkFailure()});
      c.dispose();
      c = PushRegistrationController(push, RpcPushTokenRepository(rpc));
      await c.bindUser('owner-1');
      await flush();
      expect(c.state, PushState.failed);
    });
  });

  group('đăng xuất / đổi tài khoản', () {
    test('đăng xuất: gỡ token khỏi tài khoản và hủy đăng ký trên máy',
        () async {
      await c.bindUser('owner-1');
      await flush();
      await c.bindUser(null);
      expect(callsTo('unregister_fcm_token'), [
        {'p_token': 'fcm-token-1-aaaaaaaaaaaaaaaaaaaaaaaa'}
      ]);
      expect(push.unregisterCalls, 1);
      expect(c.state, PushState.idle);

      // Token đến muộn từ phiên cũ: bỏ qua, không gắn vào ai.
      push.emitToken('fcm-token-cu-cccccccccccccccccccccc');
      await flush();
      expect(callsTo('register_fcm_token'), hasLength(1));
    });

    test('gỡ token lỗi (đã mất phiên): vẫn hủy đăng ký trên máy, không ném',
        () async {
      rpc = FakeRpcClient({
        'register_fcm_token': null,
        'unregister_fcm_token': const SessionExpiredFailure(),
      });
      c.dispose();
      c = PushRegistrationController(push, RpcPushTokenRepository(rpc));
      await c.bindUser('owner-1');
      await flush();
      await expectLater(c.bindUser(null), completes);
      expect(push.unregisterCalls, 1);
    });

    test(
        'đổi sang chủ khác trên cùng máy: gỡ của người cũ, đăng ký cho người mới',
        () async {
      await c.bindUser('owner-1');
      await flush();
      push.tokenOnRegister = 'fcm-token-moi-dddddddddddddddddddddd';
      await c.bindUser('owner-2');
      await flush();
      expect(callsTo('unregister_fcm_token'), hasLength(1));
      expect(callsTo('register_fcm_token').last?['p_token'],
          'fcm-token-moi-dddddddddddddddddddddd');
      expect(c.state, PushState.registered);
    });

    test('chưa từng đăng ký mà đăng xuất: không gọi gỡ', () async {
      await c.bindUser(null);
      expect(rpc.calls, isEmpty);
      expect(push.unregisterCalls, 0);
    });
  });

  group('thông báo khi app đang mở', () {
    test('chuyển thông báo foreground ra luồng messages', () async {
      final got = <PushMessage>[];
      c.messages.listen(got.add);
      await c.bindUser('owner-1');
      push.emitMessage(
          const PushMessage(title: 'Ca vừa đóng', body: 'Lan đã đóng ca.'));
      await flush();
      expect(got.single.title, 'Ca vừa đóng');
    });

    testWidgets('PushMessageListener hiện thanh báo', (tester) async {
      await tester
          .pumpWidget(ChangeNotifierProvider<PushRegistrationController>.value(
        value: c,
        child: MaterialApp(
          builder: (context, child) => PushMessageListener(child: child!),
          home: const Scaffold(body: Text('TRANG')),
        ),
      ));
      await c.bindUser('owner-1');
      push.emitMessage(const PushMessage(
          title: 'Bill đã thu bị hủy',
          body: 'Bill #12 bị hủy',
          data: {'bill_id': 'b12'}));
      await tester.pump();
      await tester.pump();
      expect(find.text('Bill đã thu bị hủy: Bill #12 bị hủy'), findsOneWidget);
      // Tránh dispose c 2 lần (tearDown) khi provider gỡ widget.
      await tester.pumpWidget(const SizedBox());
    });
  });

  test('NoopPushNotificationService: không có push, không lỗi', () async {
    const noop = NoopPushNotificationService();
    expect(await noop.init(), isFalse);
    await noop.registerDevice();
    await noop.unregisterDevice();
    expect(await noop.onToken.isEmpty, isTrue);
  });
}
