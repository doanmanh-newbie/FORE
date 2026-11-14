import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/application/load_phase.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/sales/application/table_map_controller.dart';

import '../support/fakes.dart';

void main() {
  late FakeSalesRepository repo;
  late TableMapController c;

  setUp(() {
    repo = FakeSalesRepository()
      ..tables = [
        slot('Bàn 1'),
        slot('Bàn 2', bill: 'b2', portions: 3),
        slot('Bàn 10'),
        slot('Sân 1', area: 'a2', areaName: 'Sân'),
        slot('Sân 2', area: 'a2', areaName: 'Sân', bill: 'b9', portions: 1),
      ];
    c = TableMapController(repo);
  });

  test('gom bàn theo khu, giữ thứ tự database', () async {
    await c.load();
    expect(c.phase, equals(LoadPhase.ready));
    expect(c.areas.map((a) => a.name).toList(), equals(['Tầng 1', 'Sân']));
    expect(c.areas.first.tables.map((t) => t.tableName).toList(), equals(['Bàn 1', 'Bàn 2', 'Bàn 10']));
    expect(c.areas.first.busyCount, equals(1));
    expect(c.areas[1].busyCount, equals(1));
  });

  test('mặc định chọn khu đầu tiên, đổi khu được', () async {
    await c.load();
    expect(c.selectedArea!.name, equals('Tầng 1'));
    c.selectArea('a2');
    expect(c.selectedArea!.name, equals('Sân'));
    expect(c.visibleTables.map((t) => t.tableName).toList(), equals(['Sân 1', 'Sân 2']));
  });

  test('khu đã chọn bị ẩn thì quay về khu đầu tiên', () async {
    await c.load();
    c.selectArea('a2');
    repo.tables = [for (final t in repo.tables) if (t.areaId != 'a2') t];
    await c.load();
    expect(c.selectedArea!.name, equals('Tầng 1'));
  });

  test('tìm bàn: bỏ dấu, tìm trên mọi khu', () async {
    await c.load();
    c.setQuery('san');
    expect(c.isSearching, isTrue);
    expect(c.visibleTables.map((t) => t.tableName).toList(), equals(['Sân 1', 'Sân 2']));
    c.setQuery('ban 1');
    expect(c.visibleTables.map((t) => t.tableName).toList(), equals(['Bàn 1', 'Bàn 10']));
    c.setQuery('   ');
    expect(c.isSearching, isFalse);
    expect(c.visibleTables, hasLength(3)); // lại hiện bàn của khu đang chọn
  });

  test('chưa có bàn nào: không lỗi', () async {
    repo.tables = [];
    await c.load();
    expect(c.phase, equals(LoadPhase.ready));
    expect(c.selectedArea, isNull);
    expect(c.visibleTables, isEmpty);
  });

  test('lỗi ở lần tải đầu hiện màn lỗi; lỗi sau đó giữ dữ liệu cũ', () async {
    repo.failNext('tableMap', const NoNetworkFailure());
    await c.load();
    expect(c.phase, equals(LoadPhase.error));
    await c.load();
    expect(c.phase, equals(LoadPhase.ready));
    repo.failNext('tableMap', const NoNetworkFailure());
    await c.load();
    expect(c.phase, equals(LoadPhase.ready));
    expect(c.slots, hasLength(5));
    expect(c.failure, isA<NoNetworkFailure>());
  });

  group('mở bàn', () {
    test('mở bàn trống: gọi database đúng tham số rồi tải lại bản đồ', () async {
      await c.load();
      final id = await c.openTable(c.slots.first, guests: 3);
      expect(id, startsWith('b'));
      expect(repo.calls, contains('openBill:t-Bàn 1:dine_in:3'));
      expect(repo.count('tableMap'), equals(2));
    });

    test('không nhập số khách thì gửi null', () async {
      await c.load();
      await c.openTable(c.slots.first);
      expect(repo.calls, contains('openBill:t-Bàn 1:dine_in:-'));
    });

    test('bàn vừa có bill từ máy khác: báo lỗi và tự tải lại bản đồ', () async {
      await c.load();
      repo.tables = [slot('Bàn 1', bill: 'bx', portions: 2), ...repo.tables.skip(1)];
      repo.failNext('openBill', const DatabaseFailure('TABLE_HAS_OPEN_BILL'));
      await expectLater(c.openTable(c.slots.first), throwsA(isA<DatabaseFailure>()));
      expect(c.slots.first.isBusy, isTrue); // đã thấy bàn có khách
    });
  });

  test('tự làm mới theo chu kỳ và dừng khi gọi stop', () async {
    await c.load();
    c.startAutoRefresh(const Duration(milliseconds: 20));
    await Future<void>.delayed(const Duration(milliseconds: 90));
    c.stopAutoRefresh();
    final n = repo.count('tableMap');
    expect(n, greaterThan(2));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(repo.count('tableMap'), equals(n)); // đã dừng
  });

  test('dispose hủy bộ đếm giờ', () async {
    await c.load();
    c.startAutoRefresh(const Duration(milliseconds: 20));
    c.dispose();
    final n = repo.count('tableMap');
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(repo.count('tableMap'), equals(n));
  });
}
