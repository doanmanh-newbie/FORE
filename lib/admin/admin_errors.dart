import '../core/errors/app_failure.dart';
import '../core/errors/failure_messages.dart';

/// Kiểm tra lỗi từ chối quyền quản trị nền tảng từ RPC (`FORBIDDEN`).
bool isAdminForbidden(AppFailure failure) =>
    failure is DatabaseFailure && failure.code == 'FORBIDDEN';

/// Chuyển [AppFailure] sang thông báo tiếng Việt phù hợp với Admin Web.
/// Không sửa `lib/core/errors/failure_messages.dart` (ngoài phạm vi admin web).
String adminFailureMessage(AppFailure failure) {
  if (failure is DatabaseFailure) {
    switch (failure.code) {
      case 'FORBIDDEN':
        return 'Tài khoản này không có quyền super-admin. Hệ thống đã đăng xuất.';
      case 'DATE_RANGE_INVALID':
        return 'Khoảng ngày không hợp lệ (tối đa 366 ngày và ngày bắt đầu phải nhỏ hơn ngày kết thúc).';
      case 'INPUT_INVALID':
        return 'Dữ liệu nhập chưa hợp lệ. Hãy kiểm tra tên khóa và giá trị JSON.';
      case 'NOT_LOGGED_IN':
        return 'Phiên đăng nhập đã hết. Hãy đăng nhập lại.';
    }
  }
  if (failure is MissingRpcFailure) {
    return 'Database chưa có hàm ${failure.rpcName}. Hãy chạy database/09_admin.sql trên Supabase.';
  }
  return failure.userMessage;
}
