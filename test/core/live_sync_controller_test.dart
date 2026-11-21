import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/realtime/live_feed.dart';
import 'package:fore/core/realtime/live_sync_controller.dart';

import '../support/fake_live_feed.dart';

/// Chờ hết khoảng gộp sự kiện / hẹn giờ kết nối lại (thời gian rút ngắn cho test).
Future<void> settle([int ms = 40]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  late FakeLiveFeed feed;
  late LiveSyncController c;
  late int shiftCalls;
  late int resyncCalls;
  late List<Set<String>> billCalls;

  setUp(() {
    feed = FakeLiveFeed();
    shiftCalls = 0;
    resyncCalls = 0;
    billCalls = [];
    c = LiveSyncController(
      feed,
      onShiftChanged: () => shiftCalls++,
      onBillsChanged: billCalls.add,
      onResync: () => resyncCalls++,
      debounce: const Duration(milliseconds: 5),
      retryDelays: const [
        Duration(milliseconds: 10),
        Duration(milliseconds: 20)
      ],
    );
  });

  tearDown(() => c.dispose());

  group('LiveChange.fromRow', () {
    test('đọc mã bill từ bills.id và bill_lines.bill_id', () {
      expect(LiveChange.fromRow(LiveTable.bills, {'id': 'b1'}).billId, 'b1');
      expect(
          LiveChange.fromRow(LiveTable.billLines, {'id': 'l1', 'bill_id': 'b2'})
              .billId,
          'b2');
      expect(LiveChange.fromRow(LiveTable.shifts, {'id': 's1'}).billId, isNull);
      expect(LiveChange.fromRow(LiveTable.bills, {}).billId, isNull);
    });
  });

  group('nhận cập nhật bình thường', () {
    test('đăng ký theo quán; kết nối xong thì live và tải lại toàn bộ 1 lần',
        () {
      c.start('quan-a');
      expect(feed.last.shopId, 'quan-a');
      expect(c.status, LiveStatus.connecting);

      feed.last.connect();
      expect(c.status, LiveStatus.live);
      expect(c.isLive, isTrue);
      expect(resyncCalls, 1);

      feed.last.connect(); // báo SUBSCRIBED lần nữa: không tải lại thừa
      expect(resyncCalls, 1);
    });

    test('nhiều thay đổi bill liên tiếp gộp thành MỘT lần tải, kèm mã bill',
        () async {
      c.start('quan-a');
      feed.last.connect();
      feed.last.emit(LiveTable.bills, billId: 'b1');
      feed.last.emit(LiveTable.billLines, billId: 'b1');
      feed.last.emit(LiveTable.billLines, billId: 'b2');
      await settle();
      expect(billCalls, [
        {'b1', 'b2'}
      ]);
      expect(shiftCalls, 0);
    });

    test('thay đổi ca gọi onShiftChanged', () async {
      c.start('quan-a');
      feed.last.connect();
      feed.last.emit(LiveTable.shifts);
      feed.last.emit(LiveTable.shifts);
      await settle();
      expect(shiftCalls, 1);
      expect(billCalls, isEmpty);
    });

    test('lỗi trong lệnh tải lại không làm hỏng vòng nghe', () async {
      final boom = LiveSyncController(
        feed,
        onShiftChanged: () => throw StateError('boom'),
        onBillsChanged: (_) {},
        onResync: () => throw StateError('boom'),
        debounce: const Duration(milliseconds: 1),
      );
      addTearDown(boom.dispose);
      boom.start('quan-a');
      expect(() => feed.last.connect(), returnsNormally);
      feed.last.emit(LiveTable.shifts);
      await settle();
      expect(boom.isLive, isTrue);
    });
  });

  group('mất kết nối / lỗi kênh', () {
    test('kênh lỗi: offline, gỡ kênh cũ, tự đăng ký lại và tải lại khi có lại',
        () async {
      c.start('quan-a');
      feed.last.connect();
      expect(resyncCalls, 1);

      feed.last.fail('CHANNEL_ERROR');
      expect(c.status, LiveStatus.offline);
      expect(c.isLive, isFalse);
      expect(feed.subscriptions, hasLength(1)); // chưa tới hẹn thử lại

      await settle();
      expect(feed.subscriptions, hasLength(2));
      expect(feed.subscriptions.first.cancelled, isTrue);
      expect(feed.last.shopId, 'quan-a');
      expect(c.status, LiveStatus.connecting);

      feed.last.connect();
      expect(c.isLive, isTrue);
      expect(resyncCalls, 2, reason: 'phải tải lại để bù thay đổi bị lỡ');
    });

    test('hết thời gian / bị đóng nhiều lần: thử lại theo thời gian tăng dần',
        () async {
      c.start('quan-a');
      feed.last.fail('TIMED_OUT');
      await settle(15); // > 10ms: lần thử 1
      expect(feed.subscriptions, hasLength(2));
      feed.last.fail('CLOSED');
      await settle(12); // < 20ms: chưa tới lần thử 2
      expect(feed.subscriptions, hasLength(2));
      await settle(20);
      expect(feed.subscriptions, hasLength(3));
      expect(feed.active, hasLength(1));
    });

    test('không tạo được kênh (ném lỗi): coi như mất kết nối rồi thử lại',
        () async {
      feed.throwOnWatch = StateError('Supabase chưa khởi tạo');
      expect(() => c.start('quan-a'), returnsNormally);
      expect(c.status, LiveStatus.offline);
      feed.throwOnWatch = null;
      await settle();
      expect(feed.subscriptions, hasLength(1));
      feed.last.connect();
      expect(c.isLive, isTrue);
    });

    test('sự kiện / trạng thái của kênh cũ về muộn bị bỏ qua', () async {
      c.start('quan-a');
      final old = feed.last;
      old.connect();
      old.fail();
      await settle();
      final fresh = feed.last;
      expect(fresh, isNot(same(old)));

      old.emit(LiveTable.bills, billId: 'b-cu');
      old.connect();
      await settle();
      expect(billCalls, isEmpty);
      expect(c.status, LiveStatus.connecting);
    });

    test(
        'reconnectNow (app quay lại từ nền): đăng ký lại ngay nếu đang offline',
        () {
      final slow = LiveSyncController(
        feed,
        onShiftChanged: () {},
        onBillsChanged: (_) {},
        onResync: () {},
        retryDelays: const [Duration(hours: 1)],
      );
      addTearDown(slow.dispose);
      slow.start('quan-a');
      feed.last.fail();
      expect(feed.subscriptions, hasLength(1));
      slow.reconnectNow();
      expect(feed.subscriptions, hasLength(2));
      expect(feed.subscriptions.first.cancelled, isTrue);

      feed.last.connect();
      slow.reconnectNow(); // đang live: không làm gì
      expect(feed.subscriptions, hasLength(2));
    });
  });

  group('vòng đời kênh', () {
    test('cùng quán thì không đăng ký lại; đổi quán thì gỡ kênh cũ', () {
      c.start('quan-a');
      c.start('quan-a');
      expect(feed.subscriptions, hasLength(1));
      c.start('quan-b');
      expect(feed.subscriptions, hasLength(2));
      expect(feed.subscriptions.first.cancelled, isTrue);
      expect(feed.last.shopId, 'quan-b');
    });

    test('stop và dispose gỡ kênh, không gọi lại sau đó', () async {
      c.start('quan-a');
      feed.last.connect();
      c.stop();
      expect(feed.last.cancelled, isTrue);
      expect(c.isLive, isFalse);

      c.start('quan-a');
      final sub = feed.last;
      c.dispose();
      expect(sub.cancelled, isTrue);
      sub.emit(LiveTable.shifts);
      sub.fail();
      await settle();
      expect(shiftCalls, 0);
      expect(feed.subscriptions, hasLength(2),
          reason: 'không thử lại sau dispose');
      c = LiveSyncController(feed,
          onShiftChanged: () {}, onBillsChanged: (_) {}, onResync: () {});
    });
  });
}
