import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/core/telemetry/error_reporter.dart';
import 'package:fore/core/telemetry/telemetry_repository.dart';
import 'package:fore/features/auth/application/login_controller.dart';
import 'package:fore/features/auth/application/staff_login_controller.dart';
import 'package:fore/features/sales/application/bill_controller.dart';
import 'package:fore/features/sales/domain/sales_models.dart';
import 'package:fore/features/shift/application/shift_controller.dart';
import 'package:fore/features/shift/operations/application/ops_shift_controller.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_shift_repository.dart' as open_screen;
import '../support/fake_telemetry_repository.dart';
import '../support/fakes.dart';

/// Telemetry ném lỗi ngay khi gọi (không phải Future lỗi) để thử lớp bảo vệ ngoài cùng.
class _ThrowingTelemetry extends FakeTelemetryRepository {
  @override
  Future<void> logEvent(String name,
          {Map<String, dynamic>? props, String? shopId}) =>
      throw StateError('sync boom');

  @override
  Future<void> recordLogin() => throw StateError('sync boom');
}

/// Telemetry mà chính việc gửi lỗi lại sinh ra một lỗi mới được báo về reporter.
class _ReentrantTelemetry extends FakeTelemetryRepository {
  ErrorReporter? reporter;

  @override
  Future<void> logError({
    required String message,
    String? stack,
    String? shopId,
    String? appVersion,
    String? platform,
    Map<String, dynamic>? context,
  }) {
    reporter!.report(StateError('lỗi trong lúc gửi lỗi'), null);
    return super.logError(message: message, stack: stack);
  }
}

void main() {
  group('RpcTelemetryRepository', () {
    test('gọi đúng tên hàm và tham số của 09_admin.sql', () async {
      final rpc =
          FakeRpcClient({'log_error': 1, 'log_event': 2, 'record_login': null});
      final t = RpcTelemetryRepository(rpc);

      await t.logError(
        message: 'boom',
        stack: 'st',
        shopId: 'q1',
        appVersion: '1.0.0',
        platform: 'android',
        context: {'source': 'flutter'},
      );
      await t.logEvent('shift_open', props: {'opening_cash': 0}, shopId: 'q1');
      await t.recordLogin();

      expect(rpc.calls.map((c) => c.fn),
          ['log_error', 'log_event', 'record_login']);
      expect(rpc.calls[0].params, {
        'p_message': 'boom',
        'p_stack': 'st',
        'p_shop_id': 'q1',
        'p_app_version': '1.0.0',
        'p_platform': 'android',
        'p_context': {'source': 'flutter'},
      });
      expect(rpc.calls[1].params, {
        'p_name': 'shift_open',
        'p_props': {'opening_cash': 0},
        'p_shop_id': 'q1',
      });
      expect(rpc.calls[2].params, isNull);
    });

    test('server lỗi (mất mạng, chưa đăng nhập): nuốt lỗi, không ném',
        () async {
      final t = RpcTelemetryRepository(FakeRpcClient({
        'log_error': const NoNetworkFailure(),
        'log_event': const NoNetworkFailure(),
      }));
      await expectLater(t.logError(message: 'x'), completes);
      await expectLater(t.logEvent('bill_paid'), completes);
      await expectLater(t.recordLogin(), completes); // chưa dựng => StateError
    });
  });

  group('trackEvent / trackLogin', () {
    test('telemetry ném lỗi (đồng bộ hoặc bất đồng bộ) không lọt ra ngoài',
        () async {
      final failing = FakeTelemetryRepository()..fail = true;
      expect(() => failing.trackEvent('bill_paid'), returnsNormally);
      expect(failing.trackLogin, returnsNormally);
      final throwing = _ThrowingTelemetry();
      expect(() => throwing.trackEvent('bill_paid'), returnsNormally);
      expect(throwing.trackLogin, returnsNormally);
      await Future<void>.delayed(Duration.zero); // để Future lỗi chạy xong
    });
  });

  group('ErrorReporter (lỗi toàn cục)', () {
    late FakeTelemetryRepository telemetry;
    late bool loggedIn;
    late DateTime clock;
    late ErrorReporter reporter;

    setUp(() {
      telemetry = FakeTelemetryRepository();
      loggedIn = true;
      clock = DateTime(2026, 11, 20, 8);
      reporter = ErrorReporter(
        telemetry: telemetry,
        appVersion: '1.2.0+5',
        platform: 'android',
        isLoggedIn: () => loggedIn,
        maxPerMinute: 3,
        now: () => clock,
      );
    });

    test('lỗi Flutter: gửi message, stack, version, platform, context', () {
      final saved = FlutterError.presentError;
      FlutterError.presentError = (_) {}; // không in ra console khi test
      addTearDown(() => FlutterError.presentError = saved);

      reporter.handleFlutterError(FlutterErrorDetails(
        exception: StateError('hỏng build'),
        stack: StackTrace.fromString('#0 main'),
        library: 'widgets library',
      ));

      expect(telemetry.errors, hasLength(1));
      final e = telemetry.errors.single;
      expect(e['message'], contains('hỏng build'));
      expect(e['stack'], contains('#0 main'));
      expect(e['app_version'], '1.2.0+5');
      expect(e['platform'], 'android');
      expect(e['context'], containsPair('source', 'flutter'));
      expect(e['context'], containsPair('library', 'widgets library'));
    });

    test('lỗi bất đồng bộ (PlatformDispatcher): gửi và báo đã xử lý', () {
      final handled = reporter.handlePlatformError(
          Exception('async'), StackTrace.fromString('#1 x'));
      expect(handled, isTrue);
      expect(telemetry.errors.single['context'],
          {'source': 'platform_dispatcher'});
    });

    test('chưa đăng nhập: không gửi (log_error cần người đăng nhập)', () {
      loggedIn = false;
      expect(reporter.report(Exception('x'), null), isFalse);
      expect(telemetry.errors, isEmpty);
    });

    test('giới hạn số lỗi mỗi phút, sang phút mới thì gửi tiếp', () {
      for (var i = 0; i < 5; i++) {
        reporter.report(Exception('lặp $i'), null);
      }
      expect(telemetry.errors, hasLength(3));
      clock = clock.add(const Duration(minutes: 1));
      expect(reporter.report(Exception('phút mới'), null), isTrue);
      expect(telemetry.errors, hasLength(4));
    });

    test('lỗi sinh ra trong lúc đang gửi lỗi: bỏ qua, không lặp vô hạn', () {
      final reentrant = _ReentrantTelemetry();
      final r = ErrorReporter(
        telemetry: reentrant,
        appVersion: 'dev',
        platform: 'web',
        isLoggedIn: () => true,
      );
      reentrant.reporter = r;
      expect(r.report(Exception('gốc'), null), isTrue);
      expect(reentrant.errors, hasLength(1));
      // Sau khi xong, lỗi mới vẫn được gửi bình thường.
      reentrant.reporter = null;
      final plain = ErrorReporter(
        telemetry: telemetry,
        appVersion: 'dev',
        platform: 'web',
        isLoggedIn: () => true,
      );
      expect(plain.report(Exception('sau'), null), isTrue);
    });

    test('telemetry hỏng: report không ném', () async {
      telemetry.fail = true;
      expect(() => reporter.report(Exception('x'), null), returnsNormally);
      await Future<void>.delayed(Duration.zero);
    });
  });

  group('record_login sau khi đăng nhập', () {
    test('chủ quán: chỉ ghi khi đăng nhập thành công', () async {
      final repo = FakeAuthRepository()..registered.add('an@quan.vn');
      final telemetry = FakeTelemetryRepository();
      final c = LoginController(repo, telemetry: telemetry);

      expect(await c.submit(email: 'an@quan.vn', password: 'sai'), isFalse);
      expect(telemetry.loginCount, 0);
      expect(
          await c.submit(email: 'an@quan.vn', password: 'matkhau123'), isTrue);
      expect(telemetry.loginCount, 1);
    });

    test('nhân viên: chỉ ghi khi đăng nhập thành công', () async {
      final repo = FakeAuthRepository();
      repo.staffAccounts['+84901234567'] = 'matkhau123';
      final telemetry = FakeTelemetryRepository();
      final c = StaffLoginController(repo, telemetry: telemetry);

      expect(await c.submit('0901234567', 'sai-mat-khau'), isFalse);
      expect(telemetry.loginCount, 0);
      expect(await c.submit('0901234567', 'matkhau123'), isTrue);
      expect(telemetry.loginCount, 1);
    });

    test('ghi log đăng nhập lỗi: vẫn đăng nhập được', () async {
      final repo = FakeAuthRepository()..registered.add('an@quan.vn');
      final c = LoginController(repo, telemetry: _ThrowingTelemetry());
      expect(
          await c.submit(email: 'an@quan.vn', password: 'matkhau123'), isTrue);
    });
  });

  group('log_event ở mở ca / đóng ca / thanh toán', () {
    test('màn mở ca: ghi shift_open kèm tiền đầu ca và shop_id', () async {
      final telemetry = FakeTelemetryRepository();
      final c = ShiftController(open_screen.FakeShiftRepository(),
          telemetry: telemetry)
        ..bindScope('quan-a|an');

      expect(await c.openShift('200.000'), OpenShiftResult.opened);
      final e = telemetry.events.single;
      expect(e.name, TelemetryEvents.shiftOpen);
      expect(e.shopId, 'quan-a');
      expect(e.props, containsPair('opening_cash', 200000));
    });

    test('màn mở ca: nhập sai số tiền thì không ghi', () async {
      final telemetry = FakeTelemetryRepository();
      final c = ShiftController(open_screen.FakeShiftRepository(),
          telemetry: telemetry);
      expect(await c.openShift('abc'), OpenShiftResult.failed);
      expect(telemetry.events, isEmpty);
    });

    test('màn chính: mở rồi đóng ca ghi shift_open và shift_close', () async {
      final telemetry = FakeTelemetryRepository();
      final c = OpsShiftController(FakeShiftRepository(), telemetry: telemetry);
      await c.load();

      expect(await c.openShift(150000), isTrue);
      expect(await c.closeShift(900000), isTrue);

      expect(telemetry.events.map((e) => e.name),
          [TelemetryEvents.shiftOpen, TelemetryEvents.shiftClose]);
      expect(telemetry.events[0].props,
          {'shift_id': 's1', 'opening_cash': 150000});
      expect(telemetry.events[1].props,
          {'shift_id': 's1', 'closing_cash': 900000});
    });

    test('màn chính: đóng ca bị từ chối thì không ghi shift_close', () async {
      final repo = FakeShiftRepository();
      final telemetry = FakeTelemetryRepository();
      final c = OpsShiftController(repo, telemetry: telemetry);
      await c.openShift(0);
      repo.failNext('closeShift', const DatabaseFailure('OPEN_BILLS_REMAIN'));

      await expectLater(c.closeShift(0), throwsA(isA<DatabaseFailure>()));
      expect(telemetry.events.map((e) => e.name), [TelemetryEvents.shiftOpen]);
    });

    test('thanh toán: ghi bill_paid kèm mã bill, cách trả, số tiền', () async {
      final repo = FakeSalesRepository()..menuItems = List.of(sampleMenu);
      final telemetry = FakeTelemetryRepository();
      final c = BillController(repo, 'b1', telemetry: telemetry);
      await c.load();
      c.setCartQty('cf-m', 2);
      await c.submitCart();

      final total = await c.pay(PaymentMethod.transfer);

      final e = telemetry.events.single;
      expect(e.name, TelemetryEvents.billPaid);
      expect(e.props, {'bill_id': 'b1', 'method': 'transfer', 'total': total});
    });

    test('thanh toán lỗi thì không ghi bill_paid', () async {
      final repo = FakeSalesRepository()..menuItems = List.of(sampleMenu);
      final telemetry = FakeTelemetryRepository();
      final c = BillController(repo, 'b1', telemetry: telemetry);
      await c.load();
      repo.failNext('pay', const NoNetworkFailure());

      await expectLater(
          c.pay(PaymentMethod.cash), throwsA(isA<NoNetworkFailure>()));
      expect(telemetry.events, isEmpty);
    });
  });
}
