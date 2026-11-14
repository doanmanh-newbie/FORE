import '../../../core/data/json_row.dart';

num? _num(Object? v) => v is num ? v : null;

int? _intOrNull(Object? v) => v is num ? v.round() : null;

List<Map<String, dynamic>> _list(Object? v) => v is List
    ? [
        for (final e in v)
          if (e is Map<String, dynamic>) e,
      ]
    : const [];

/// Nhãn đơn vị hiển thị (database lưu ml, g, piece).
String menuUnitLabel(String unit) => unit == 'piece' ? 'cái' : unit;

/// Giá vốn một dòng/size; `null` nghĩa là chưa xác định (thiếu giá nguyên liệu).
class MenuSize {
  const MenuSize({
    required this.id,
    required this.name,
    required this.price,
    required this.active,
    required this.hasRecipe,
    required this.cost,
    required this.costKnown,
    required this.recipeVersion,
    required this.scheduledFrom,
    required this.pendingPrice,
    required this.soldWeek,
  });

  factory MenuSize.fromJson(Map<String, dynamic> j) => MenuSize(
        id: j.str('id'),
        name: j.str('name'),
        price: j.integer('price'),
        active: j.flag('active'),
        hasRecipe: j.flag('has_recipe'),
        cost: _intOrNull(j['cost']),
        costKnown: j['cost_known'] == true,
        recipeVersion: _intOrNull(j['recipe_version']),
        scheduledFrom: j.timeOrNull('scheduled_from'),
        pendingPrice: _intOrNull(j['pending_price']),
        soldWeek: _intOrNull(j['sold_week']) ?? 0,
      );

  final String id;
  final String name;
  final int price;
  final bool active;
  final bool hasRecipe;
  final int? cost;
  final bool costKnown;
  final int? recipeVersion;
  final DateTime? scheduledFrom;
  final int? pendingPrice;
  final int soldWeek;

  int? get margin => cost == null ? null : price - cost!;
  double? get marginPct =>
      cost == null || price <= 0 ? null : (price - cost!) * 100 / price;
}

enum MenuItemStatus { selling, paused, draft }

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.category,
    required this.active,
    required this.isDraft,
    required this.imagePath,
    required this.description,
    required this.soldWeek,
    required this.bestSeller,
    required this.sizes,
  });

  factory MenuItem.fromJson(Map<String, dynamic> j) => MenuItem(
        id: j.str('id'),
        name: j.str('name'),
        category: j.strOrNull('category'),
        active: j.flag('active'),
        isDraft: j.flag('is_draft'),
        imagePath: j.strOrNull('image_path'),
        description: j.strOrNull('description'),
        soldWeek: _intOrNull(j['sold_week']) ?? 0,
        bestSeller: j['best_seller'] == true,
        sizes: [for (final s in _list(j['sizes'])) MenuSize.fromJson(s)],
      );

  final String id;
  final String name;
  final String? category;
  final bool active;
  final bool isDraft;
  final String? imagePath;
  final String? description;
  final int soldWeek;
  final bool bestSeller;
  final List<MenuSize> sizes;

  List<MenuSize> get activeSizes =>
      sizes.where((s) => s.active).toList(growable: false);

  MenuItemStatus get status => isDraft
      ? MenuItemStatus.draft
      : active
          ? MenuItemStatus.selling
          : MenuItemStatus.paused;

  int get sizesMissingRecipe => activeSizes.where((s) => !s.hasRecipe).length;
  bool get missingRecipe => sizesMissingRecipe > 0;

  /// Size có lãi gộp thấp nhất (chỉ xét size đã có giá vốn).
  MenuSize? get worstMarginSize {
    MenuSize? worst;
    for (final s in activeSizes) {
      if (s.marginPct == null) continue;
      if (worst == null || s.marginPct! < worst.marginPct!) worst = s;
    }
    return worst;
  }

  bool isLowMargin(int thresholdPct) =>
      activeSizes.any((s) => s.marginPct != null && s.marginPct! < thresholdPct);
}

class MenuCategory {
  const MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.itemCount,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> j) => MenuCategory(
        id: j.str('id'),
        name: j.str('name'),
        sortOrder: j.integer('sort_order'),
        itemCount: _intOrNull(j['item_count']) ?? 0,
      );

  final String id;
  final String name;
  final int sortOrder;
  final int itemCount;
}

class MenuOverview {
  const MenuOverview({
    required this.lowMarginPct,
    required this.weekFrom,
    required this.weekTo,
    required this.costUpdatedAt,
    required this.categories,
    required this.items,
    required this.fetchedAt,
  });

  factory MenuOverview.fromJson(Map<String, dynamic> j, {DateTime? now}) =>
      MenuOverview(
        lowMarginPct: _intOrNull(j['low_margin_pct']) ?? 30,
        weekFrom: DateTime.tryParse('${j['week_from']}'),
        weekTo: DateTime.tryParse('${j['week_to']}'),
        costUpdatedAt: j.timeOrNull('cost_updated_at'),
        categories: [
          for (final c in _list(j['categories'])) MenuCategory.fromJson(c),
        ],
        items: [for (final i in _list(j['items'])) MenuItem.fromJson(i)],
        fetchedAt: j.timeOrNull('fetched_at') ?? now ?? DateTime.now(),
      );

  final int lowMarginPct;
  final DateTime? weekFrom;
  final DateTime? weekTo;
  final DateTime? costUpdatedAt;
  final List<MenuCategory> categories;
  final List<MenuItem> items;

  /// Thời điểm tải về máy (dùng cho "Lần đồng bộ cuối" khi mất mạng).
  final DateTime fetchedAt;

  bool get isEmpty => items.isEmpty;

  int get sellingCount =>
      items.where((i) => i.status == MenuItemStatus.selling).length;
  int get itemsMissingRecipe => items
      .where((i) => i.status != MenuItemStatus.draft && i.missingRecipe)
      .length;
  int get lowMarginSizeCount => items
      .where((i) => i.status != MenuItemStatus.draft)
      .expand((i) => i.activeSizes)
      .where((s) => s.marginPct != null && s.marginPct! < lowMarginPct)
      .length;
  MenuItem? get firstLowMarginItem {
    for (final i in items) {
      if (i.status != MenuItemStatus.draft && i.isLowMargin(lowMarginPct)) {
        return i;
      }
    }
    return null;
  }

  MenuItem? itemById(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

}

class RecipeLine {
  const RecipeLine({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitCost,
    required this.lineCost,
  });

  factory RecipeLine.fromJson(Map<String, dynamic> j) => RecipeLine(
        ingredientId: j.str('ingredient_id'),
        name: j.str('name'),
        unit: j.str('unit'),
        qty: j.integer('qty'),
        unitCost: _num(j['unit_cost']),
        lineCost: _intOrNull(j['line_cost']),
      );

  final String ingredientId;
  final String name;
  final String unit;
  final int qty;
  final num? unitCost;
  final int? lineCost;
}

/// Một phiên bản công thức (đang dùng, đã hẹn, hoặc cũ).
class RecipeBlock {
  const RecipeBlock({
    required this.versionId,
    required this.versionNo,
    required this.effectiveFrom,
    required this.lines,
    required this.cost,
    required this.costKnown,
    this.createdByName,
    this.createdAt,
  });

  factory RecipeBlock.fromJson(Map<String, dynamic> j) => RecipeBlock(
        versionId: j.str('version_id'),
        versionNo: j.integer('version_no'),
        effectiveFrom: j.timeOrNull('effective_from'),
        lines: [for (final l in _list(j['lines'])) RecipeLine.fromJson(l)],
        cost: _intOrNull(j['cost']),
        costKnown: j['cost_known'] == true,
        createdByName: j.strOrNull('created_by_name'),
        createdAt: j.timeOrNull('created_at'),
      );

  final String versionId;
  final int versionNo;
  final DateTime? effectiveFrom;
  final List<RecipeLine> lines;
  final int? cost;
  final bool costKnown;
  final String? createdByName;
  final DateTime? createdAt;
}

class PendingPrice {
  const PendingPrice({
    required this.changeId,
    required this.newPrice,
    required this.effectiveFrom,
  });

  factory PendingPrice.fromJson(Map<String, dynamic> j) => PendingPrice(
        changeId: j.str('change_id'),
        newPrice: j.integer('new_price'),
        effectiveFrom: j.time('effective_from'),
      );

  final String changeId;
  final int newPrice;
  final DateTime effectiveFrom;
}

class SizeDetail {
  const SizeDetail({
    required this.id,
    required this.name,
    required this.price,
    required this.active,
    required this.everSold,
    required this.current,
    required this.scheduled,
    required this.pendingPrice,
  });

  factory SizeDetail.fromJson(Map<String, dynamic> j) => SizeDetail(
        id: j.str('id'),
        name: j.str('name'),
        price: j.integer('price'),
        active: j.flag('active'),
        everSold: j['ever_sold'] == true,
        current: j['current'] is Map<String, dynamic>
            ? RecipeBlock.fromJson(j['current'] as Map<String, dynamic>)
            : null,
        scheduled: j['scheduled'] is Map<String, dynamic>
            ? RecipeBlock.fromJson(j['scheduled'] as Map<String, dynamic>)
            : null,
        pendingPrice: j['pending_price'] is Map<String, dynamic>
            ? PendingPrice.fromJson(j['pending_price'] as Map<String, dynamic>)
            : null,
      );

  final String id;
  final String name;
  final int price;
  final bool active;
  final bool everSold;
  final RecipeBlock? current;
  final RecipeBlock? scheduled;
  final PendingPrice? pendingPrice;

  int? get cost => current?.costKnown == true ? current!.cost : null;
  int? get margin => cost == null ? null : price - cost!;
  double? get marginPct =>
      cost == null || price <= 0 ? null : (price - cost!) * 100 / price;
}

class ItemDetail {
  const ItemDetail({
    required this.id,
    required this.name,
    required this.category,
    required this.active,
    required this.isDraft,
    required this.description,
    required this.imagePath,
    required this.lowMarginPct,
    required this.sizes,
  });

  factory ItemDetail.fromJson(Map<String, dynamic> j) {
    final item = asObject(j['item']);
    return ItemDetail(
      id: item.str('id'),
      name: item.str('name'),
      category: item.strOrNull('category'),
      active: item.flag('active'),
      isDraft: item.flag('is_draft'),
      description: item.strOrNull('description'),
      imagePath: item.strOrNull('image_path'),
      lowMarginPct: _intOrNull(j['low_margin_pct']) ?? 30,
      sizes: [for (final s in _list(j['sizes'])) SizeDetail.fromJson(s)],
    );
  }

  final String id;
  final String name;
  final String? category;
  final bool active;
  final bool isDraft;
  final String? description;
  final String? imagePath;
  final int lowMarginPct;
  final List<SizeDetail> sizes;

  List<SizeDetail> get activeSizes =>
      sizes.where((s) => s.active).toList(growable: false);

  SizeDetail? sizeById(String id) {
    for (final s in sizes) {
      if (s.id == id) return s;
    }
    return null;
  }

  MenuItemStatus get status => isDraft
      ? MenuItemStatus.draft
      : active
          ? MenuItemStatus.selling
          : MenuItemStatus.paused;
}

class RecipeVersion {
  const RecipeVersion({
    required this.id,
    required this.versionNo,
    required this.status,
    required this.effectiveFrom,
    required this.createdAt,
    required this.createdByName,
    required this.lines,
    required this.cost,
    required this.costKnown,
  });

  factory RecipeVersion.fromJson(Map<String, dynamic> j) => RecipeVersion(
        id: j.str('id'),
        versionNo: j.integer('version_no'),
        status: j.str('status'),
        effectiveFrom: j.timeOrNull('effective_from'),
        createdAt: j.timeOrNull('created_at'),
        createdByName: j.strOrNull('created_by_name'),
        lines: [for (final l in _list(j['lines'])) RecipeLine.fromJson(l)],
        cost: _intOrNull(j['cost']),
        costKnown: j['cost_known'] == true,
      );

  final String id;
  final int versionNo;
  final String status; // scheduled | active | superseded
  final DateTime? effectiveFrom;
  final DateTime? createdAt;
  final String? createdByName;
  final List<RecipeLine> lines;
  final int? cost;
  final bool costKnown;
}

class HistoryEvent {
  const HistoryEvent({
    required this.id,
    required this.kind,
    required this.summary,
    required this.detail,
    required this.actorName,
    required this.createdAt,
  });

  factory HistoryEvent.fromJson(Map<String, dynamic> j) => HistoryEvent(
        id: j.str('id'),
        kind: j.str('kind'),
        summary: j.str('summary'),
        detail: j['detail'] is Map<String, dynamic>
            ? j['detail'] as Map<String, dynamic>
            : const {},
        actorName: j.strOrNull('actor_name'),
        createdAt: j.time('created_at'),
      );

  final String id;
  final String kind;
  final String summary;
  final Map<String, dynamic> detail;
  final String? actorName;
  final DateTime createdAt;
}

class UpcomingChange {
  const UpcomingChange({
    required this.kind,
    required this.id,
    required this.sizeName,
    required this.versionNo,
    required this.oldPrice,
    required this.newPrice,
    required this.effectiveFrom,
    required this.actorName,
  });

  factory UpcomingChange.fromJson(Map<String, dynamic> j) => UpcomingChange(
        kind: j.str('kind'),
        id: j.str('id'),
        sizeName: j.str('size_name'),
        versionNo: _intOrNull(j['version_no']),
        oldPrice: _intOrNull(j['old_price']),
        newPrice: _intOrNull(j['new_price']),
        effectiveFrom: j.time('effective_from'),
        actorName: j.strOrNull('actor_name'),
      );

  final String kind; // recipe | price
  final String id;
  final String sizeName;
  final int? versionNo;
  final int? oldPrice;
  final int? newPrice;
  final DateTime effectiveFrom;
  final String? actorName;
}

class MenuHistory {
  const MenuHistory({required this.upcoming, required this.events});

  factory MenuHistory.fromJson(Map<String, dynamic> j) => MenuHistory(
        upcoming: [
          for (final u in _list(j['upcoming'])) UpcomingChange.fromJson(u),
        ],
        events: [for (final e in _list(j['events'])) HistoryEvent.fromJson(e)],
      );

  final List<UpcomingChange> upcoming;
  final List<HistoryEvent> events;
}

class IngredientInfo {
  const IngredientInfo({
    required this.id,
    required this.name,
    required this.unit,
    required this.unitCost,
    required this.unitCostUpdatedAt,
  });

  factory IngredientInfo.fromJson(Map<String, dynamic> j) => IngredientInfo(
        id: j.str('id'),
        name: j.str('name'),
        unit: j.str('unit'),
        unitCost: _num(j['unit_cost']),
        unitCostUpdatedAt: j.timeOrNull('unit_cost_updated_at'),
      );

  final String id;
  final String name;
  final String unit;
  final num? unitCost;
  final DateTime? unitCostUpdatedAt;
}

class IngredientCatalog {
  const IngredientCatalog({required this.items, required this.costUpdatedAt});

  factory IngredientCatalog.fromJson(Map<String, dynamic> j) =>
      IngredientCatalog(
        items: [for (final i in _list(j['items'])) IngredientInfo.fromJson(i)],
        costUpdatedAt: j.timeOrNull('cost_updated_at'),
      );

  final List<IngredientInfo> items;
  final DateTime? costUpdatedAt;
}

class CopyTarget {
  const CopyTarget({required this.shopId, required this.name});

  factory CopyTarget.fromJson(Map<String, dynamic> j) =>
      CopyTarget(shopId: j.str('shop_id'), name: j.str('name'));

  final String shopId;
  final String name;
}

class CopyResult {
  const CopyResult({
    required this.itemId,
    required this.copiedLines,
    required this.skippedIngredients,
    this.copiedToppings = 0,
    this.skippedToppings = const [],
    this.copiedOptionGroups = 0,
  });

  factory CopyResult.fromJson(Map<String, dynamic> j) => CopyResult(
        itemId: j.str('item_id'),
        copiedLines: _intOrNull(j['copied_lines']) ?? 0,
        skippedIngredients: [
          for (final s in (j['skipped_ingredients'] as List? ?? const []))
            '$s',
        ],
        copiedToppings: _intOrNull(j['copied_toppings']) ?? 0,
        skippedToppings: [
          for (final s in (j['skipped_toppings'] as List? ?? const [])) '$s',
        ],
        copiedOptionGroups: _intOrNull(j['copied_option_groups']) ?? 0,
      );

  final String itemId;
  final int copiedLines;
  final List<String> skippedIngredients;
  final int copiedToppings;
  final List<String> skippedToppings;
  final int copiedOptionGroups;
}

/// Một nguyên liệu của công thức nguồn và nguyên liệu khớp tự động ở quán nhận (nếu có).
class CopyLine {
  const CopyLine({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.sizes,
    required this.matchId,
    required this.matchName,
  });

  factory CopyLine.fromJson(Map<String, dynamic> j) => CopyLine(
        ingredientId: j.str('ingredient_id'),
        name: j.str('name'),
        unit: j.str('unit'),
        qty: _intOrNull(j['qty']) ?? 0,
        sizes: [for (final s in (j['sizes'] as List? ?? const [])) '$s'],
        matchId: j.strOrNull('match_id'),
        matchName: j.strOrNull('match_name'),
      );

  final String ingredientId;
  final String name;
  final String unit;
  final int qty;
  final List<String> sizes;
  final String? matchId;
  final String? matchName;
}

class DestIngredient {
  const DestIngredient({required this.id, required this.name, required this.unit});

  factory DestIngredient.fromJson(Map<String, dynamic> j) =>
      DestIngredient(id: j.str('id'), name: j.str('name'), unit: j.str('unit'));

  final String id;
  final String name;
  final String unit;
}

/// Kết quả xem trước khi sao chép món: tên có trùng không, nguyên liệu nào khớp.
class CopyPreview {
  const CopyPreview({
    required this.nameTaken,
    required this.category,
    required this.categoryExists,
    required this.sizes,
    required this.lines,
    required this.destIngredients,
    required this.toppingCount,
    required this.optionGroupCount,
  });

  factory CopyPreview.fromJson(Map<String, dynamic> j) => CopyPreview(
        nameTaken: j['name_taken'] == true,
        category: j.strOrNull('category'),
        categoryExists: j['category_exists'] != false,
        sizes: [
          for (final s in _list(j['sizes']))
            (name: s.str('name'), price: s.integer('price')),
        ],
        lines: [for (final l in _list(j['lines'])) CopyLine.fromJson(l)],
        destIngredients: [
          for (final d in _list(j['dest_ingredients'])) DestIngredient.fromJson(d),
        ],
        toppingCount: _intOrNull(j['topping_count']) ?? 0,
        optionGroupCount: _intOrNull(j['option_group_count']) ?? 0,
      );

  final bool nameTaken;
  final String? category;
  final bool categoryExists;
  final List<({String name, int price})> sizes;
  final List<CopyLine> lines;
  final List<DestIngredient> destIngredients;
  final int toppingCount;
  final int optionGroupCount;

  int get matchedCount => lines.where((l) => l.matchId != null).length;
}

// ---------------------------------------------------------------------------
// Topping và tùy chọn pha chế
// ---------------------------------------------------------------------------

class ToppingInfo {
  const ToppingInfo({
    required this.id,
    required this.name,
    required this.price,
    required this.active,
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.qty,
    required this.unitCost,
    required this.cost,
    required this.costKnown,
    required this.selected,
    required this.usedBy,
  });

  factory ToppingInfo.fromJson(Map<String, dynamic> j) => ToppingInfo(
        id: j.str('id'),
        name: j.str('name'),
        price: j.integer('price'),
        active: j.flag('active'),
        ingredientId: j.strOrNull('ingredient_id'),
        ingredientName: j.strOrNull('ingredient_name'),
        unit: j.strOrNull('unit'),
        qty: _intOrNull(j['qty']),
        unitCost: _num(j['unit_cost']),
        cost: _intOrNull(j['cost']),
        costKnown: j['cost_known'] != false,
        selected: j['selected'] == true,
        usedBy: _intOrNull(j['used_by']) ?? 0,
      );

  final String id;
  final String name;
  final int price;
  final bool active;
  final String? ingredientId;
  final String? ingredientName;
  final String? unit;
  final int? qty;
  final num? unitCost;
  final int? cost;
  final bool costKnown;
  final bool selected;
  final int usedBy;

  bool get hasRecipe => ingredientId != null;
}

class OptionChoice {
  const OptionChoice({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.priceDelta,
    required this.ingredientId,
    required this.ingredientName,
    required this.unit,
    required this.qty,
    required this.unitCost,
  });

  factory OptionChoice.fromJson(Map<String, dynamic> j) => OptionChoice(
        id: j.str('id'),
        name: j.str('name'),
        isDefault: j.flag('is_default'),
        priceDelta: _intOrNull(j['price_delta']) ?? 0,
        ingredientId: j.strOrNull('ingredient_id'),
        ingredientName: j.strOrNull('ingredient_name'),
        unit: j.strOrNull('unit'),
        qty: _intOrNull(j['qty']),
        unitCost: _num(j['unit_cost']),
      );

  final String id;
  final String name;
  final bool isDefault;
  final int priceDelta;
  final String? ingredientId;
  final String? ingredientName;
  final String? unit;
  final int? qty;
  final num? unitCost;
}

class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.required,
    required this.choices,
  });

  factory OptionGroup.fromJson(Map<String, dynamic> j) => OptionGroup(
        id: j.str('id'),
        name: j.str('name'),
        required: j['required'] != false,
        choices: [for (final c in _list(j['choices'])) OptionChoice.fromJson(c)],
      );

  final String id;
  final String name;
  final bool required;
  final List<OptionChoice> choices;

  OptionChoice? get defaultChoice {
    for (final c in choices) {
      if (c.isDefault) return c;
    }
    return null;
  }
}

class ItemExtras {
  const ItemExtras({
    required this.itemId,
    required this.maxKinds,
    required this.maxPortions,
    required this.toppings,
    required this.groups,
  });

  factory ItemExtras.fromJson(Map<String, dynamic> j) => ItemExtras(
        itemId: j.str('item_id'),
        maxKinds: _intOrNull(j['topping_max_kinds']) ?? 2,
        maxPortions: _intOrNull(j['topping_max_portions']) ?? 1,
        toppings: [for (final t in _list(j['toppings'])) ToppingInfo.fromJson(t)],
        groups: [for (final g in _list(j['groups'])) OptionGroup.fromJson(g)],
      );

  final String itemId;
  final int maxKinds;
  final int maxPortions;
  final List<ToppingInfo> toppings;
  final List<OptionGroup> groups;

  List<ToppingInfo> get selectedToppings =>
      [for (final t in toppings) if (t.selected && t.active) t];
}

/// Lựa chọn tùy chọn đang soạn (chưa lưu).
class DraftOptionChoice {
  DraftOptionChoice({
    this.id,
    required this.name,
    this.isDefault = false,
    this.ingredientId,
    this.ingredientName,
    this.unit,
    this.qty,
  });

  factory DraftOptionChoice.from(OptionChoice c) => DraftOptionChoice(
        id: c.id,
        name: c.name,
        isDefault: c.isDefault,
        ingredientId: c.ingredientId,
        ingredientName: c.ingredientName,
        unit: c.unit,
        qty: c.qty,
      );

  String? id;
  String name;
  bool isDefault;
  String? ingredientId;
  String? ingredientName;
  String? unit;
  int? qty;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name.trim(),
        'is_default': isDefault,
        'ingredient_id': ingredientId,
        'qty': ingredientId == null ? null : qty,
      };
}

class DraftOptionGroup {
  DraftOptionGroup({
    this.id,
    required this.name,
    this.required = true,
    List<DraftOptionChoice>? choices,
  }) : choices = choices ?? [];

  factory DraftOptionGroup.from(OptionGroup g) => DraftOptionGroup(
        id: g.id,
        name: g.name,
        required: g.required,
        choices: [for (final c in g.choices) DraftOptionChoice.from(c)],
      );

  String? id;
  String name;
  bool required;
  final List<DraftOptionChoice> choices;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name.trim(),
        'required': required,
        'choices': [for (final c in choices) c.toJson()],
      };
}

/// Dòng công thức đang soạn trong màn chỉnh sửa.
class DraftRecipeLine {
  const DraftRecipeLine({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.qty,
    required this.unitCost,
  });

  final String ingredientId;
  final String name;
  final String unit;
  final int qty;
  final num? unitCost;

  int? get lineCost => unitCost == null ? null : (qty * unitCost!).round();

  DraftRecipeLine withQty(int value) => DraftRecipeLine(
        ingredientId: ingredientId,
        name: name,
        unit: unit,
        qty: value,
        unitCost: unitCost,
      );

  Map<String, dynamic> toJson() => {'ingredient_id': ingredientId, 'qty': qty};
}

/// Giá vốn của một danh sách dòng; `null` nếu có nguyên liệu chưa có giá.
int? draftCost(List<DraftRecipeLine> lines) {
  var total = 0.0;
  for (final l in lines) {
    if (l.unitCost == null) return null;
    total += l.qty * l.unitCost!;
  }
  return total.round();
}
