import 'package:fore/features/inventory/domain/kho_models.dart';
import 'package:fore/features/inventory/domain/kho_repository.dart';

/// Kho giả cho test màn hình khác: tổng quan rỗng (không việc gấp), mọi thứ còn lại trả rỗng.
class FakeKhoRepository implements KhoRepository {
  @override
  Future<InvOverview> overview() async => InvOverview.fromJson({
        'updated_at': '2026-11-08T09:41:00Z',
        'stock_value': 0,
        'ingredient_count': 0,
      });

  @override
  Future<List<SupplierSummary>> suppliers() async => const [];

  @override
  Future<List<CatalogItem>> catalog(
          {String? group, String? search, bool includeInactive = false}) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
