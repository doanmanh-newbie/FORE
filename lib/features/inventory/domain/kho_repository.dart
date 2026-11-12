import 'inventory_models.dart' show WasteTypeOption;
import 'kho_models.dart';

/// Hợp đồng dữ liệu của module Kho v2. Màn hình và controller chỉ biết interface này;
/// bản thật gọi RPC Supabase, bản giả dùng trong test.
abstract interface class KhoRepository {
  // ----- Chủ: đọc -----
  Future<InvOverview> overview();
  Future<List<CatalogItem>> catalog(
      {String? group, String? search, bool includeInactive = false});
  Future<IngredientProfile> ingredientProfile(String id);
  Future<IngredientHistory> ingredientHistory(String id, {String? kind});
  Future<List<IngredientGroup>> groups();
  Future<List<SupplierSummary>> suppliers();
  Future<SupplierDetail> supplierDetail(String id);
  Future<List<PoSummary>> orders({String? status});
  Future<PoImpact> orderImpact(String id);
  Future<Suggestions> suggestions();
  Future<List<StocktakeSummary>> stocktakes({String? status});
  Future<StocktakeDetail> stocktakeDetail(String id);
  Future<WasteOverview> wasteOverview(DateTime from, DateTime to);
  Future<WeekReview> weekReview(DateTime from, DateTime to);
  Future<List<ShopSnapshot>> shopSnapshots();
  Future<List<InventoryRequest>> requests();

  // ----- Chủ: ghi -----
  Future<String> saveIngredient(String? id, IngredientDraft draft);
  Future<void> setIngredientActive(String id, bool active);
  Future<String> saveGroup(String? id, String name);
  Future<void> setGroupActive(String id, bool active);
  Future<String> saveSupplier(String? id, SupplierDraft draft);
  Future<void> setSupplierActive(String id, bool active);
  Future<PoDetail> setOrderPrices(String id, Map<String, double> priceByLineId);
  Future<List<PoSummary>> draftsFromSuggestions(
      List<({String ingredientId, int qty, String? supplierId})> items);
  Future<void> requestRecount(
      String stocktakeId, List<String> ingredientIds, String? note);
  Future<StocktakeResult> approveStocktake(
    String id, {
    required Map<String, bool> adjustByIngredient,
    required String reason,
    String? note,
  });
  Future<void> resolveRequest(String id);

  // ----- Chủ và nhân viên -----
  Future<List<PickerItem>> picker();
  Future<List<SupplierOption>> supplierOptions();
  Future<List<PoSummary>> myOrders({String? status});
  Future<PoDetail> orderDetail(String id);

  /// Lưu phiếu. `confirm = true` thì ghi hàng vào kho. Nhân viên không gửi giá.
  Future<PoDetail> saveOrder(String? id, PoDraft draft,
      {required bool confirm, required bool withPrice});
  Future<void> cancelOrder(String id, {String? reason});

  // ----- Nhân viên -----
  Future<StaffInventoryHomeData> staffHome();
  Future<({String id, String code, bool resumed})> startStocktake();
  Future<CountSheet> countSheet(String id);
  Future<void> saveCounts(String id, Map<String, int?> qtyByIngredient);
  Future<void> submitStocktake(String id);
  Future<List<LotOption>> lotsFor(String ingredientId);
  Future<List<WasteTypeOption>> wasteTypes();
  Future<WasteRecord> addWaste({
    required String ingredientId,
    required int qty,
    required String typeCode,
    String? note,
    String? lotId,
  });
  Future<void> requestCorrection(
      {required String kind, required String refId, required String note});
}
