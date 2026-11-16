/// Ca đang mở của quán. Cả quán chỉ có tối đa một ca mở tại một thời điểm.
class CurrentShift {
  const CurrentShift({
    required this.id,
    required this.openedByName,
    required this.openedAt,
    this.openedByMe = false,
    this.openBills = 0,
  });

  /// Đọc từ một dòng của hàm database `current_shift()`.
  factory CurrentShift.fromMap(Map<String, dynamic> map) => CurrentShift(
        id: map['shift_id'] as String,
        openedByName: map['opened_by_name'] as String,
        openedAt: DateTime.parse(map['opened_at'] as String),
        openedByMe: map['opened_by_me'] as bool? ?? false,
        openBills: (map['open_bills'] as num?)?.toInt() ?? 0,
      );

  final String id;
  final String openedByName;

  /// Giờ máy chủ lúc mở ca.
  final DateTime openedAt;

  /// Người đang dùng app chính là người mở ca.
  final bool openedByMe;

  /// Số bill đang mở trong ca. Phải xử lý hết thì mới đóng ca được.
  final int openBills;
}
