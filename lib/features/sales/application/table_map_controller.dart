import 'dart:async';

import '../../../core/application/action_notifier.dart';
import '../../../core/application/load_phase.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/text.dart';
import '../domain/sales_models.dart';
import '../domain/sales_repository.dart';

/// Bản đồ bàn: danh sách khu, bàn của khu đang chọn, tìm bàn, mở bàn.
/// Hai máy cùng dùng một ca nên tự làm mới theo chu kỳ (mặc định tắt; màn hình bật khi hiển thị).
class TableMapController extends ActionNotifier {
  TableMapController(this._repo);

  final SalesRepository _repo;

  LoadPhase phase = LoadPhase.loading;
  List<TableSlot> slots = const [];
  AppFailure? failure;

  String? _selectedAreaId;
  String _query = '';
  Timer? _timer;

  String get query => _query;

  List<AreaGroup> get areas {
    final order = <String>[];
    final names = <String, String>{};
    final tables = <String, List<TableSlot>>{};
    for (final s in slots) {
      if (!tables.containsKey(s.areaId)) {
        order.add(s.areaId);
        names[s.areaId] = s.areaName;
        tables[s.areaId] = [];
      }
      tables[s.areaId]!.add(s);
    }
    return [
      for (final id in order)
        AreaGroup(id: id, name: names[id]!, tables: tables[id]!),
    ];
  }

  /// Khu đang chọn; nếu khu đã chọn biến mất (bị ẩn) thì quay về khu đầu tiên.
  AreaGroup? get selectedArea {
    final all = areas;
    if (all.isEmpty) return null;
    return all.firstWhere((a) => a.id == _selectedAreaId,
        orElse: () => all.first);
  }

  bool get isSearching => _query.trim().isNotEmpty;

  /// Đang tìm thì tìm trên TẤT CẢ các khu; không thì chỉ bàn của khu đang chọn.
  List<TableSlot> get visibleTables {
    if (isSearching) {
      final q = foldVietnamese(_query.trim());
      return [
        for (final s in slots)
          if (foldVietnamese(s.tableName).contains(q)) s
      ];
    }
    return selectedArea?.tables ?? const [];
  }

  void selectArea(String areaId) {
    _selectedAreaId = areaId;
    notify();
  }

  void setQuery(String value) {
    _query = value;
    notify();
  }

  Future<void> load() async {
    if (slots.isEmpty) {
      phase = LoadPhase.loading;
      notify();
    }
    try {
      slots = await _repo.tableMap();
      failure = null;
      phase = LoadPhase.ready;
    } on AppFailure catch (f) {
      failure = f;
      phase = slots.isEmpty ? LoadPhase.error : LoadPhase.ready;
    }
    notify();
  }

  @override
  Future<void> onStale() => load();

  void startAutoRefresh(Duration every) {
    _timer?.cancel();
    _timer = Timer.periodic(every, (_) {
      if (!busy) load();
    });
  }

  void stopAutoRefresh() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }

  /// Mở bill cho một bàn trống. Trả mã bill; `null` nếu đang bận.
  /// Bàn vừa có bill từ máy khác: ném `TABLE_HAS_OPEN_BILL` sau khi đã tải lại.
  Future<String?> openTable(TableSlot slot, {int? guests}) =>
      runAction<String>(() async {
        final id = await _repo.openBill(
          tableId: slot.tableId,
          type: BillType.dineIn,
          guests: guests,
        );
        await load();
        return id;
      });
}
