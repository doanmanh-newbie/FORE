part of 'kho_models.dart';

// ---------- Gợi ý nhập ----------
class SuggestionItem {
  const SuggestionItem({
    required this.ingredientId,
    required this.name,
    required this.unit,
    required this.stock,
    required this.suggestedQty,
    required this.leadDays,
    this.perDay,
    this.daysLeft,
    this.supplierId,
    this.supplierName,
    this.orderCutoff,
    this.lastPrice,
  });

  factory SuggestionItem.fromJson(Map<String, dynamic> j) => SuggestionItem(
        ingredientId: _str(j, 'ingredient_id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        stock: _int(j, 'stock'),
        perDay: _dbl(j, 'per_day'),
        daysLeft: _dbl(j, 'days_left'),
        suggestedQty: _int(j, 'suggested_qty'),
        supplierId: _strOrNull(j, 'supplier_id'),
        supplierName: _strOrNull(j, 'supplier_name'),
        leadDays: _int(j, 'lead_days', 1),
        orderCutoff: _strOrNull(j, 'order_cutoff'),
        lastPrice: _dbl(j, 'last_price'),
      );

  final String ingredientId;
  final String name;
  final String unit;
  final int stock;
  final double? perDay;
  final double? daysLeft;
  final int suggestedQty;
  final String? supplierId;
  final String? supplierName;
  final int leadDays;
  final String? orderCutoff;
  final double? lastPrice;
}

class Suggestions {
  const Suggestions(
      {required this.generatedAt,
      required this.windowDays,
      required this.items,
      required this.draftCodes});

  factory Suggestions.fromJson(Map<String, dynamic> j) => Suggestions(
        generatedAt: _time(j, 'generated_at') ?? DateTime.now(),
        windowDays: _int(j, 'window_days', 7),
        items: _list(j, 'items').map(SuggestionItem.fromJson).toList(),
        draftCodes: [for (final e in (j['draft_codes'] as List? ?? const [])) '$e'],
      );

  final DateTime generatedAt;
  final int windowDays;
  final List<SuggestionItem> items;
  final List<String> draftCodes;
}

