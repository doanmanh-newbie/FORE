import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/inventory/data/rpc_kho_repository.dart';
import 'package:fore/features/inventory/domain/kho_models.dart';

import '../../support/fakes.dart';

/// Hợp đồng giữa app và database/07_inventory.sql: tên hàm và tên tham số app gửi lên phải khớp
/// chữ ký hàm trong file SQL (tham số bắt buộc không được thiếu, không gửi tham số lạ).
Map<String, ({Set<String> all, Set<String> required})> _signatures() {
  final sql = File('database/07_inventory.sql').readAsStringSync();
  final out = <String, ({Set<String> all, Set<String> required})>{};
  final re = RegExp(r'create or replace function (\w+)\(([^)]*)\)', multiLine: true);
  for (final m in re.allMatches(sql)) {
    final name = m.group(1)!;
    if (name.startsWith('_')) continue;
    final all = <String>{};
    final required = <String>{};
    for (final raw in m.group(2)!.split(',')) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      final pname = part.split(RegExp(r'\s+')).first;
      all.add(pname);
      if (!part.toLowerCase().contains(' default ')) required.add(pname);
    }
    out[name] = (all: all, required: required);
  }
  return out;
}

void main() {
  test('mọi lời gọi RPC của Kho khớp chữ ký hàm trong 07_inventory.sql', () async {
    final sigs = _signatures();
    expect(sigs.length, greaterThan(30), reason: 'không đọc được chữ ký hàm');

    final rpc = FakeRpcClient({
      for (final fn in sigs.keys) fn: null,
      'inv_overview': <String, dynamic>{},
      'inv_catalog': [],
      'inv_ingredient_profile': <String, dynamic>{},
      'inv_ingredient_history': <String, dynamic>{},
      'inv_groups': [],
      'sup_list': [],
      'sup_detail': <String, dynamic>{},
      'po_list': [],
      'po_impact': <String, dynamic>{},
      'po_suggestions': <String, dynamic>{},
      'st_list': [],
      'st_detail': <String, dynamic>{},
      'inv_waste_overview': {'from': '2026-11-01', 'to': '2026-11-07'},
      'inv_week_review': {'from': '2026-11-01', 'to': '2026-11-07'},
      'inv_shops_snapshot': [],
      'inv_requests': [],
      'inv_ingredient_save': 'id',
      'inv_group_save': 'id',
      'sup_save': 'id',
      'po_set_prices': <String, dynamic>{},
      'po_from_suggestions': [],
      'st_approve': <String, dynamic>{},
      'inv_picker': [],
      'sup_options': [],
      'po_detail': <String, dynamic>{},
      'po_save': <String, dynamic>{},
      'inv_staff_home': <String, dynamic>{},
      'st_start': {'id': 'k', 'code': 'KK-1', 'resumed': false},
      'st_sheet': <String, dynamic>{},
      'inv_lots_for_staff': [],
      'waste_type_list': [],
      'inv_waste_add': <String, dynamic>{},
    });
    final repo = RpcKhoRepository(rpc);
    final day = DateTime(2026, 11, 7);

    await repo.overview();
    await repo.catalog(group: 'Sữa', search: 'sữa', includeInactive: true);
    await repo.ingredientProfile('i');
    await repo.ingredientHistory('i', kind: 'purchase');
    await repo.groups();
    await repo.suppliers();
    await repo.supplierDetail('s');
    await repo.orders(status: 'draft');
    await repo.orderImpact('p');
    await repo.suggestions();
    await repo.stocktakes(status: 'submitted');
    await repo.stocktakeDetail('k');
    await repo.wasteOverview(day, day);
    await repo.weekReview(day, day);
    await repo.shopSnapshots();
    await repo.requests();
    await repo.saveIngredient(null, const IngredientDraft(name: 'Sữa', unit: 'ml'));
    await repo.setIngredientActive('i', false);
    await repo.saveGroup(null, 'Sữa');
    await repo.setGroupActive('g', false);
    await repo.saveSupplier(null, const SupplierDraft(name: 'Vinamilk'));
    await repo.setSupplierActive('s', false);
    await repo.setOrderPrices('p', {'l': 20});
    await repo.draftsFromSuggestions([(ingredientId: 'i', qty: 1000, supplierId: null)]);
    await repo.requestRecount('k', ['i'], 'đếm lại giúp');
    await repo.approveStocktake('k', adjustByIngredient: {'i': true}, reason: 'Hao hụt chưa ghi');
    await repo.resolveRequest('r');
    await repo.picker();
    await repo.supplierOptions();
    await repo.myOrders();
    await repo.orderDetail('p');
    await repo.saveOrder(null, const PoDraft(lines: []), confirm: false, withPrice: false);
    await repo.cancelOrder('p', reason: 'nhầm');
    await repo.staffHome();
    await repo.startStocktake();
    await repo.countSheet('k');
    await repo.saveCounts('k', {'i': 1});
    await repo.submitStocktake('k');
    await repo.lotsFor('i');
    await repo.wasteTypes();
    await repo.addWaste(ingredientId: 'i', qty: 1, typeCode: 'spill');
    await repo.requestCorrection(kind: 'waste', refId: 'w', note: 'ghi nhầm');

    expect(rpc.calls, isNotEmpty);
    for (final c in rpc.calls) {
      if (c.fn == 'waste_type_list') continue; // hàm có sẵn từ module 03
      final sig = sigs[c.fn];
      expect(sig, isNotNull, reason: 'database chưa có hàm ${c.fn}');
      final sent = (c.params ?? const <String, dynamic>{}).keys.toSet();
      expect(sent.difference(sig!.all), isEmpty,
          reason: '${c.fn}: gửi tham số database không có');
      expect(sig.required.difference(sent), isEmpty,
          reason: '${c.fn}: thiếu tham số bắt buộc');
    }

    // Mọi hàm app-facing của module 07 đều được app dùng (trừ hàm trợ giúp nội bộ).
    final used = rpc.calls.map((c) => c.fn).toSet();
    final unused = sigs.keys.where((f) => !used.contains(f) && f != 'inv_seed_trg' && f != 'inv_lock_confirmed');
    expect(unused, isEmpty, reason: 'Hàm database chưa có chỗ dùng trong app: $unused');
  });

  test('nhân viên gửi phiếu không kèm giá', () async {
    final rpc = FakeRpcClient({'po_save': <String, dynamic>{}});
    final repo = RpcKhoRepository(rpc);
    await repo.saveOrder(
      null,
      const PoDraft(lines: [
        PoLine(ingredientId: 'i', name: 'Sữa', unit: 'ml', qty: 1000, unitPrice: 50),
      ]),
      confirm: true,
      withPrice: false,
    );
    final p = rpc.calls.single.params!['p'] as Map<String, dynamic>;
    final line = (p['lines'] as List).single as Map<String, dynamic>;
    expect(line.containsKey('unit_price'), isFalse);
    expect(rpc.calls.single.params!['p_confirm'], isTrue);
  });
}
