import '../../../../core/data/json_row.dart';

/// Hồ sơ quán: tên hiển thị ở đầu trang và nhãn đơn vị bán ("phần", "ly", "tô"...).
class ShopInfo {
  const ShopInfo(
      {required this.name, required this.type, required this.servingLabel});

  factory ShopInfo.fromRow(Map<String, dynamic> row) => ShopInfo(
        name: row.str('shop_name'),
        type: row.str('shop_type'),
        servingLabel: row.str('serving_label'),
      );

  final String name;
  final String type;
  final String servingLabel;
}

/// Ca đang mở của cả quán. Cố ý KHÔNG có tiền đầu ca: đếm mù tiền mặt.
class OpsCurrentShift {
  const OpsCurrentShift({
    required this.id,
    required this.openedAt,
    required this.openedByName,
    required this.openedByMe,
  });

  factory OpsCurrentShift.fromRow(Map<String, dynamic> row) => OpsCurrentShift(
        id: row.str(row.containsKey('id') ? 'id' : 'shift_id'),
        openedAt: row.time('opened_at'),
        openedByName: row.str('opened_by_name'),
        openedByMe: row.flag('opened_by_me'),
      );

  final String id;
  final DateTime openedAt;
  final String openedByName;
  final bool openedByMe;
}

/// Việc còn thiếu trước khi đóng ca. Chỉ là SỐ LƯỢNG, không lộ số liệu kho.
class CloseStatus {
  const CloseStatus({required this.openBills, required this.missingCounts});

  factory CloseStatus.fromRow(Map<String, dynamic> row) => CloseStatus(
        openBills: row.integer('open_bills'),
        missingCounts: row.integer('missing_counts'),
      );

  final int openBills;
  final int missingCounts;

  bool get ready => openBills == 0 && missingCounts == 0;
}
