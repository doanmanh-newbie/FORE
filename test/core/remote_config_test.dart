import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/config/app_version.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/core/remote_config/app_config_repository.dart';
import 'package:fore/core/remote_config/remote_app_config.dart';
import 'package:fore/core/remote_config/remote_config_controller.dart';
import 'package:fore/core/remote_config/remote_config_gate.dart';
import 'package:provider/provider.dart';

import '../support/fake_app_config_repository.dart';
import '../support/fakes.dart';

const _maintenance = RemoteAppConfig(
    maintenanceMode: true, maintenanceMessage: 'Nâng cấp tới 23h.');
const _needs120 = RemoteAppConfig(minVersion: '1.2.0');

/// Dựng app nhỏ có cổng cấu hình từ xa, nội dung app là chữ "TRANG CHU".
Future<RemoteConfigController> _pumpGate(
  WidgetTester tester,
  FakeAppConfigRepository repo, {
  String version = '1.1.0',
}) async {
  final c = RemoteConfigController(repo, appVersion: version);
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: c,
    child: MaterialApp(
      builder: (context, child) => RemoteConfigGate(child: child!),
      home: const Scaffold(body: Text('TRANG CHU')),
    ),
  ));
  c.bindUser('u1'); // vừa đăng nhập
  await tester.pumpAndSettle();
  return c;
}

void main() {
  group('compareVersions', () {
    test('so theo số, bỏ +build', () {
      expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2.0+7', '1.2.0'), 0);
      expect(compareVersions('0.9.0', '1.0.0'), lessThan(0));
    });
    test('không đọc được thì null (không chặn)', () {
      expect(compareVersions('dev', '1.0.0'), isNull);
      expect(compareVersions('1.0.0', 'abc'), isNull);
    });
  });

  group('RemoteAppConfig', () {
    test('đọc đúng các khóa của get_app_config', () {
      final c = RemoteAppConfig.fromJson({
        'maintenance_mode': true,
        'maintenance_message': ' Bảo trì ',
        'min_version': '1.2.0',
        'force_update': false,
        'khoa_khac': 1,
      });
      expect(c.maintenanceMode, isTrue);
      expect(c.maintenanceMessage, 'Bảo trì');
      expect(c.minVersion, '1.2.0');
      expect(c.forceUpdate, isFalse);
    });

    test('bảng trống hoặc sai kiểu: giá trị an toàn, vào app bình thường', () {
      final c = RemoteAppConfig.fromJson({
        'maintenance_mode': 'true', // chuỗi, không phải bool
        'min_version': 5,
        'force_update': 'no',
      });
      expect(c.verdictFor('0.0.1'), RemoteConfigVerdict.ok);
      expect(RemoteAppConfig.fromJson({}).verdictFor('0.0.1'),
          RemoteConfigVerdict.ok);
      expect(c.forceUpdate, isTrue);
    });

    test('bảo trì ưu tiên hơn phiên bản; bản dev không bị chặn phiên bản', () {
      const both = RemoteAppConfig(maintenanceMode: true, minVersion: '9.0.0');
      expect(both.verdictFor('1.0.0'), RemoteConfigVerdict.maintenance);
      expect(_needs120.verdictFor('dev'), RemoteConfigVerdict.ok);
      expect(_needs120.verdictFor('1.2.0'), RemoteConfigVerdict.ok);
      expect(_needs120.verdictFor('1.1.9'), RemoteConfigVerdict.updateRequired);
      expect(
          const RemoteAppConfig(minVersion: '1.2.0', forceUpdate: false)
              .verdictFor('1.1.9'),
          RemoteConfigVerdict.updateSuggested);
    });
  });

  group('RpcAppConfigRepository', () {
    test('gọi get_app_config và đọc object', () async {
      final rpc = FakeRpcClient({
        'get_app_config': {'maintenance_mode': true, 'min_version': '2.0.0'},
      });
      final c = await RpcAppConfigRepository(rpc).fetch();
      expect(rpc.calls.single.fn, 'get_app_config');
      expect(c.maintenanceMode, isTrue);
      expect(c.minVersion, '2.0.0');
    });

    test('kết quả sai dạng: báo UnknownFailure', () async {
      final rpc = FakeRpcClient({'get_app_config': <dynamic>[]});
      await expectLater(
          RpcAppConfigRepository(rpc).fetch(), throwsA(isA<UnknownFailure>()));
    });
  });

  group('RemoteConfigController', () {
    test('chưa đăng nhập: không gọi server, không chặn', () async {
      final repo = FakeAppConfigRepository(_maintenance);
      final c = RemoteConfigController(repo, appVersion: '1.0.0');
      c.bindUser(null);
      await c.load();
      expect(repo.fetchCount, 0);
      expect(c.verdict, RemoteConfigVerdict.ok);
    });

    test('lỗi mạng lúc khởi động: dùng giá trị an toàn, không chặn', () async {
      final repo = FakeAppConfigRepository(_maintenance)
        ..failure = const NoNetworkFailure();
      final c = RemoteConfigController(repo, appVersion: '1.0.0');
      c.bindUser('u1');
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCount, 1);
      expect(c.loading, isFalse);
      expect(c.verdict, RemoteConfigVerdict.ok);
    });

    test('lỗi mạng khi tải lại: giữ cấu hình đã có', () async {
      final repo = FakeAppConfigRepository(_maintenance);
      final c = RemoteConfigController(repo, appVersion: '1.0.0');
      c.bindUser('u1');
      await Future<void>.delayed(Duration.zero);
      repo.failure = const NoNetworkFailure();
      await c.load();
      expect(c.verdict, RemoteConfigVerdict.maintenance);
    });

    test('đăng xuất thì bỏ chặn; đăng nhập lại thì tải lại', () async {
      final repo = FakeAppConfigRepository(_maintenance);
      final c = RemoteConfigController(repo, appVersion: '1.0.0');
      c.bindUser('u1');
      await Future<void>.delayed(Duration.zero);
      expect(c.verdict, RemoteConfigVerdict.maintenance);
      c.bindUser(null);
      expect(c.verdict, RemoteConfigVerdict.ok);
      c.bindUser('u2');
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCount, 2);
    });
  });

  group('RemoteConfigGate khi mở app', () {
    testWidgets('cấu hình bình thường: vào app', (tester) async {
      final repo = FakeAppConfigRepository(_needs120);
      await _pumpGate(tester, repo, version: '1.2.0');
      expect(find.text('TRANG CHU'), findsOneWidget);
      expect(find.text('Fore đang bảo trì'), findsNothing);
      expect(find.text('Cần cập nhật ứng dụng'), findsNothing);
    });

    testWidgets(
        'bật bảo trì: chặn app, hiện lời nhắn; tắt rồi kiểm tra lại thì vào',
        (tester) async {
      final repo = FakeAppConfigRepository(_maintenance);
      await _pumpGate(tester, repo);
      expect(find.text('Fore đang bảo trì'), findsOneWidget);
      expect(find.text('Nâng cấp tới 23h.'), findsOneWidget);
      expect(find.text('TRANG CHU'), findsNothing);

      repo.config = RemoteAppConfig.fallback; // admin tắt bảo trì
      await tester.tap(find.text('Kiểm tra lại'));
      await tester.pumpAndSettle();
      expect(find.text('TRANG CHU'), findsOneWidget);
    });

    testWidgets('phiên bản thấp hơn min_version: bắt cập nhật', (tester) async {
      final repo = FakeAppConfigRepository(_needs120);
      await _pumpGate(tester, repo, version: '1.1.0');
      expect(find.text('Cần cập nhật ứng dụng'), findsOneWidget);
      expect(find.textContaining('1.2.0'), findsOneWidget);
      expect(find.text('TRANG CHU'), findsNothing);
    });

    testWidgets('cập nhật không bắt buộc: bấm "Để sau" thì vào app',
        (tester) async {
      final repo = FakeAppConfigRepository(
          const RemoteAppConfig(minVersion: '1.2.0', forceUpdate: false));
      await _pumpGate(tester, repo, version: '1.1.0');
      expect(find.text('Đã có phiên bản mới'), findsOneWidget);
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(find.text('TRANG CHU'), findsOneWidget);
    });

    testWidgets('không có controller (test cũ): hiện app như thường',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => RemoteConfigGate(child: child!),
        home: const Text('TRANG CHU'),
      ));
      expect(find.text('TRANG CHU'), findsOneWidget);
    });
  });

  test('StaticAppConfigRepository mặc định không chặn', () async {
    final c = await const StaticAppConfigRepository().fetch();
    expect(c.verdictFor('0.0.1'), RemoteConfigVerdict.ok);
  });
}
