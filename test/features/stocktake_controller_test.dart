import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/application/load_phase.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/stocktake/application/stocktake_controller.dart';
import 'package:fore/features/stocktake/domain/stocktake_models.dart';

import '../support/fakes.dart';

void main() {
  late FakeStocktakeRepository repo;
  late StocktakeController c;

  setUp(() async {
    repo = FakeStocktakeRepository()
      ..items = [
        countItem('milk'),
        countItem('cafe'),
        countItem('sugar', weekly: true, important: false),
      ];
    c = StocktakeController(repo, CountKind.close);
    await c.load();
  });

  test('chia nguyên liệu mỗi ca và theo tuần', () {
    expect(c.phase, equals(LoadPhase.ready));
    expect(c.dailyItems.map((i) => i.id).toList(), equals(['milk', 'cafe']));
    expect(c.weeklyItems.map((i) => i.id).toList(), equals(['sugar']));
    expect(c.dailyTotal, equals(2));
    expect(c.allDailyCounted, isFalse);
  });

  test('lúc đầu mọi dòng cần ô nhập', () {
    expect(c.items.every(c.needsInput), isTrue);
  });

  group('nhập và lưu', () {
    test('lưu mọi dòng đã gõ, theo thứ tự, đúng loại kiểm kê và đúng số', () async {
      c.setDraft('milk', 1234);
      c.setDraft('cafe', 0); // đếm ra 0 là số hợp lệ
      expect(c.pendingCount, equals(2));
      final saved = await c.saveAll();
      expect(saved, equals(2));
      expect(repo.calls.where((x) => x.startsWith('submit')).toList(),
          equals(['submit:milk:close:1234', 'submit:cafe:close:0']));
      expect(c.allDailyCounted, isTrue);
    });

    test('ĐẾM MÙ: sau khi lưu, số vừa nhập biến mất khỏi bộ nhớ', () async {
      c.setDraft('milk', 777);
      await c.saveAll();
      expect(c.pendingCount, equals(0));
      expect(c.hasPending, isFalse);
      final milk = c.items.firstWhere((i) => i.id == 'milk');
      expect(milk.counted, isTrue);
      expect(c.needsInput(milk), isFalse); // dòng chỉ còn "Đã đếm", không có ô chứa số cũ
    });

    test('xóa ô (null) thì bỏ số đã gõ; số âm bị bỏ', () {
      c.setDraft('milk', 5);
      c.setDraft('milk', null);
      expect(c.pendingCount, equals(0));
      c.setDraft('cafe', -3);
      expect(c.pendingCount, equals(0));
    });

    test('không có gì để lưu thì không gọi database', () async {
      final saved = await c.saveAll();
      expect(saved, equals(0));
      expect(repo.count('submit'), equals(0));
    });

    test('lỗi giữa chừng: dòng đã lưu vẫn tính, dòng lỗi còn nguyên để thử lại', () async {
      c.setDraft('milk', 10);
      c.setDraft('cafe', 20);
      // hẹn lỗi cho lệnh submit đầu tiên? Lệnh đầu là milk -> lỗi ngay, không lưu gì
      repo.failNext('submit', const NoNetworkFailure());
      await expectLater(c.saveAll(), throwsA(isA<NoNetworkFailure>()));
      expect(c.pendingCount, equals(2)); // chưa mất số nào
      expect(repo.saved, isEmpty);
      final saved = await c.saveAll();
      expect(saved, equals(2));
      expect(repo.saved, equals(['milk=10', 'cafe=20']));
    });

    test('bấm lưu hai lần liên tiếp chỉ lưu một lần', () async {
      c.setDraft('milk', 10);
      final a = c.saveAll();
      final b = await c.saveAll();
      expect(b, isNull);
      expect(await a, equals(1));
      expect(repo.saved, equals(['milk=10']));
    });
  });

  group('đếm lại', () {
    test('dòng đã đếm có thể chọn đếm lại: lại có ô trống để nhập', () async {
      c.setDraft('milk', 10);
      await c.saveAll();
      final milk = c.items.firstWhere((i) => i.id == 'milk');
      expect(c.needsInput(milk), isFalse);
      c.startRecount(milk);
      expect(c.needsInput(milk), isTrue);
      c.setDraft('milk', 11);
      await c.saveAll();
      expect(repo.saved, equals(['milk=10', 'milk=11'])); // số lưu sau cùng được dùng
      expect(c.needsInput(c.items.firstWhere((i) => i.id == 'milk')), isFalse);
    });
  });

  test('loại đầu ca dùng đúng kind', () async {
    final open = StocktakeController(repo, CountKind.open);
    await open.load();
    open.setDraft('milk', 5);
    await open.saveAll();
    expect(repo.calls, contains('submit:milk:open:5'));
  });
}
