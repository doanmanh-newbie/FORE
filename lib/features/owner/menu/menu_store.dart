import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/network_errors.dart';
import 'menu_format.dart';
import 'menu_models.dart';
import 'menu_repository.dart';

enum MenuStatusFilter { all, selling, paused, draft }

enum MenuRecipeFilter { all, complete, missing }

enum MenuSort { nameAsc, nameDesc, priceAsc, priceDesc, bestSeller }

/// Bộ lọc của danh sách món. Mặc định = hiện tất cả, sắp theo tên A → Z.
@immutable
class MenuFilters {
  const MenuFilters({
    this.query = '',
    this.category,
    this.status = MenuStatusFilter.all,
    this.recipe = MenuRecipeFilter.all,
    this.lowMarginOnly = false,
    this.sort = MenuSort.nameAsc,
  });

  final String query;
  final String? category;
  final MenuStatusFilter status;
  final MenuRecipeFilter recipe;
  final bool lowMarginOnly;
  final MenuSort sort;

  MenuFilters copyWith({
    String? query,
    Object? category = _keep,
    MenuStatusFilter? status,
    MenuRecipeFilter? recipe,
    bool? lowMarginOnly,
    MenuSort? sort,
  }) =>
      MenuFilters(
        query: query ?? this.query,
        category: identical(category, _keep) ? this.category : category as String?,
        status: status ?? this.status,
        recipe: recipe ?? this.recipe,
        lowMarginOnly: lowMarginOnly ?? this.lowMarginOnly,
        sort: sort ?? this.sort,
      );

  static const _keep = Object();

  /// Có bộ lọc nào ngoài ô tìm kiếm không (để hiện chấm trên nút "Lọc").
  bool get hasAdvanced =>
      status != MenuStatusFilter.all ||
      recipe != MenuRecipeFilter.all ||
      lowMarginOnly ||
      sort != MenuSort.nameAsc;

  bool get isDefault => !hasAdvanced && category == null && query.trim().isEmpty;
}

/// Áp bộ lọc và sắp xếp lên danh sách món (dùng cho danh sách và để đếm "Áp dụng · N món").
List<MenuItem> filterMenuItems(MenuOverview data, MenuFilters filters) {
  final q = foldVietnamese(filters.query);
  final cat = filters.category;
  final result = data.items.where((item) {
    if (q.isNotEmpty && !foldVietnamese(item.name).contains(q)) return false;
    if (cat != null) {
      final name = (item.category ?? '').trim().isEmpty ? 'Khác' : item.category!;
      if (foldVietnamese(name) != foldVietnamese(cat)) return false;
    }
    switch (filters.status) {
      case MenuStatusFilter.all:
        break;
      case MenuStatusFilter.selling:
        if (item.status != MenuItemStatus.selling) return false;
      case MenuStatusFilter.paused:
        if (item.status != MenuItemStatus.paused) return false;
      case MenuStatusFilter.draft:
        if (item.status != MenuItemStatus.draft) return false;
    }
    switch (filters.recipe) {
      case MenuRecipeFilter.all:
        break;
      case MenuRecipeFilter.complete:
        if (item.missingRecipe) return false;
      case MenuRecipeFilter.missing:
        if (!item.missingRecipe) return false;
    }
    if (filters.lowMarginOnly && !item.isLowMargin(data.lowMarginPct)) {
      return false;
    }
    return true;
  }).toList();

  int minPrice(MenuItem i) =>
      i.activeSizes.isEmpty ? 0 : i.activeSizes.first.price;
  int byName(MenuItem a, MenuItem b) =>
      foldVietnamese(a.name).compareTo(foldVietnamese(b.name));
  switch (filters.sort) {
    case MenuSort.nameAsc:
      result.sort(byName);
    case MenuSort.nameDesc:
      result.sort((a, b) => byName(b, a));
    case MenuSort.priceAsc:
      result.sort((a, b) {
        final c = minPrice(a).compareTo(minPrice(b));
        return c != 0 ? c : byName(a, b);
      });
    case MenuSort.priceDesc:
      result.sort((a, b) {
        final c = minPrice(b).compareTo(minPrice(a));
        return c != 0 ? c : byName(a, b);
      });
    case MenuSort.bestSeller:
      result.sort((a, b) {
        final c = b.soldWeek.compareTo(a.soldWeek);
        return c != 0 ? c : byName(a, b);
      });
  }
  // Bản nháp luôn lên đầu để chủ quán không quên hoàn thiện (sort ổn định giữ thứ tự trên).
  final drafts = result.where((i) => i.status == MenuItemStatus.draft);
  final others = result.where((i) => i.status != MenuItemStatus.draft);
  return [...drafts, ...others];
}

/// Trạng thái màn Thực đơn: dữ liệu, bộ lọc, và các lệnh ghi (mỗi lệnh ghi xong tự tải lại).
class MenuStore extends ChangeNotifier {
  MenuStore(
    this._repository, {
    required this.shopKey,
    MenuCache? cache,
    DateTime Function()? clock,
  })  : _cache = cache ?? MemoryMenuCache(),
        _clock = clock ?? DateTime.now;

  final MenuRepository _repository;
  final MenuCache _cache;
  final DateTime Function() _clock;

  /// Khóa của quán đang chọn (để bản sao trên máy không lẫn giữa các quán).
  final String shopKey;

  MenuRepository get repository => _repository;

  MenuOverview? overview;
  bool loading = false;
  Object? failure;

  /// Đang hiện bản đã lưu vì lần tải mới nhất lỗi.
  bool stale = false;

  MenuFilters filters = const MenuFilters();
  int _generation = 0;
  bool _disposed = false;

  bool get networkFailure => failure != null && _isNetwork(failure!);

  bool get isOffline => stale && networkFailure;

  static bool _isNetwork(Object e) =>
      e is NoNetworkFailure || looksLikeNetworkError(e);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  Future<void> load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent || overview == null) {
      loading = true;
      notifyListeners();
    }
    try {
      final raw = await _repository.overviewJson();
      if (generation != _generation) return;
      raw['fetched_at'] = _clock().toUtc().toIso8601String();
      overview = MenuOverview.fromJson(raw, now: _clock());
      failure = null;
      stale = false;
      await _cache.write(shopKey, raw);
    } catch (error) {
      if (generation != _generation) return;
      failure = error;
      if (overview == null) {
        final cached = await _cache.read(shopKey);
        if (cached != null) {
          try {
            overview = MenuOverview.fromJson(cached, now: _clock());
          } catch (_) {
            overview = null;
          }
        }
      }
      stale = overview != null;
    } finally {
      if (generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  // ---------- Bộ lọc ----------

  void setFilters(MenuFilters next) {
    filters = next;
    notifyListeners();
  }

  void setQuery(String value) => setFilters(filters.copyWith(query: value));

  void setCategory(String? value) =>
      setFilters(filters.copyWith(category: value));

  void resetFilters() => setFilters(const MenuFilters());

  /// Món hiển thị sau khi áp bộ lọc và sắp xếp.
  List<MenuItem> get visibleItems {
    final data = overview;
    return data == null ? const [] : filterMenuItems(data, filters);
  }

  /// Tên các nhóm món để làm chip lọc ("Tất cả" do giao diện thêm).
  List<String> get categoryNames {
    final data = overview;
    if (data == null) return const [];
    final names = [for (final c in data.categories) c.name];
    final hasOther = data.items.any((i) => (i.category ?? '').trim().isEmpty);
    if (hasOther) names.add('Khác');
    return names;
  }

  // ---------- Đọc chi tiết (không lưu trong store) ----------

  Future<ItemDetail> loadDetail(String itemId) =>
      _repository.itemDetail(itemId);
  Future<List<RecipeVersion>> loadVersions(String sizeId) =>
      _repository.recipeVersions(sizeId);
  Future<MenuHistory> loadHistory(String itemId) =>
      _repository.history(itemId);
  Future<IngredientCatalog> loadIngredients() => _repository.ingredients();
  Future<List<CopyTarget>> loadCopyTargets() => _repository.copyTargets();

  // ---------- Ghi (xong tự tải lại, lỗi ném ra cho giao diện báo) ----------

  Future<T> _write<T>(Future<T> Function() action) async {
    final result = await action();
    await load(silent: true);
    return result;
  }

  Future<void> setActive(String itemId, bool active) =>
      _write(() => _repository.setActive(itemId, active));

  Future<void> publish(String itemId) =>
      _write(() => _repository.publish(itemId));

  Future<String> createItem({
    required String name,
    required String? category,
    required List<({String name, int price})> sizes,
    required bool publish,
  }) =>
      _write(() => _repository.createItem(
            name: name,
            category: category,
            sizes: sizes,
            publish: publish,
          ));

  Future<void> updateItem({
    required String itemId,
    required String name,
    required String? category,
    String? description,
  }) =>
      _write(() => _repository.updateItem(
            itemId: itemId,
            name: name,
            category: category,
            description: description,
          ));

  Future<void> addSize(String itemId, String name, int price) =>
      _write(() => _repository.addSize(itemId, name, price));

  Future<void> removeSize(String sizeId) =>
      _write(() => _repository.removeSize(sizeId));

  Future<void> saveRecipe(
    String sizeId,
    List<DraftRecipeLine> lines, {
    DateTime? effectiveFrom,
    String? note,
  }) =>
      _write(() => _repository.saveRecipe(sizeId, lines,
          effectiveFrom: effectiveFrom, note: note));

  Future<void> cancelRecipe(String versionId) =>
      _write(() => _repository.cancelRecipe(versionId));

  Future<void> changePrices(
    List<({String sizeId, int price})> changes, {
    DateTime? effectiveFrom,
  }) =>
      _write(() =>
          _repository.changePrices(changes, effectiveFrom: effectiveFrom));

  Future<void> cancelPriceChange(String changeId) =>
      _write(() => _repository.cancelPriceChange(changeId));

  Future<void> setIngredientCost(String ingredientId, num? cost) =>
      _write(() => _repository.setIngredientCost(ingredientId, cost));

  Future<void> addCategory(String name) =>
      _write(() => _repository.addCategory(name));

  Future<void> renameCategory(String id, String name) =>
      _write(() => _repository.renameCategory(id, name));

  Future<void> reorderCategories(List<String> ids) =>
      _write(() => _repository.reorderCategories(ids));

  Future<CopyResult> copyItem(String itemId, String newName) =>
      _write(() => _repository.copyItem(itemId, newName));

  Future<CopyPreview> copyPreview(String itemId, String shopId, String? newName) =>
      _repository.copyPreview(itemId, shopId, newName);

  Future<CopyResult> copyToShop(
    String itemId,
    String shopId,
    String? newName, {
    Map<String, String> mapping = const {},
    bool copyToppings = false,
    bool copyOptions = false,
  }) =>
      _write(() => _repository.copyToShop(itemId, shopId, newName,
          mapping: mapping, copyToppings: copyToppings, copyOptions: copyOptions));

  Future<void> setImage(String itemId, String? path) =>
      _write(() => _repository.setImage(itemId, path));

  Future<ItemExtras> loadExtras(String itemId) => _repository.itemExtras(itemId);
  Future<List<ToppingInfo>> loadToppings() => _repository.toppings();

  Future<String> saveTopping({
    String? id,
    required String name,
    required int price,
    String? ingredientId,
    int? qty,
    bool active = true,
  }) =>
      _repository.saveTopping(
          id: id, name: name, price: price, ingredientId: ingredientId, qty: qty, active: active);

  Future<void> saveItemToppings(
          String itemId, List<String> ids, int maxKinds, int maxPortions) =>
      _repository.saveItemToppings(itemId, ids, maxKinds, maxPortions);

  Future<void> saveOptions(String itemId, List<DraftOptionGroup> groups) =>
      _repository.saveOptions(itemId, groups);
}
