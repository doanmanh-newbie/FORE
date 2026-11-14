part of 'kho_models.dart';

// ---------- Hao hụt ----------
class WasteRecord {
  const WasteRecord({required this.id, required this.code, required this.at});

  factory WasteRecord.fromJson(Map<String, dynamic> j) => WasteRecord(
      id: _str(j, 'id'),
      code: _str(j, 'code'),
      at: _time(j, 'at') ?? DateTime.now());

  final String id;
  final String code;
  final DateTime at;
}

class WasteReason {
  const WasteReason(
      {required this.code,
      required this.label,
      required this.value,
      required this.prevValue,
      required this.count});

  factory WasteReason.fromJson(Map<String, dynamic> j) => WasteReason(
        code: _str(j, 'code'),
        label: _str(j, 'label'),
        value: _int(j, 'value'),
        prevValue: _int(j, 'prev_value'),
        count: _int(j, 'count'),
      );

  final String code;
  final String label;
  final int value;
  final int prevValue;
  final int count;
}

class WasteIngredient {
  const WasteIngredient(
      {required this.id,
      required this.name,
      required this.unit,
      required this.qty,
      required this.value});

  factory WasteIngredient.fromJson(Map<String, dynamic> j) => WasteIngredient(
        id: _str(j, 'ingredient_id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        qty: _int(j, 'qty'),
        value: _int(j, 'value'),
      );

  final String id;
  final String name;
  final String unit;
  final int qty;
  final int value;
}

class WasteDay {
  const WasteDay({required this.date, required this.value});

  factory WasteDay.fromJson(Map<String, dynamic> j) => WasteDay(
      date: DateTime.tryParse(_str(j, 'date')) ?? DateTime.now(),
      value: _int(j, 'value'));

  final DateTime date;
  final int value;
}

class WasteOverview {
  const WasteOverview({
    required this.from,
    required this.to,
    required this.totalValue,
    required this.prevValue,
    required this.entryCount,
    required this.unpricedCount,
    required this.byReason,
    required this.byIngredient,
    required this.daily,
  });

  factory WasteOverview.fromJson(Map<String, dynamic> j) => WasteOverview(
        from: DateTime.tryParse(_str(j, 'from')) ?? DateTime.now(),
        to: DateTime.tryParse(_str(j, 'to')) ?? DateTime.now(),
        totalValue: _int(j, 'total_value'),
        prevValue: _int(j, 'prev_value'),
        entryCount: _int(j, 'entry_count'),
        unpricedCount: _int(j, 'unpriced_count'),
        byReason: _list(j, 'by_reason').map(WasteReason.fromJson).toList(),
        byIngredient:
            _list(j, 'by_ingredient').map(WasteIngredient.fromJson).toList(),
        daily: _list(j, 'daily').map(WasteDay.fromJson).toList(),
      );

  final DateTime from;
  final DateTime to;
  final int totalValue;
  final int prevValue;
  final int entryCount;
  final int unpricedCount;
  final List<WasteReason> byReason;
  final List<WasteIngredient> byIngredient;
  final List<WasteDay> daily;

  /// Lý do tăng bất thường: kỳ này ≥ 1,5 lần kỳ trước và có tăng thật.
  WasteReason? get spike {
    for (final r in byReason) {
      if (r.value > 0 && r.prevValue > 0 && r.value >= r.prevValue * 1.5) {
        return r;
      }
    }
    return null;
  }
}

class InventoryRequest {
  const InventoryRequest({
    required this.id,
    required this.kind,
    required this.note,
    required this.staffName,
    this.refCode,
    this.createdAt,
  });

  factory InventoryRequest.fromJson(Map<String, dynamic> j) => InventoryRequest(
        id: _str(j, 'id'),
        kind: _str(j, 'kind'),
        note: _str(j, 'note'),
        staffName: _str(j, 'staff_name'),
        refCode: _strOrNull(j, 'ref_code'),
        createdAt: _time(j, 'created_at'),
      );

  final String id;
  final String kind;
  final String note;
  final String staffName;
  final String? refCode;
  final DateTime? createdAt;
}

