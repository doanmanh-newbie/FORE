/// Một quán mà tôi là thành viên (kết quả `my_shops()`).
class ShopMembership {
  const ShopMembership({
    required this.shopId,
    required this.shopName,
    required this.staffId,
    required this.isOwner,
    required this.displayName,
    required this.isCurrent,
  });

  factory ShopMembership.fromMap(Map<String, dynamic> m) => ShopMembership(
        shopId: m['shop_id'] as String,
        shopName: m['shop_name'] as String,
        staffId: m['staff_id'] as String,
        isOwner: m['role'] == 'owner',
        displayName: m['display_name'] as String,
        isCurrent: m['is_current'] as bool,
      );

  final String shopId;
  final String shopName;
  final String staffId;
  final bool isOwner;
  final String displayName;
  final bool isCurrent;
}

/// Lời mời vào quán trong hộp thư của tôi (kết quả `my_invites()`).
class Invite {
  const Invite({
    required this.id,
    required this.shopId,
    required this.shopName,
    required this.invitedName,
    required this.invitedByName,
    required this.createdAt,
  });

  factory Invite.fromMap(Map<String, dynamic> m) => Invite(
        id: m['invite_id'] as String,
        shopId: m['shop_id'] as String,
        shopName: m['shop_name'] as String,
        invitedName: m['invited_name'] as String,
        invitedByName: m['invited_by_name'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );

  final String id;
  final String shopId;
  final String shopName;

  /// Tên hiển thị chủ đặt cho mình trong quán.
  final String invitedName;
  final String invitedByName;
  final DateTime createdAt;
}

/// Thành viên của quán (chủ xem, kết quả `shop_team()`).
class TeamMember {
  const TeamMember({
    required this.staffId,
    required this.fullName,
    required this.isOwner,
    required this.active,
    required this.phone,
    required this.email,
  });

  factory TeamMember.fromMap(Map<String, dynamic> m) => TeamMember(
        staffId: m['staff_id'] as String,
        fullName: m['full_name'] as String,
        isOwner: m['role'] == 'owner',
        active: m['active'] as bool,
        phone: (m['phone'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
      );

  final String staffId;
  final String fullName;
  final bool isOwner;
  final bool active;
  final String phone;
  final String email;
}

/// Lời mời chủ đã gửi, kèm trạng thái phản hồi trong lịch sử đội ngũ.
class PendingInvite {
  const PendingInvite({
    required this.id,
    this.phone,
    this.email,
    required this.fullName,
    required this.createdAt,
    this.status = 'pending',
    this.respondedAt,
  });

  factory PendingInvite.fromMap(Map<String, dynamic> m) => PendingInvite(
        id: m['id'] as String,
        phone: m['phone'] as String?,
        email: m['email'] as String?,
        fullName: m['full_name'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        status: m['status'] as String? ?? 'pending',
        respondedAt: m['responded_at'] == null
            ? null
            : DateTime.parse(m['responded_at'] as String).toLocal(),
      );

  final String id;

  /// Dạng chỉ chữ số, có mã quốc gia (ví dụ `84901234567`).
  final String? phone;
  final String? email;
  final String fullName;
  final DateTime createdAt;
  final String status;
  final DateTime? respondedAt;

  String get statusLabel => switch (status) {
        'accepted' => 'Đã tham gia',
        'declined' => 'Đã từ chối',
        'cancelled' => 'Đã hủy',
        'expired' => 'Đã hết hạn',
        _ => 'Đang chờ',
      };
}
