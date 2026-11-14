import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/data/json_row.dart';
import '../../../core/data/rpc_client.dart';
import 'menu_models.dart';

/// Giao tiếp dữ liệu của màn Thực đơn (chủ quán). Mọi lệnh ghi đi qua hàm
/// trong `database/05_menu_management.sql`; lỗi nghiệp vụ trả về `DatabaseFailure(mã)`.
abstract interface class MenuRepository {
  /// JSON thô của `menu_overview()` (để lưu bản sao dùng khi mất mạng).
  Future<Map<String, dynamic>> overviewJson();

  Future<ItemDetail> itemDetail(String itemId);
  Future<List<RecipeVersion>> recipeVersions(String sizeId);
  Future<MenuHistory> history(String itemId);
  Future<IngredientCatalog> ingredients();
  Future<List<CopyTarget>> copyTargets();

  Future<String> createItem({
    required String name,
    required String? category,
    required List<({String name, int price})> sizes,
    required bool publish,
  });
  Future<void> updateItem({
    required String itemId,
    required String name,
    required String? category,
    String? description,
  });
  Future<void> addSize(String itemId, String name, int price);
  Future<void> removeSize(String sizeId);
  Future<void> setActive(String itemId, bool active);
  Future<void> publish(String itemId);

  Future<void> saveRecipe(
    String sizeId,
    List<DraftRecipeLine> lines, {
    DateTime? effectiveFrom,
    String? note,
  });
  Future<void> cancelRecipe(String versionId);
  Future<void> changePrices(
    List<({String sizeId, int price})> changes, {
    DateTime? effectiveFrom,
  });
  Future<void> cancelPriceChange(String changeId);
  Future<void> setIngredientCost(String ingredientId, num? cost);

  Future<void> addCategory(String name);
  Future<void> renameCategory(String id, String name);
  Future<void> reorderCategories(List<String> ids);

  Future<CopyResult> copyItem(String itemId, String newName);
  Future<CopyPreview> copyPreview(String itemId, String shopId, String? newName);
  Future<CopyResult> copyToShop(
    String itemId,
    String shopId,
    String? newName, {
    Map<String, String> mapping = const {},
    bool copyToppings = false,
    bool copyOptions = false,
  });

  Future<void> setImage(String itemId, String? path);

  Future<ItemExtras> itemExtras(String itemId);
  Future<List<ToppingInfo>> toppings();
  Future<String> saveTopping({
    String? id,
    required String name,
    required int price,
    String? ingredientId,
    int? qty,
    bool active = true,
  });
  Future<void> saveItemToppings(
      String itemId, List<String> ids, int maxKinds, int maxPortions);
  Future<void> saveOptions(String itemId, List<DraftOptionGroup> groups);
}

class RpcMenuRepository implements MenuRepository {
  RpcMenuRepository(this._rpc);

  final RpcClient _rpc;

  @override
  Future<Map<String, dynamic>> overviewJson() async =>
      asObject(await _rpc.call('menu_overview'));

  @override
  Future<ItemDetail> itemDetail(String itemId) async => ItemDetail.fromJson(
      asObject(await _rpc.call('menu_item_detail', {'p_item': itemId})));

  @override
  Future<List<RecipeVersion>> recipeVersions(String sizeId) async => [
        for (final r in asRows(
            await _rpc.call('menu_recipe_versions', {'p_size': sizeId})))
          RecipeVersion.fromJson(r),
      ];

  @override
  Future<MenuHistory> history(String itemId) async => MenuHistory.fromJson(
      asObject(await _rpc.call('menu_item_history', {'p_item': itemId})));

  @override
  Future<IngredientCatalog> ingredients() async =>
      IngredientCatalog.fromJson(asObject(await _rpc.call('menu_ingredients')));

  @override
  Future<List<CopyTarget>> copyTargets() async => [
        for (final r in asRows(await _rpc.call('menu_copy_targets')))
          CopyTarget.fromJson(r),
      ];

  @override
  Future<String> createItem({
    required String name,
    required String? category,
    required List<({String name, int price})> sizes,
    required bool publish,
  }) async {
    final id = await _rpc.call('menu_item_create', {
      'p_name': name,
      'p_category': category,
      'p_sizes': [
        for (final s in sizes) {'name': s.name, 'price': s.price},
      ],
      'p_publish': publish,
    });
    return '$id';
  }

  @override
  Future<void> updateItem({
    required String itemId,
    required String name,
    required String? category,
    String? description,
  }) =>
      _rpc.call('menu_item_update', {
        'p_item': itemId,
        'p_name': name,
        'p_category': category,
        'p_description': description,
      });

  @override
  Future<void> addSize(String itemId, String name, int price) => _rpc
      .call('menu_size_add', {'p_item': itemId, 'p_name': name, 'p_price': price});

  @override
  Future<void> removeSize(String sizeId) =>
      _rpc.call('menu_size_remove', {'p_size': sizeId});

  @override
  Future<void> setActive(String itemId, bool active) =>
      _rpc.call('menu_item_set_active', {'p_item': itemId, 'p_active': active});

  @override
  Future<void> publish(String itemId) =>
      _rpc.call('menu_item_publish', {'p_item': itemId});

  @override
  Future<void> saveRecipe(
    String sizeId,
    List<DraftRecipeLine> lines, {
    DateTime? effectiveFrom,
    String? note,
  }) =>
      _rpc.call('menu_recipe_save', {
        'p_size': sizeId,
        'p_lines': [for (final l in lines) l.toJson()],
        'p_effective': effectiveFrom?.toUtc().toIso8601String(),
        'p_note': note,
      });

  @override
  Future<void> cancelRecipe(String versionId) =>
      _rpc.call('menu_recipe_cancel', {'p_version': versionId});

  @override
  Future<void> changePrices(
    List<({String sizeId, int price})> changes, {
    DateTime? effectiveFrom,
  }) =>
      _rpc.call('menu_price_change', {
        'p_changes': [
          for (final c in changes) {'size_id': c.sizeId, 'price': c.price},
        ],
        'p_effective': effectiveFrom?.toUtc().toIso8601String(),
      });

  @override
  Future<void> cancelPriceChange(String changeId) =>
      _rpc.call('menu_price_cancel', {'p_change': changeId});

  @override
  Future<void> setIngredientCost(String ingredientId, num? cost) => _rpc.call(
      'set_ingredient_cost', {'p_ingredient': ingredientId, 'p_cost': cost});

  @override
  Future<void> addCategory(String name) =>
      _rpc.call('menu_category_add', {'p_name': name});

  @override
  Future<void> renameCategory(String id, String name) =>
      _rpc.call('menu_category_rename', {'p_id': id, 'p_name': name});

  @override
  Future<void> reorderCategories(List<String> ids) =>
      _rpc.call('menu_category_reorder', {'p_ids': ids});

  @override
  Future<CopyResult> copyItem(String itemId, String newName) async =>
      CopyResult.fromJson(asObject(await _rpc
          .call('menu_item_copy', {'p_item': itemId, 'p_new_name': newName})));

  @override
  Future<CopyPreview> copyPreview(
          String itemId, String shopId, String? newName) async =>
      CopyPreview.fromJson(asObject(await _rpc.call('menu_copy_preview', {
        'p_item': itemId,
        'p_shop': shopId,
        'p_new_name': newName,
      })));

  @override
  Future<CopyResult> copyToShop(
    String itemId,
    String shopId,
    String? newName, {
    Map<String, String> mapping = const {},
    bool copyToppings = false,
    bool copyOptions = false,
  }) async =>
      CopyResult.fromJson(asObject(await _rpc.call('menu_item_copy_to_shop', {
        'p_item': itemId,
        'p_shop': shopId,
        'p_new_name': newName,
        'p_mapping': mapping,
        'p_copy_toppings': copyToppings,
        'p_copy_options': copyOptions,
      })));

  @override
  Future<void> setImage(String itemId, String? path) =>
      _rpc.call('menu_item_set_image', {'p_item': itemId, 'p_path': path});

  @override
  Future<ItemExtras> itemExtras(String itemId) async => ItemExtras.fromJson(
      asObject(await _rpc.call('menu_item_extras', {'p_item': itemId})));

  @override
  Future<List<ToppingInfo>> toppings() async => [
        for (final r in asRows(await _rpc.call('menu_toppings_list')))
          ToppingInfo.fromJson(r),
      ];

  @override
  Future<String> saveTopping({
    String? id,
    required String name,
    required int price,
    String? ingredientId,
    int? qty,
    bool active = true,
  }) async =>
      '${await _rpc.call('menu_topping_save', {
        'p_id': id,
        'p_name': name,
        'p_price': price,
        'p_ingredient': ingredientId,
        'p_qty': ingredientId == null ? null : qty,
        'p_active': active,
      })}';

  @override
  Future<void> saveItemToppings(
          String itemId, List<String> ids, int maxKinds, int maxPortions) =>
      _rpc.call('menu_item_toppings_save', {
        'p_item': itemId,
        'p_ids': ids,
        'p_max_kinds': maxKinds,
        'p_max_portions': maxPortions,
      });

  @override
  Future<void> saveOptions(String itemId, List<DraftOptionGroup> groups) =>
      _rpc.call('menu_item_options_save', {
        'p_item': itemId,
        'p_groups': [for (final g in groups) g.toJson()],
      });
}

/// Bản sao thực đơn lưu trên máy để vẫn xem được khi mất mạng.
abstract interface class MenuCache {
  Future<Map<String, dynamic>?> read(String shopKey);
  Future<void> write(String shopKey, Map<String, dynamic> overview);
}

class MemoryMenuCache implements MenuCache {
  final Map<String, Map<String, dynamic>> _data = {};

  @override
  Future<Map<String, dynamic>?> read(String shopKey) async => _data[shopKey];

  @override
  Future<void> write(String shopKey, Map<String, dynamic> overview) async =>
      _data[shopKey] = overview;
}

class PreferencesMenuCache implements MenuCache {
  String _key(String shopKey) => 'fore.menu_overview.$shopKey';

  @override
  Future<Map<String, dynamic>?> read(String shopKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = prefs.getString(_key(shopKey));
      if (text == null) return null;
      final decoded = jsonDecode(text);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String shopKey, Map<String, dynamic> overview) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(shopKey), jsonEncode(overview));
    } catch (_) {
      // Không lưu được bản sao thì thôi: không ảnh hưởng việc dùng bình thường.
    }
  }
}
