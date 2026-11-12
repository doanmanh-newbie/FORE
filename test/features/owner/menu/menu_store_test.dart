import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/owner/menu/menu_format.dart';
import 'package:fore/features/owner/menu/menu_models.dart';
import 'package:fore/features/owner/menu/menu_recipe_views.dart';
import 'package:fore/features/owner/menu/menu_repository.dart';
import 'package:fore/features/owner/menu/menu_store.dart';

import '../../../support/fake_menu_repository.dart';

void main() {
  MenuOverview overview() => MenuOverview.fromJson(sampleMenuOverview());

  group('lọc và sắp xếp', () {
    test('tìm không dấu và không phân biệt hoa thường', () {
      final result =
          filterMenuItems(overview(), const MenuFilters(query: 'tra dao'));
      expect(result.map((i) => i.name), ['Trà đào']);
    });

    test('lọc theo nhóm', () {
      final result =
          filterMenuItems(overview(), const MenuFilters(category: 'Cà phê'));
      expect(result.map((i) => i.name), ['Cà phê sữa']);
    });

    test('lọc món thiếu công thức', () {
      final result = filterMenuItems(
          overview(), const MenuFilters(recipe: MenuRecipeFilter.missing));
      expect(result.map((i) => i.name), ['Trà đào']);
    });

    test('lọc món đang tạm ngừng', () {
      final result = filterMenuItems(
          overview(), const MenuFilters(status: MenuStatusFilter.paused));
      expect(result.map((i) => i.name), ['Cà phê sữa']);
    });

    test('lọc lãi gộp thấp: 29.000 giá vốn 25.000 là lãi 14%', () {
      final result = filterMenuItems(
          overview(), const MenuFilters(lowMarginOnly: true));
      expect(result.map((i) => i.name), ['Cà phê sữa']);
    });

    test('sắp theo giá giảm dần', () {
      final result = filterMenuItems(
          overview(), const MenuFilters(sort: MenuSort.priceDesc));
      expect(result.first.name, 'Trà đào');
    });

    test('sắp theo bán chạy', () {
      final result = filterMenuItems(
          overview(), const MenuFilters(sort: MenuSort.bestSeller));
      expect(result.first.name, 'QA-Trà');
    });

    test('bộ lọc mặc định là mặc định', () {
      expect(const MenuFilters().isDefault, isTrue);
      expect(const MenuFilters(lowMarginOnly: true).hasAdvanced, isTrue);
    });
  });

  group('MenuStore', () {
    test('tải thành công thì có dữ liệu và lưu bản sao', () async {
      final cache = MemoryMenuCache();
      final store = MenuStore(FakeMenuRepository(), shopKey: 'a', cache: cache);
      await store.load();
      expect(store.overview?.items.length, 3);
      expect(store.failure, isNull);
      expect(store.stale, isFalse);
      expect(await cache.read('a'), isNotNull);
    });

    test('mất mạng thì dùng bản đã lưu và báo là bản cũ', () async {
      final cache = MemoryMenuCache();
      await cache.write('a', sampleMenuOverview());
      final repo = FakeMenuRepository(
          overviewError: const SocketLikeError());
      final store = MenuStore(repo, shopKey: 'a', cache: cache);
      await store.load();
      expect(store.overview, isNotNull);
      expect(store.stale, isTrue);
      expect(store.failure, isNotNull);
    });

    test('lỗi mà chưa có bản lưu thì không có dữ liệu', () async {
      final store = MenuStore(
        FakeMenuRepository(overviewError: StateError('x')),
        shopKey: 'a',
        cache: MemoryMenuCache(),
      );
      await store.load();
      expect(store.overview, isNull);
      expect(store.stale, isFalse);
      expect(store.failure, isNotNull);
    });

    test('bản lưu của quán khác không bị dùng', () async {
      final cache = MemoryMenuCache();
      await cache.write('quan-khac', sampleMenuOverview());
      final store = MenuStore(
        FakeMenuRepository(overviewError: StateError('x')),
        shopKey: 'a',
        cache: cache,
      );
      await store.load();
      expect(store.overview, isNull);
    });

    test('ghi xong thì tự tải lại', () async {
      final repo = FakeMenuRepository();
      final store = MenuStore(repo, shopKey: 'a');
      await store.load();
      await store.setActive('i1', false);
      expect(repo.calls, ['overview', 'setActive:i1:false', 'overview']);
    });

    test('tên nhóm có thêm "Khác" khi có món chưa phân nhóm', () async {
      final store = MenuStore(FakeMenuRepository(), shopKey: 'a');
      await store.load();
      expect(store.categoryNames, ['Trà', 'Cà phê']);
    });
  });

  group('định dạng và công thức nháp', () {
    test('bỏ dấu tiếng Việt', () {
      expect(foldVietnamese('Cà phê SỮA đá'), 'ca phe sua da');
    });

    test('hẹn mặc định là 06:00', () {
      final early = nextBusinessDayStart(DateTime(2026, 11, 5, 3));
      expect(early, DateTime(2026, 11, 5, 6));
      final later = nextBusinessDayStart(DateTime(2026, 11, 5, 14));
      expect(later, DateTime(2026, 11, 6, 6));
    });

    test('giá vốn nháp: thiếu giá thì chưa xác định', () {
      const a = DraftRecipeLine(
          ingredientId: '1', name: 'Sữa', unit: 'ml', qty: 100, unitCost: 50);
      const b = DraftRecipeLine(
          ingredientId: '2', name: 'Đá', unit: 'g', qty: 100, unitCost: null);
      expect(draftCost([a]), 5000);
      expect(draftCost([a, b]), isNull);
    });

    test('mô tả khác biệt giữa hai công thức', () {
      const old = [
        DraftRecipeLine(
            ingredientId: '1', name: 'Sữa', unit: 'ml', qty: 140, unitCost: 50),
        DraftRecipeLine(
            ingredientId: '3', name: 'Đường', unit: 'g', qty: 10, unitCost: 20),
      ];
      const next = [
        DraftRecipeLine(
            ingredientId: '1', name: 'Sữa', unit: 'ml', qty: 160, unitCost: 50),
        DraftRecipeLine(
            ingredientId: '2', name: 'Đá', unit: 'g', qty: 100, unitCost: 1),
      ];
      final text = describeRecipeDiff(old, next);
      expect(text, contains('sữa 140 → 160 ml (+20 ml)'));
      expect(text, contains('thêm đá 100 g'));
      expect(text, contains('bỏ đường'));
      expect(sameLines(old, old), isTrue);
      expect(sameLines(old, next), isFalse);
    });
  });
}

/// Lỗi mạng giả: tên lớp chứa "SocketException" để `looksLikeNetworkError` nhận ra.
class SocketLikeError implements Exception {
  const SocketLikeError();

  @override
  String toString() => 'SocketException: Failed host lookup';
}
