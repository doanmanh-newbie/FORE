part of 'kho_models.dart';

// ---------- Nhà cung cấp ----------
class SupplierSummary {
  const SupplierSummary({
    required this.id,
    required this.name,
    required this.active,
    required this.leadDays,
    required this.items,
    this.contactName,
    this.phone,
    this.lastOrderAt,
  });

  factory SupplierSummary.fromJson(Map<String, dynamic> j) => SupplierSummary(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        contactName: _strOrNull(j, 'contact_name'),
        phone: _strOrNull(j, 'phone'),
        active: j['active'] != false,
        leadDays: _int(j, 'lead_days', 1),
        items: [
          for (final e in (j['items'] as List? ?? const [])) '$e',
        ],
        lastOrderAt: _time(j, 'last_order_at'),
      );

  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final bool active;
  final int leadDays;
  final List<String> items;
  final DateTime? lastOrderAt;
}

class SupplierItem {
  const SupplierItem(
      {required this.id,
      required this.name,
      required this.unit,
      this.lastPrice,
      this.lastAt});

  factory SupplierItem.fromJson(Map<String, dynamic> j) => SupplierItem(
        id: _str(j, 'ingredient_id'),
        name: _str(j, 'name'),
        unit: _str(j, 'unit'),
        lastPrice: _dbl(j, 'last_price'),
        lastAt: _time(j, 'last_at'),
      );

  final String id;
  final String name;
  final String unit;
  final double? lastPrice;
  final DateTime? lastAt;
}

class SupplierDetail {
  const SupplierDetail({
    required this.id,
    required this.name,
    required this.active,
    required this.leadDays,
    required this.items,
    required this.orders,
    required this.draftCount,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.deliveryWindow,
    this.orderCutoff,
    this.note,
  });

  factory SupplierDetail.fromJson(Map<String, dynamic> j) => SupplierDetail(
        id: _str(j, 'id'),
        name: _str(j, 'name'),
        contactName: _strOrNull(j, 'contact_name'),
        phone: _strOrNull(j, 'phone'),
        email: _strOrNull(j, 'email'),
        address: _strOrNull(j, 'address'),
        leadDays: _int(j, 'lead_days', 1),
        deliveryWindow: _strOrNull(j, 'delivery_window'),
        orderCutoff: _strOrNull(j, 'order_cutoff'),
        note: _strOrNull(j, 'note'),
        active: j['active'] != false,
        items: _list(j, 'items').map(SupplierItem.fromJson).toList(),
        orders: _list(j, 'orders').map(PoSummary.fromJson).toList(),
        draftCount: _int(j, 'draft_count'),
      );

  final String id;
  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final int leadDays;
  final String? deliveryWindow;
  final String? orderCutoff;
  final String? note;
  final bool active;
  final List<SupplierItem> items;
  final List<PoSummary> orders;
  final int draftCount;
}

class SupplierDraft {
  const SupplierDraft({
    required this.name,
    this.contactName,
    this.phone,
    this.email,
    this.address,
    this.leadDays = 1,
    this.deliveryWindow,
    this.orderCutoff,
    this.note,
  });

  final String name;
  final String? contactName;
  final String? phone;
  final String? email;
  final String? address;
  final int leadDays;
  final String? deliveryWindow;
  final String? orderCutoff;
  final String? note;

  Map<String, dynamic> toJson() => {
        'name': name,
        'contact_name': contactName,
        'phone': phone,
        'email': email,
        'address': address,
        'lead_days': leadDays,
        'delivery_window': deliveryWindow,
        'order_cutoff': orderCutoff,
        'note': note,
      };
}

class SupplierOption {
  const SupplierOption({required this.id, required this.name});

  factory SupplierOption.fromJson(Map<String, dynamic> j) =>
      SupplierOption(id: _str(j, 'id'), name: _str(j, 'name'));

  final String id;
  final String name;
}

