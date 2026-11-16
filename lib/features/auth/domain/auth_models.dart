import '../../../core/phone.dart';

/// Tài khoản đăng nhập (Supabase Auth): id, email và/hoặc số điện thoại, tên hiển thị.
/// Chủ quán và nhân viên đều đăng nhập bằng mật khẩu (nhân viên dùng số điện thoại hoặc email).
class AuthUser {
  const AuthUser({
    required this.id,
    this.email = '',
    this.phone = '',
    this.displayName = '',
    this.birthDate = '',
    this.accountKind = AccountKind.unknown,
  });

  final String id;
  final String email;

  /// Dạng quốc tế không dấu "+" như Supabase lưu (ví dụ `84901234567`), hoặc rỗng.
  final String phone;

  /// Tên hiển thị người dùng tự nhập lúc đăng nhập lần đầu (rỗng nếu chưa có).
  final String displayName;
  final String birthDate;
  final AccountKind accountKind;

  /// Cái để hiện cho người dùng nhận ra tài khoản của mình. Tài khoản đăng ký bằng số điện thoại
  /// có email nội bộ `p<số>@phone.fore-staff.app`: hiện lại số (0901 234 567), không hiện email đó.
  String get contact {
    if (phone.isNotEmpty) return Phone.pretty('+$phone');
    final m = _phoneLoginEmail.firstMatch(email);
    return m == null ? email : Phone.pretty('+${m[1]}');
  }

  static final _phoneLoginEmail =
      RegExp(r'^p([0-9]{8,15})@phone\.fore-staff\.app$');
}

enum StaffRole {
  owner,
  staff;

  static StaffRole parse(String value) => switch (value) {
        'owner' => StaffRole.owner,
        'staff' => StaffRole.staff,
        _ => throw ArgumentError.value(value, 'role', 'ROLE_INVALID'),
      };

  bool get isOwner => this == StaffRole.owner;
}

enum AccountKind {
  owner,
  staff,
  unknown;

  static AccountKind parse(Object? value) => switch (value) {
        'owner' => AccountKind.owner,
        'staff' => AccountKind.staff,
        _ => AccountKind.unknown,
      };
}

/// Thành viên được máy chủ xác nhận trong một quán.
class SessionShop {
  const SessionShop({
    required this.shopId,
    required this.shopName,
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.active,
    required this.hasPin,
    required this.isCurrent,
  });

  factory SessionShop.fromMap(Map<String, dynamic> map) => SessionShop(
        shopId: map['shop_id'] as String,
        shopName: map['shop_name'] as String,
        staffId: map['staff_id'] as String,
        fullName: map['full_name'] as String,
        role: StaffRole.parse(map['role'] as String),
        active: map['active'] as bool? ?? false,
        hasPin: map['has_pin'] as bool? ?? false,
        isCurrent: map['is_current'] as bool? ?? false,
      );

  final String shopId;
  final String shopName;
  final String staffId;
  final String fullName;
  final StaffRole role;
  final bool active;
  final bool hasPin;
  final bool isCurrent;

  Profile get profile => Profile(
        staffId: staffId,
        fullName: fullName,
        role: role,
        hasPin: hasPin,
        active: active,
        shopId: shopId,
        shopName: shopName,
      );
}

/// Toàn cảnh phiên do RPC `my_session_context()` trả về, không suy luận quyền từ UI.
class SessionContext {
  const SessionContext({
    required this.accountKind,
    required this.shops,
    required this.pendingInviteCount,
    this.activeShopId,
  });

  factory SessionContext.fromMap(Map<String, dynamic> map) => SessionContext(
        accountKind: AccountKind.parse(map['account_kind']),
        shops: [
          for (final shop in (map['shops'] as List<dynamic>? ?? const []))
            SessionShop.fromMap(shop as Map<String, dynamic>),
        ],
        pendingInviteCount: (map['pending_invite_count'] as num?)?.toInt() ?? 0,
        activeShopId: map['active_shop_id'] as String?,
      );

  final AccountKind accountKind;
  final List<SessionShop> shops;
  final int pendingInviteCount;
  final String? activeShopId;

  SessionShop? get currentShop {
    for (final shop in shops) {
      if (shop.isCurrent) return shop;
    }
    return null;
  }
}

/// Hồ sơ trong quán đang chọn: kết quả của hàm `my_profile()` ở database.
/// Một tài khoản đăng nhập được mà chưa có hồ sơ nghĩa là chưa thuộc quán nào
/// (chưa nhận/chấp nhận lời mời, hoặc chưa tạo quán).
class Profile {
  const Profile({
    required this.staffId,
    required this.fullName,
    required this.role,
    required this.hasPin,
    required this.active,
    this.shopId = '',
    this.shopName = '',
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        staffId: map['staff_id'] as String,
        fullName: map['full_name'] as String,
        role: StaffRole.parse(map['role'] as String),
        hasPin: map['has_pin'] as bool,
        active: map['active'] as bool,
        shopId: (map['shop_id'] as String?) ?? '',
        shopName: (map['shop_name'] as String?) ?? '',
      );

  final String staffId;
  final String fullName;
  final StaffRole role;
  final bool hasPin;
  final bool active;
  final String shopId;
  final String shopName;
}
