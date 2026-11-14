import 'auth_models.dart';
import 'staff_contact.dart';

/// Hợp đồng truy cập tài khoản. Controller và màn hình chỉ biết lớp này,
/// không biết Supabase. Nhờ vậy:
///  - test dùng được bản giả (không cần mạng),
///  - đổi nhà cung cấp chỉ phải viết lại một lớp ở thư mục `data/`.
///
/// Mọi lỗi được ném ra là một [AppFailure].
abstract interface class AuthRepository {
  /// Người đang đăng nhập (đọc từ bộ nhớ máy, không cần mạng). `null` nếu chưa.
  AuthUser? get currentUser;

  /// Phát id người dùng (hoặc `null` khi đăng xuất) mỗi khi phiên Auth đổi,
  /// kể cả khi đổi từ tab/cửa sổ khác. Chỉ phát khi id thật sự thay đổi.
  Stream<String?> get userIdChanges;

  Future<AuthUser> signIn({required String email, required String password});

  /// Tạo tài khoản chủ quán (email + mật khẩu). Trả về `true` nếu đã đăng nhập luôn
  /// (Supabase tắt xác nhận email), `false` nếu phải xác nhận email rồi mới đăng nhập.
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    required AccountKind accountKind,
  });

  /// Đọc vai trò khởi tạo, thành viên, quán hiện tại và lời mời từ máy chủ.
  Future<SessionContext> fetchSessionContext({String? preferredShopId});

  /// Chọn quán; máy chủ xác minh người dùng còn là thành viên hoạt động.
  Future<void> selectShop(String shopId);

  Future<String?> lastActiveShopId();
  Future<void> rememberShop(String shopId);

  /// Gửi OTP tới email/số điện thoại thật; không tự động đăng nhập.
  /// Khi [createUser] là false, không tạo tài khoản mới.
  Future<void> requestStaffOtp(
    StaffContact contact, {
    required bool createUser,
    String? fullName,
    DateTime? birthDate,
  });

  /// Xác minh OTP, đăng nhập và ghi nhận thiết bị hiện tại làm thiết bị tin cậy.
  Future<AuthUser> verifyStaffOtp(StaffContact contact, String token);

  /// Xác minh bằng máy chủ rằng phiên nhân viên còn thiết bị tin cậy hợp lệ.
  Future<bool> validateStaffDeviceTrust();

  Future<void> signOut();

  Future<void> sendPasswordReset(String email);

  /// Hồ sơ trong quán của người đang đăng nhập; `null` nếu chưa được thêm.
  Future<Profile?> fetchProfile();
}
