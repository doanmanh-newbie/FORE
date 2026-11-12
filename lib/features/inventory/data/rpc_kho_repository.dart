import '../../../core/data/rpc_client.dart';
import '../../../core/errors/app_failure.dart';
import '../domain/inventory_models.dart' show WasteTypeOption;
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';

/// Gọi các hàm của database/07_inventory.sql. Lỗi dữ liệu sai dạng được đổi thành [UnknownFailure].
class RpcKhoRepository implements KhoRepository {
  RpcKhoRepository(this._rpc);

  final RpcClient _rpc;

  Future<T> _parse<T>(Future<dynamic> call, T Function(dynamic raw) map) async {
    final raw = await call;
    try {
      return map(raw);
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }

  String? _clean(String? s) {
    final t = s?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  // ----- Chủ: đọc -----
  @override
  Future<InvOverview> overview() => _parse(
      _rpc.call('inv_overview'), (r) => InvOverview.fromJson(objectOf(r)));

  @override
  Future<List<CatalogItem>> catalog(
          {String? group, String? search, bool includeInactive = false}) =>
      _parse(
        _rpc.call('inv_catalog', {
          'p_group': _clean(group),
          'p_search': _clean(search),
          'p_include_inactive': includeInactive,
        }),
        (r) => rowsOf(r).map(CatalogItem.fromJson).toList(),
      );

  @override
  Future<IngredientProfile> ingredientProfile(String id) => _parse(
      _rpc.call('inv_ingredient_profile', {'p_id': id}),
      (r) => IngredientProfile.fromJson(objectOf(r)));

  @override
  Future<IngredientHistory> ingredientHistory(String id, {String? kind}) =>
      _parse(
          _rpc.call('inv_ingredient_history',
              {'p_id': id, 'p_kind': kind, 'p_limit': 60}),
          (r) => IngredientHistory.fromJson(objectOf(r)));

  @override
  Future<List<IngredientGroup>> groups() => _parse(_rpc.call('inv_groups'),
      (r) => rowsOf(r).map(IngredientGroup.fromJson).toList());

  @override
  Future<List<SupplierSummary>> suppliers() => _parse(_rpc.call('sup_list'),
      (r) => rowsOf(r).map(SupplierSummary.fromJson).toList());

  @override
  Future<SupplierDetail> supplierDetail(String id) => _parse(
      _rpc.call('sup_detail', {'p_id': id}),
      (r) => SupplierDetail.fromJson(objectOf(r)));

  @override
  Future<List<PoSummary>> orders({String? status}) => _parse(
      _rpc.call('po_list', {'p_status': status, 'p_limit': 50}),
      (r) => rowsOf(r).map(PoSummary.fromJson).toList());

  @override
  Future<PoImpact> orderImpact(String id) => _parse(
      _rpc.call('po_impact', {'p_id': id}), (r) => PoImpact.fromJson(objectOf(r)));

  @override
  Future<Suggestions> suggestions() => _parse(
      _rpc.call('po_suggestions'), (r) => Suggestions.fromJson(objectOf(r)));

  @override
  Future<List<StocktakeSummary>> stocktakes({String? status}) => _parse(
      _rpc.call('st_list', {'p_status': status}),
      (r) => rowsOf(r).map(StocktakeSummary.fromJson).toList());

  @override
  Future<StocktakeDetail> stocktakeDetail(String id) => _parse(
      _rpc.call('st_detail', {'p_id': id}),
      (r) => StocktakeDetail.fromJson(objectOf(r)));

  @override
  Future<WasteOverview> wasteOverview(DateTime from, DateTime to) => _parse(
      _rpc.call('inv_waste_overview',
          {'p_from': _day(from), 'p_to': _day(to)}),
      (r) => WasteOverview.fromJson(objectOf(r)));

  @override
  Future<WeekReview> weekReview(DateTime from, DateTime to) => _parse(
      _rpc.call(
          'inv_week_review', {'p_from': _day(from), 'p_to': _day(to)}),
      (r) => WeekReview.fromJson(objectOf(r)));

  @override
  Future<List<ShopSnapshot>> shopSnapshots() => _parse(
      _rpc.call('inv_shops_snapshot'),
      (r) => rowsOf(r).map(ShopSnapshot.fromJson).toList());

  @override
  Future<List<InventoryRequest>> requests() => _parse(
      _rpc.call('inv_requests'),
      (r) => rowsOf(r).map(InventoryRequest.fromJson).toList());

  // ----- Chủ: ghi -----
  @override
  Future<String> saveIngredient(String? id, IngredientDraft draft) async =>
      '${await _rpc.call('inv_ingredient_save', {
            'p_id': id,
            'p': draft.toJson(),
          })}';

  @override
  Future<void> setIngredientActive(String id, bool active) async {
    await _rpc.call(
        'inv_ingredient_set_active', {'p_id': id, 'p_active': active});
  }

  @override
  Future<String> saveGroup(String? id, String name) async =>
      '${await _rpc.call('inv_group_save', {'p_id': id, 'p_name': name})}';

  @override
  Future<void> setGroupActive(String id, bool active) async {
    await _rpc.call('inv_group_set_active', {'p_id': id, 'p_active': active});
  }

  @override
  Future<String> saveSupplier(String? id, SupplierDraft draft) async =>
      '${await _rpc.call('sup_save', {'p_id': id, 'p': draft.toJson()})}';

  @override
  Future<void> setSupplierActive(String id, bool active) async {
    await _rpc.call('sup_set_active', {'p_id': id, 'p_active': active});
  }

  @override
  Future<PoDetail> setOrderPrices(
          String id, Map<String, double> priceByLineId) =>
      _parse(
        _rpc.call('po_set_prices', {
          'p_id': id,
          'p_lines': [
            for (final e in priceByLineId.entries)
              {'line_id': e.key, 'unit_price': e.value}
          ],
        }),
        (r) => PoDetail.fromJson(objectOf(r)),
      );

  @override
  Future<List<PoSummary>> draftsFromSuggestions(
      List<({String ingredientId, int qty, String? supplierId})> items) async {
    final raw = await _rpc.call('po_from_suggestions', {
      'p_items': [
        for (final i in items)
          {
            'ingredient_id': i.ingredientId,
            'qty': i.qty,
            'supplier_id': i.supplierId,
          }
      ],
    });
    try {
      return [
        for (final r in rowsOf(raw))
          PoSummary(
            id: '${r['id']}',
            code: '${r['code']}',
            status: PoStatus.draft,
            lineCount: 0,
            needsPricing: false,
          ),
      ];
    } on FormatException catch (e) {
      throw UnknownFailure(e);
    }
  }

  @override
  Future<void> requestRecount(
      String stocktakeId, List<String> ingredientIds, String? note) async {
    await _rpc.call('st_request_recount', {
      'p_id': stocktakeId,
      'p_ingredients': ingredientIds,
      'p_note': _clean(note),
    });
  }

  @override
  Future<StocktakeResult> approveStocktake(
    String id, {
    required Map<String, bool> adjustByIngredient,
    required String reason,
    String? note,
  }) =>
      _parse(
        _rpc.call('st_approve', {
          'p_id': id,
          'p_decisions': [
            for (final e in adjustByIngredient.entries)
              {
                'ingredient_id': e.key,
                'decision': e.value ? 'adjust' : 'keep',
              }
          ],
          'p_reason': reason.trim(),
          'p_note': _clean(note),
        }),
        (r) => StocktakeResult.fromJson(objectOf(r)),
      );

  @override
  Future<void> resolveRequest(String id) async {
    await _rpc.call('inv_request_resolve', {'p_id': id});
  }

  // ----- Chủ và nhân viên -----
  @override
  Future<List<PickerItem>> picker() => _parse(_rpc.call('inv_picker'),
      (r) => rowsOf(r).map(PickerItem.fromJson).toList());

  @override
  Future<List<SupplierOption>> supplierOptions() => _parse(
      _rpc.call('sup_options'),
      (r) => rowsOf(r).map(SupplierOption.fromJson).toList());

  @override
  Future<List<PoSummary>> myOrders({String? status}) => orders(status: status);

  @override
  Future<PoDetail> orderDetail(String id) => _parse(
      _rpc.call('po_detail', {'p_id': id}),
      (r) => PoDetail.fromJson(objectOf(r)));

  @override
  Future<PoDetail> saveOrder(String? id, PoDraft draft,
          {required bool confirm, required bool withPrice}) =>
      _parse(
        _rpc.call('po_save', {
          'p_id': id,
          'p': draft.toJson(withPrice: withPrice),
          'p_confirm': confirm,
        }),
        (r) => PoDetail.fromJson(objectOf(r)),
      );

  @override
  Future<void> cancelOrder(String id, {String? reason}) async {
    await _rpc.call('po_cancel', {'p_id': id, 'p_reason': _clean(reason)});
  }

  // ----- Nhân viên -----
  @override
  Future<StaffInventoryHomeData> staffHome() => _parse(
      _rpc.call('inv_staff_home'),
      (r) => StaffInventoryHomeData.fromJson(objectOf(r)));

  @override
  Future<({String id, String code, bool resumed})> startStocktake() => _parse(
        _rpc.call('st_start'),
        (r) {
          final o = objectOf(r);
          return (
            id: '${o['id']}',
            code: '${o['code']}',
            resumed: o['resumed'] == true,
          );
        },
      );

  @override
  Future<CountSheet> countSheet(String id) => _parse(
      _rpc.call('st_sheet', {'p_id': id}),
      (r) => CountSheet.fromJson(objectOf(r)));

  @override
  Future<void> saveCounts(String id, Map<String, int?> qtyByIngredient) async {
    await _rpc.call('st_save', {
      'p_id': id,
      'p_lines': [
        for (final e in qtyByIngredient.entries)
          {'ingredient_id': e.key, 'counted_qty': e.value}
      ],
    });
  }

  @override
  Future<void> submitStocktake(String id) async {
    await _rpc.call('st_submit', {'p_id': id});
  }

  @override
  Future<List<LotOption>> lotsFor(String ingredientId) => _parse(
      _rpc.call('inv_lots_for_staff', {'p_ingredient': ingredientId}),
      (r) => rowsOf(r).map(LotOption.fromJson).toList());

  @override
  Future<List<WasteTypeOption>> wasteTypes() => _parse(
        _rpc.call('waste_type_list'),
        (r) => [
          for (final j in rowsOf(r))
            WasteTypeOption(
              code: '${j['code']}',
              label: '${j['label_vi']}',
              requiresNote: j['requires_note'] == true,
            ),
        ],
      );

  @override
  Future<WasteRecord> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
    String? lotId,
  }) =>
      _parse(
        _rpc.call('inv_waste_add', {
          'p_ingredient': ingredientId,
          'p_qty': qty,
          'p_type': typeCode,
          'p_note': _clean(note),
          'p_lot': lotId,
        }),
        (r) => WasteRecord.fromJson(objectOf(r)),
      );

  @override
  Future<void> requestCorrection(
      {required String kind,
      required String refId,
      required String note}) async {
    await _rpc.call('inv_request_correction',
        {'p_kind': kind, 'p_ref': refId, 'p_note': note.trim()});
  }
}
