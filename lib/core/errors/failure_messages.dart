import 'app_failure.dart';

/// Chuyển lỗi thành câu tiếng Việt hiển thị cho người dùng.
extension FailureMessage on AppFailure {
  String get userMessage => switch (this) {
        NoNetworkFailure() => 'Không có mạng. Kiểm tra kết nối rồi thử lại.',
        InvalidCredentialsFailure() => 'Email hoặc mật khẩu chưa đúng.',
        EmailAlreadyRegisteredFailure() => 'Email này đã được đăng ký.',
        WeakPasswordFailure() => 'Mật khẩu cần ít nhất 8 ký tự.',
        EmailNotConfirmedFailure() =>
          'Email chưa được xác nhận. Kiểm tra hộp thư của bạn.',
        ShiftAlreadyOpenFailure() => 'Quán đã có ca đang mở.',
        InvalidPhoneFailure() =>
          'Số điện thoại chưa đúng. Ví dụ: 0901 234 567.',
        AlreadyMemberFailure() => 'Người này đã là nhân viên của quán.',
        AlreadyInvitedFailure() =>
          'Số này đã được mời rồi, đang chờ họ chấp nhận.',
        InviteNotFoundFailure() =>
          'Lời mời này không còn nữa. Kéo xuống để làm mới hộp thư.',
        OwnerOnlyFailure() => 'Chỉ chủ quán làm được việc này.',
        InvalidOtpFailure() => 'Mã chưa đúng hoặc đã hết hạn.',
        TooManyRequestsFailure() =>
          'Bạn thử quá nhiều lần. Đợi một chút rồi thử lại.',
        OtpSendFailure() =>
          'Không gửi được mã xác nhận. Kiểm tra số/email rồi thử lại.',
        StaffNotFoundFailure() =>
          'Chưa có tài khoản với thông tin này. Bấm "Tạo tài khoản" để đăng ký.',
        StaffAlreadyExistsFailure() =>
          'Đã có tài khoản với thông tin này. Hãy quay lại và đăng nhập.',
        EmailConfirmRequiredFailure() =>
          'Supabase đang bật "Confirm email". Tắt ở Authentication > Providers > Email rồi thử lại.',
        PhoneLoginDomainRejectedFailure() =>
          'Supabase từ chối email giả của số điện thoại. Hãy đổi StaffCredentials.phoneEmailDomain '
              'sang một tên miền khác (và cả _phone_login_domain() trong 015), hoặc đăng ký bằng email.',
        SessionExpiredFailure() =>
          'Phiên đăng nhập đã hết hạn. Hãy đăng nhập lại.',
        DatabaseFailure(:final code) =>
          databaseMessages[code] ?? 'Có lỗi xảy ra. Thử lại sau ít phút.',
        MissingRpcFailure(:final rpcName) => _missingRpcMessage(rpcName),
        UnknownFailure() => 'Có lỗi xảy ra. Thử lại sau ít phút.',
      };

  bool get shouldRefresh =>
      this is DatabaseFailure &&
      const {
        'TABLE_HAS_OPEN_BILL',
        'BILL_NOT_OPEN',
        'NO_OPEN_SHIFT',
        'SHIFT_ALREADY_OPEN',
        'LINE_ALREADY_VOIDED',
        'NOT_FOUND',
        'TABLE_NOT_FOUND',
      }.contains(code);

  bool get isSessionProblem =>
      this is SessionExpiredFailure ||
      (this is DatabaseFailure &&
          const {'NOT_LOGGED_IN', 'NOT_STAFF'}.contains(code));
}

String _missingRpcMessage(String rpcName) {
  if (rpcName == 'current_shift') {
    return 'Database chưa có hàm current_shift. Hãy chạy database/010_current_shift.sql trên Supabase.';
  }
  const appReadRpcs = {
    'shop_info',
    'shift_close_status',
    'table_map',
    'takeaway_orders',
    'menu_for_sale',
    'bill_detail',
    'count_sheet',
    'ingredient_list',
    'waste_type_list',
  };
  if (appReadRpcs.contains(rpcName)) {
    return 'Database chưa có hàm $rpcName. Hãy chạy database/011_app_read_api.sql trên Supabase.';
  }
  return 'Database chưa có hàm $rpcName. Kiểm tra các migration SQL của dự án trên Supabase.';
}

/// Database errors used by the sales, stocktake and inventory workflows.
const databaseMessages = <String, String>{
  'NOT_LOGGED_IN': 'Bạn chưa đăng nhập. Hãy đăng nhập lại.',
  'NOT_STAFF': 'Tài khoản này chưa được thêm vào quán.',
  'OWNER_ONLY': 'Chỉ chủ quán mới làm được việc này.',
  'NO_OPEN_SHIFT': 'Chưa có ca đang mở. Hãy mở ca trước.',
  'SHIFT_ALREADY_OPEN': 'Đang có một ca mở rồi. Đang tải lại.',
  'OPENING_CASH_INVALID': 'Tiền đầu ca phải là số không âm.',
  'CLOSING_CASH_INVALID': 'Hãy nhập tiền cuối ca bằng 0 hoặc lớn hơn.',
  'TABLE_REQUIRED': 'Hãy chọn bàn cho đơn ăn tại quán.',
  'TABLE_HAS_OPEN_BILL': 'Bàn này vừa có bill mở từ máy khác. Đang tải lại.',
  'BILL_NOT_OPEN': 'Bill này đã được thanh toán hoặc hủy. Đang tải lại.',
  'BILL_EMPTY': 'Bill chưa có món nào.',
  'ITEM_UNAVAILABLE': 'Món này đã ngừng bán.',
  'ITEM_SOLD_OUT': 'Món này đã tạm hết trong ca. Vui lòng chọn món khác.',
  'REASON_REQUIRED': 'Hãy nhập lý do.',
  'DISCOUNT_INVALID': 'Giảm giá không hợp lệ.',
  'OPEN_BILLS_REMAIN': 'Còn bill đang mở. Hãy xử lý hết rồi đóng ca.',
  'MISSING_CLOSE_COUNTS': 'Chưa đếm hết nguyên liệu cuối ca.',
  'KIND_INVALID': 'Loại kiểm kê không hợp lệ.',
  'NOTE_REQUIRED': 'Hãy ghi chú cho thao tác này.',
  'WASTE_TYPE_INVALID': 'Loại hao hụt không hợp lệ.',
  'AMOUNT_INVALID': 'Số tiền không hợp lệ.',
  'QTY_INVALID': 'Số lượng phải lớn hơn 0.',
  'QTY_TOO_LARGE': 'Số lượng quá lớn. Tối đa mỗi dòng là 99.',
  'BILL_TOTAL_OVERFLOW': 'Tổng bill vượt giới hạn cho phép. Kiểm tra lại số lượng.',
  'LINE_ALREADY_VOIDED': 'Dòng này đã được bỏ trước đó. Đang tải lại.',
  'NOT_FOUND': 'Không tìm thấy dữ liệu này. Đang tải lại.',
  'BILL_NOT_PAID': 'Bill chưa được thanh toán.',
  'PAYMENT_METHOD_INVALID': 'Cách thanh toán không hợp lệ.',
  'SHOP_TYPE_INVALID': 'Loại quán không hợp lệ.',
  'CONTACT_REQUIRED': 'Nhập số điện thoại hoặc email của nhân viên.',
  'EMAIL_INVALID': 'Email chưa đúng định dạng.',
  'NAME_REQUIRED': 'Hãy nhập tên.',
  'SHOP_NAME_REQUIRED': 'Hãy nhập tên quán.',
  'BIRTH_DATE_INVALID': 'Ngày sinh không hợp lệ.',
  'LAST_OWNER': 'Quán phải còn ít nhất một chủ quán.',
  'TABLE_NOT_FOUND': 'Không tìm thấy bàn này. Đang tải lại.',
  'PIN_FORMAT': 'Mã PIN gồm 4 đến 6 chữ số.',
  'RECIPE_IN_USE':
      'Size này đã từng bán nên không sửa công thức được. Hãy ẩn size cũ và tạo size mới.',
  'NO_CHANGE': 'Không có gì thay đổi so với số hiện tại.',
  'NOTE_TOO_LONG': 'Ghi chú quá dài (tối đa 1000 ký tự).',
  'DATE_RANGE_INVALID': 'Khoảng thời gian không hợp lệ.',
  'ONLY_CURRENT_SHIFT': 'Chỉ làm được với bill của ca đang mở.',
  'REVIEW_STATUS_INVALID': 'Trạng thái xử lý không hợp lệ.',
  'TOO_MANY_NOTIFICATIONS': 'Chọn quá nhiều thông báo cùng lúc.',
  'DIRECTION_INVALID': 'Loại thu/chi không hợp lệ.',
  'TENDERED_INSUFFICIENT': 'Tiền khách đưa chưa đủ số tiền phải thu.',
  'BANK_CODE_REQUIRED': 'Hãy nhập mã ngân hàng (ví dụ: VCB, MB, TCB...).',
  'ACCOUNT_NO_REQUIRED': 'Hãy nhập số tài khoản ngân hàng.',
  'ACCOUNT_NAME_REQUIRED': 'Hãy nhập tên chủ tài khoản.',
  'WRONG_PIN': 'Mã PIN của chủ quán chưa đúng.',
  'PIN_LOCKED': 'Nhập sai PIN quá số lần cho phép. Chức năng đã bị khóa tạm thời.',
  'NO_OWNER_PIN': 'Quán chưa đặt mã PIN chủ. Hãy nhờ chủ quán thiết lập PIN.',
  'APP_API_MISSING':
      'Database chưa có API giao diện mới. Hãy chạy database/011_app_read_api.sql trên Supabase rồi tải lại.',
};
