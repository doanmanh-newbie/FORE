/// Mọi lỗi nghiệp vụ của app là một lớp con của [AppFailure].
///
/// - `code` là mã lỗi viết hoa tiếng Anh (khớp quy ước với database).
/// - Câu tiếng Việt cho người dùng nằm ở `failure_messages.dart`,
///   để lớp lỗi không phụ thuộc vào giao diện.
///
/// `sealed` giúp `switch` bắt buộc xử lý đủ mọi loại lỗi: thêm lỗi mới mà
/// quên viết câu thông báo thì trình biên dịch báo ngay.
sealed class AppFailure implements Exception {
  const AppFailure(this.code);

  final String code;

  @override
  String toString() => '$runtimeType($code)';
}

class NoNetworkFailure extends AppFailure {
  const NoNetworkFailure() : super('NO_NETWORK');
}

class InvalidCredentialsFailure extends AppFailure {
  const InvalidCredentialsFailure() : super('INVALID_CREDENTIALS');
}

class EmailAlreadyRegisteredFailure extends AppFailure {
  const EmailAlreadyRegisteredFailure() : super('EMAIL_ALREADY_REGISTERED');
}

class WeakPasswordFailure extends AppFailure {
  const WeakPasswordFailure() : super('WEAK_PASSWORD');
}

class EmailNotConfirmedFailure extends AppFailure {
  const EmailNotConfirmedFailure() : super('EMAIL_NOT_CONFIRMED');
}

/// Có người khác vừa mở ca (cả quán chỉ có một ca mở tại một thời điểm).
class ShiftAlreadyOpenFailure extends AppFailure {
  const ShiftAlreadyOpenFailure() : super('SHIFT_ALREADY_OPEN');
}

/// Số điện thoại không hợp lệ.
class InvalidPhoneFailure extends AppFailure {
  const InvalidPhoneFailure() : super('PHONE_INVALID');
}

/// Người này đã là thành viên của quán.
class AlreadyMemberFailure extends AppFailure {
  const AlreadyMemberFailure() : super('ALREADY_MEMBER');
}

/// Số này đã được mời và đang chờ trả lời.
class AlreadyInvitedFailure extends AppFailure {
  const AlreadyInvitedFailure() : super('ALREADY_INVITED');
}

/// Lời mời không còn (đã bị hủy, đã xử lý, hoặc không gửi cho mình).
class InviteNotFoundFailure extends AppFailure {
  const InviteNotFoundFailure() : super('INVITE_NOT_FOUND');
}

/// Lời mời đã quá thời hạn phản hồi.
class InviteExpiredFailure extends AppFailure {
  const InviteExpiredFailure() : super('INVITE_EXPIRED');
}

/// Việc này chỉ chủ quán làm được.
class OwnerOnlyFailure extends AppFailure {
  const OwnerOnlyFailure() : super('OWNER_ONLY');
}

/// Mã xác nhận (OTP) sai hoặc hết hạn.
class InvalidOtpFailure extends AppFailure {
  const InvalidOtpFailure() : super('OTP_INVALID');
}

/// Gửi mã quá nhiều lần trong thời gian ngắn.
class TooManyRequestsFailure extends AppFailure {
  const TooManyRequestsFailure() : super('TOO_MANY_REQUESTS');
}

/// Không gửi được mã xác nhận (chưa bật nhà cung cấp SMS, số không nhận được...).
class OtpSendFailure extends AppFailure {
  const OtpSendFailure() : super('OTP_SEND_FAILED');
}

/// Tạo tài khoản nhân viên: số/email này đã có tài khoản.
class StaffAlreadyExistsFailure extends AppFailure {
  const StaffAlreadyExistsFailure() : super('STAFF_ALREADY_EXISTS');
}

/// Supabase đang bật "Confirm email" nên đăng ký xong chưa vào được ngay (lỗi cấu hình khi thử).
class EmailConfirmRequiredFailure extends AppFailure {
  const EmailConfirmRequiredFailure() : super('EMAIL_CONFIRM_REQUIRED');
}

class UnknownFailure extends AppFailure {
  const UnknownFailure([this.detail]) : super('UNKNOWN');

  /// Chi tiết kỹ thuật để ghi log, không hiện cho người dùng.
  final Object? detail;
}

class SessionExpiredFailure extends AppFailure {
  const SessionExpiredFailure() : super('SESSION_EXPIRED');
}

class DatabaseFailure extends AppFailure {
  const DatabaseFailure(super.code);
}

class MissingRpcFailure extends AppFailure {
  const MissingRpcFailure(this.rpcName) : super('RPC_MISSING');

  final String rpcName;
}
