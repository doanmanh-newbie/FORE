import 'package:fore/features/owner/menu/menu_models.dart';
import 'package:fore/features/owner/menu/menu_repository.dart';

/// JSON giống `menu_overview()` với vài món để test.
Map<String, dynamic> sampleMenuOverview() => {
      'low_margin_pct': 30,
      'week_from': '2026-11-02',
      'week_to': '2026-11-08',
      'cost_updated_at': null,
      'categories': [
        {'id': 'c1', 'name': 'Trà', 'sort_order': 1, 'item_count': 2},
        {'id': 'c2', 'name': 'Cà phê', 'sort_order': 2, 'item_count': 1},
      ],
      'items': [
        {
          'id': 'i1',
          'name': 'QA-Trà',
          'category': 'Trà',
          'active': true,
          'is_draft': false,
          'sold_week': 40,
          'best_seller': true,
          'sizes': [
            {
              'id': 's1',
              'name': 'Vừa',
              'price': 35000,
              'active': true,
              'has_recipe': true,
              'cost': 11200,
              'cost_known': true,
              'recipe_version': 1,
              'sold_week': 40,
            },
          ],
        },
        {
          'id': 'i2',
          'name': 'Trà đào',
          'category': 'Trà',
          'active': true,
          'is_draft': false,
          'sold_week': 5,
          'best_seller': false,
          'sizes': [
            {
              'id': 's2',
              'name': 'Lớn',
              'price': 45000,
              'active': true,
              'has_recipe': false,
              'cost': null,
              'cost_known': false,
              'sold_week': 5,
            },
          ],
        },
        {
          'id': 'i3',
          'name': 'Cà phê sữa',
          'category': 'Cà phê',
          'active': false,
          'is_draft': false,
          'sold_week': 0,
          'best_seller': false,
          'sizes': [
            {
              'id': 's3',
              'name': 'Vừa',
              'price': 29000,
              'active': true,
              'has_recipe': true,
              'cost': 25000,
              'cost_known': true,
              'recipe_version': 1,
              'sold_week': 0,
            },
          ],
        },
      ],
    };

/// Bản giả của [MenuRepository]: chỉ phần đọc danh sách chạy thật, còn lại ghi lại lời gọi.
class FakeMenuRepository implements MenuRepository {
  FakeMenuRepository({this.overviewError});

  Object? overviewError;
  final List<String> calls = [];

  @override
  Future<Map<String, dynamic>> overviewJson() async {
    calls.add('overview');
    final error = overviewError;
    if (error != null) throw error;
    return sampleMenuOverview();
  }

  @override
  Future<void> setActive(String itemId, bool active) async =>
      calls.add('setActive:$itemId:$active');

  @override
  Future<void> publish(String itemId) async => calls.add('publish:$itemId');

  @override
  Future<void> addCategory(String name) async => calls.add('addCategory:$name');

  @override
  Future<void> renameCategory(String id, String name) async =>
      calls.add('renameCategory:$id:$name');

  @override
  Future<void> reorderCategories(List<String> ids) async =>
      calls.add('reorder:${ids.join(',')}');

  @override
  Future<void> changePrices(
    List<({String sizeId, int price})> changes, {
    DateTime? effectiveFrom,
  }) async =>
      calls.add('prices:${changes.length}');

  @override
  Future<void> saveRecipe(
    String sizeId,
    List<DraftRecipeLine> lines, {
    DateTime? effectiveFrom,
    String? note,
  }) async =>
      calls.add('recipe:$sizeId:${lines.length}');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('FakeMenuRepository.${invocation.memberName}');
}
