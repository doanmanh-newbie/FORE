import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/shift/operations/application/ops_shift_controller.dart';
import 'package:fore/features/shift/operations/domain/ops_shift_models.dart';

import '../support/fakes.dart';

OpsCurrentShift _openShift() => OpsCurrentShift(
      id: 's1',
      openedAt: DateTime(2026, 10, 23, 8, 2),
      openedByName: 'An',
      openedByMe: true,
    );

/// Cho phép test quyết định request nào xong trước.
class _ManualShiftRepo extends FakeShiftRepository {
  final pending = <Completer<OpsCurrentShift?>>[];

  @override
  Future<OpsCurrentShift?> currentShift() {
    final c = Completer<OpsCurrentShift?>();
    pending.add(c);
    return c.future;
  }
}

void main() {
  late FakeShiftRepository repo;
  late OpsShiftController c;

  setUp(() {
    repo = FakeShiftRepository();
    c = OpsShiftController(repo);
  });

  test('hai lần tải chồng nhau: kết quả cũ về sau không ghi đè kết quả mới', () async {
    final manual = _ManualShiftRepo();
    final ctrl = OpsShiftController(manual);

    final first = ctrl.load(); // gửi trước, sẽ về sau
    await Future<void>.delayed(Duration.zero); // request ca của lần 1 đã bay đi
    final second = ctrl.load(); // gửi sau, về trước
    await Future<void>.delayed(Duration.zero);
    expect(manual.pending, hasLength(2));

    manual.pending[1].complete(null); // lần mới: hiện không có ca
    await second;
    manual.pending[0].complete(_openShift()); // lần cũ về muộn: còn ca
    await first;

    expect(ctrl.hasOpenShift, isFalse);
  });

  group('tải trạng thái', () {
    test('chưa mở ca', () async {
      await c.load();
      expect(c.phase, equals(OpsShiftPhase.ready));
      expect(c.hasOpenShift, isFalse);
      expect(c.shopName, equals('Fore Nguyễn Du'));
      expect(c.servingLabel, equals('phần'));
    });

    test('đang có ca của người khác', () async {
      repo.shift = OpsCurrentShift(
          id: 's',
          openedAt: DateTime(2026, 10, 23, 8, 2),
          openedByName: 'Bình',
          openedByMe: false);
      await c.load();
      expect(c.hasOpenShift, isTrue);
      expect(c.shift!.openedByName, equals('Bình'));
      expect(c.shift!.openedByMe, isFalse);
    });

    test('quán chưa có hồ sơ thì dùng tên mặc định', () async {
      repo.shop = null;
      await c.load();
      expect(c.shopName, equals('Fore'));
      expect(c.servingLabel, equals('phần'));
    });

    test('RPC hồ sơ quán lỗi nhưng vẫn vào trang nếu tải trạng thái ca được', () async {
      // Lỗi RPC hồ sơ quán không còn chặn ca; chỉ lỗi tải ca làm màn thất bại.
      repo.failNext('shopInfo', const NoNetworkFailure());
      await c.load();
      expect(c.phase, equals(OpsShiftPhase.ready));
      expect(c.failure, isNull);
      expect(c.shopName, equals('Fore'));
    });

    test(
        'mất mạng thoáng qua sau khi đã có dữ liệu: giữ giao diện, không đẩy ra màn lỗi',
        () async {
      repo.shift = _openShift();
      await c.load();
      repo.failNext('currentShift', const NoNetworkFailure());
      await c.load();
      expect(c.phase, equals(OpsShiftPhase.ready));
      expect(c.hasOpenShift, isTrue);
      expect(c.failure, isA<NoNetworkFailure>());
      await c.load(); // tải lại được thì lỗi biến mất
      expect(c.failure, isNull);
    });

    test(
        'ca bị đóng ở máy khác: tải lại thì mất ca và mất danh sách việc đóng ca',
        () async {
      repo.shift = _openShift();
      await c.load();
      await c.loadCloseStatus();
      expect(c.closeStatus, isNotNull);
      repo.shift = null;
      await c.load();
      expect(c.hasOpenShift, isFalse);
      expect(c.closeStatus, isNull);
    });
  });

  group('mở ca', () {
    test('mở ca thành công rồi tải lại trạng thái', () async {
      await c.load();
      final ok = await c.openShift(500000);
      expect(ok, isTrue);
      expect(c.hasOpenShift, isTrue);
      expect(repo.calls, contains('openShift:500000'));
    });

    test('đã có ca mở ở máy khác: báo lỗi và tự tải lại để thấy ca đó',
        () async {
      await c.load();
      repo.shift = _openShift(); // máy khác vừa mở
      repo.failNext('openShift', const DatabaseFailure('SHIFT_ALREADY_OPEN'));
      await expectLater(c.openShift(1), throwsA(isA<DatabaseFailure>()));
      expect(c.hasOpenShift, isTrue);
    });

    test('bấm đúp chỉ gửi một lệnh', () async {
      await c.load();
      repo.gate = Completer<void>();
      final first = c.openShift(100);
      final second = await c.openShift(100);
      expect(second, isFalse);
      repo.gate!.complete();
      expect(await first, isTrue);
      expect(repo.count('openShift'), equals(1));
    });

    test('đóng màn hình khi lệnh chưa xong thì không lỗi', () async {
      await c.load();
      repo.gate = Completer<void>();
      final f = c.openShift(100);
      c.dispose();
      repo.gate!.complete();
      expect(await f, isTrue);
    });
  });

  group('đóng ca', () {
    setUp(() async {
      repo.shift = _openShift();
      await c.load();
    });

    test('đóng thành công thì không còn ca', () async {
      final ok = await c.closeShift(1250000);
      expect(ok, isTrue);
      expect(c.hasOpenShift, isFalse);
      expect(c.closeStatus, isNull);
      expect(repo.calls, contains('closeShift:1250000'));
    });

    test('còn bill mở: bị từ chối, danh sách việc còn thiếu được tải lại',
        () async {
      repo.status = const CloseStatus(openBills: 2, missingCounts: 1);
      repo.failNext('closeShift', const DatabaseFailure('OPEN_BILLS_REMAIN'));
      await expectLater(c.closeShift(1000), throwsA(isA<DatabaseFailure>()));
      expect(c.hasOpenShift, isTrue);
      expect(c.closeStatus!.openBills, equals(2));
      expect(c.closeStatus!.missingCounts, equals(1));
      expect(c.closeStatus!.ready, isFalse);
    });

    test('loadCloseStatus: sẵn sàng khi không còn gì thiếu', () async {
      await c.loadCloseStatus();
      expect(c.closeStatus!.ready, isTrue);
    });

    test('loadCloseStatus khi ca đã đóng ở máy khác: cập nhật về chưa mở ca',
        () async {
      repo.shift = null;
      repo.failNext('closeStatus', const DatabaseFailure('NO_OPEN_SHIFT'));
      await c.loadCloseStatus();
      expect(c.hasOpenShift, isFalse);
    });
  });
}
