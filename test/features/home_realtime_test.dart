import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/realtime/live_feed.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/home/home_screen.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_live_feed.dart';
import '../support/fakes.dart';

dynamic _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync());

const _profile = Profile(
  staffId: 's1',
  fullName: 'Nguyễn An',
  role: StaffRole.staff,
  hasPin: false,
  active: true,
  shopId: 'shop-1',
  shopName: 'Quán A',
);

/// Màn chính với ca đang mở, RPC giả từ fixture thật và kênh realtime giả.
class _Harness {
  late FakeRpcClient rpc;
  late FakeLiveFeed feed;

  int count(String fn) => rpc.calls.where((c) => c.fn == fn).length;

  Future<void> pump(WidgetTester tester, {bool withFeed = true}) async {
    rpc = FakeRpcClient({
      'shop_info': _fixture('shop_info'),
      'current_shift': _fixture('current_shift'),
      'table_map': _fixture('table_map'),
      'takeaway_orders': _fixture('takeaway_orders'),
      'shift_close_status': _fixture('shift_close_status'),
    });
    feed = FakeLiveFeed();
    final auth = FakeAuthRepository()
      ..user = const AuthUser(
          id: 'u1', email: 'an@quan.vn', accountKind: AccountKind.staff)
      ..profile = _profile;
    final session = SessionController(auth, minVisible: Duration.zero);
    await tester.runAsync(session.restore);
    expect(session.state, isA<SessionReady>());

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionController>.value(value: session),
        if (withFeed) Provider<LiveFeed>.value(value: feed),
      ],
      child: MaterialApp(home: OpsHomeScreen(rpc: rpc)),
    ));
    await tester.pumpAndSettle();
  }
}

void main() {
  late _Harness h;
  setUp(() => h = _Harness());

  testWidgets('nghe realtime theo quán đang chọn; kết nối xong thì tải lại',
      (tester) async {
    await h.pump(tester);
    expect(h.feed.subscriptions, hasLength(1));
    expect(h.feed.last.shopId, 'shop-1');

    final before = h.count('table_map');
    h.feed.last.connect();
    await tester.pumpAndSettle();
    expect(h.count('table_map'), before + 1);
    expect(h.count('current_shift'), greaterThanOrEqualTo(2));
  });

  testWidgets('bill đổi ở máy khác: tự tải lại bàn, không cần bấm làm mới',
      (tester) async {
    await h.pump(tester);
    h.feed.last.connect();
    await tester.pumpAndSettle();
    final before = h.count('table_map');

    h.feed.last.emit(LiveTable.bills, billId: 'b9');
    h.feed.last.emit(LiveTable.billLines, billId: 'b9');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(h.count('table_map'), before + 1,
        reason: 'gộp 2 sự kiện thành 1 lần');
  });

  testWidgets('đang live: tắt tải lại theo giờ', (tester) async {
    await h.pump(tester);
    h.feed.last.connect();
    await tester.pumpAndSettle();
    final tables = h.count('table_map');
    final shifts = h.count('current_shift');

    await tester.pump(const Duration(seconds: 61));
    expect(h.count('table_map'), tables);
    expect(h.count('current_shift'), shifts);
  });

  testWidgets(
      'mất kết nối: bật lại tải theo giờ, tự kết nối lại và đồng bộ, không crash',
      (tester) async {
    await h.pump(tester);
    h.feed.last.connect();
    await tester.pumpAndSettle();

    h.feed.last.fail('CHANNEL_ERROR');
    await tester.pump();
    expect(tester.takeException(), isNull);
    final tables = h.count('table_map');

    // Kênh tự thử lại sau 2 giây nhưng vẫn lỗi (hết thời gian).
    await tester.pump(const Duration(seconds: 2));
    expect(h.feed.subscriptions, hasLength(2));
    expect(h.feed.subscriptions.first.cancelled, isTrue);
    h.feed.last.fail('TIMED_OUT');

    // Lần thử lại thứ hai chờ lâu hơn (5 giây), dù trạng thái kênh đổi liên tục.
    await tester.pump(const Duration(seconds: 4));
    expect(h.feed.subscriptions, hasLength(2));
    await tester.pump(const Duration(seconds: 2));
    expect(h.feed.subscriptions, hasLength(3));
    expect(h.feed.active, hasLength(1));

    // Trong lúc chưa live, bàn vẫn được tải lại theo giờ (15 giây), hẹn giờ không bị
    // đặt lại mỗi lần kênh đổi trạng thái.
    await tester.pump(const Duration(seconds: 10));
    expect(h.count('table_map'), greaterThan(tables));

    // Kết nối lại: tải lại toàn bộ để bù thay đổi bị lỡ, rồi tắt tải theo giờ.
    final beforeResync = h.count('table_map');
    h.feed.last.connect();
    await tester.pumpAndSettle();
    expect(h.count('table_map'), beforeResync + 1);

    final afterResync = h.count('table_map');
    await tester.pump(const Duration(seconds: 31));
    expect(h.count('table_map'), afterResync);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thoát màn hình: gỡ kênh realtime', (tester) async {
    await h.pump(tester);
    h.feed.last.connect();
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    expect(h.feed.active, isEmpty);
  });

  testWidgets('không có realtime (test cũ / chưa cấu hình): vẫn tải theo giờ',
      (tester) async {
    await h.pump(tester, withFeed: false);
    final tables = h.count('table_map');
    await tester.pump(const Duration(seconds: 16));
    expect(h.count('table_map'), greaterThan(tables));
    await tester.pumpWidget(const SizedBox());
  });
}
