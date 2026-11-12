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
        InviteExpiredFailure() =>
          'Lời mời đã hết hạn. Nhờ chủ quán gửi lời mời mới.',
        OwnerOnlyFailure() => 'Chỉ chủ quán làm được việc này.',
        InvalidOtpFailure() => 'Mã chưa đúng hoặc đã hết hạn.',
        TooManyRequestsFailure() =>
          'Bạn thử quá nhiều lần. Đợi một chút rồi thử lại.',
        OtpSendFailure() =>
          'Không gửi được mã xác nhận. Kiểm tra số/email rồi thử lại.',
        StaffAlreadyExistsFailure() =>
          'Đã có tài khoản với thông tin này. Hãy quay lại và đăng nhập.',
        EmailConfirmRequiredFailure() =>
          'Supabase đang bật "Confirm email". Tắt ở Authentication > Providers > Email rồi thử lại.',
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
  const appReadRpcs = {
    'current_shift',
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
    return 'Database chưa có hàm $rpcName. Hãy chạy database/03_read_apis.sql trên Supabase.';
  }
  if (const {
    'my_session_context',
    'my_invites',
    'expire_my_invites',
    'invite_staff',
    'shop_team',
    'accept_invite',
    'decline_invite',
    'cancel_invite',
    'owner_sales_trend',
    'register_staff_device',
    'validate_staff_device',
  }.contains(rpcName)) {
    return 'Database chưa có hàm $rpcName. Hãy cập nhật database/04_membership_sessions.sql trên Supabase.';
  }
  if (const {
    'create_shop',
    'my_shops',
    'select_shop',
    'my_profile',
  }.contains(rpcName)) {
    return 'Database chưa có hàm $rpcName. Hãy chạy database/02_operations_reconciliation.sql trên Supabase.';
  }
  if (rpcName.startsWith('inv_') ||
      rpcName.startsWith('po_') ||
      rpcName.startsWith('sup_') ||
      rpcName.startsWith('st_') ||
      rpcName.startsWith('team_') ||
      rpcName.startsWith('roles_') ||
      rpcName.startsWith('shop_profile') ||
      rpcName.startsWith('floor_') ||
      rpcName.startsWith('area_') ||
      rpcName.startsWith('table_') ||
      rpcName.startsWith('audit_') ||
      rpcName.startsWith('support_') ||
      rpcName.startsWith('branches_')) {
    return 'Database chưa có hàm $rpcName. Hãy chạy database/07_inventory.sql rồi 08_settings.sql trên Supabase.';
  }
  return 'Database chưa có hàm $rpcName. Hãy kiểm tra các nhóm SQL 01–04 trên Supabase.';
}

/// Database errors used by the sales, stocktake and inventory workflows.
const databaseMessages = <String, String>{
  'NOT_LOGGED_IN': 'Bạn chưa đăng nhập. Hãy đăng nhập lại.',
  'NOT_STAFF': 'Tài khoản này chưa được thêm vào quán.',
  'STAFF_DEVICE_UNTRUSTED': 'Thiết bị này chưa được xác minh. Hãy đăng nhập lại bằng mã OTP.',
  'DEVICE_TOKEN_INVALID': 'Không thể xác minh thiết bị này. Hãy gửi lại mã OTP.',
  'OTP_REQUIRED': 'Hãy xác minh OTP trước khi ghi nhớ thiết bị.',
  'SESSION_INVALID': 'Phiên đăng nhập không hợp lệ. Hãy đăng nhập lại bằng OTP.',
  'FILTER_INVALID': 'Bộ lọc không hợp lệ. Hãy tải lại trang và thử lại.',
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
  'REASON_REQUIRED': 'Hãy nhập lý do.',
  'DISCOUNT_INVALID': 'Giảm giá không hợp lệ.',
  'OPEN_BILLS_REMAIN': 'Còn bill đang mở. Hãy xử lý hết rồi đóng ca.',
  'MISSING_CLOSE_COUNTS': 'Chưa đếm hết nguyên liệu cuối ca.',
  'KIND_INVALID': 'Loại kiểm kê không hợp lệ.',
  'NOTE_REQUIRED': 'Hãy ghi chú cho thao tác này.',
  'WASTE_TYPE_INVALID': 'Loại hao hụt không hợp lệ.',
  'AMOUNT_INVALID': 'Số tiền không hợp lệ.',
  'QTY_INVALID': 'Số lượng không hợp lệ.',
  'NOT_FOUND': 'Không tìm thấy dữ liệu này. Đang tải lại.',
  'BILL_NOT_PAID': 'Bill chưa được thanh toán.',
  'PAYMENT_METHOD_INVALID': 'Cách thanh toán không hợp lệ.',
  'SHOP_TYPE_INVALID': 'Loại quán không hợp lệ.',
  'CONTACT_REQUIRED': 'Nhập số điện thoại hoặc email của nhân viên.',
  'INVITE_EXPIRED': 'Lời mời đã hết hạn. Nhờ chủ quán gửi lời mời mới.',
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
  'NAME_EXISTS': 'Tên này đã có rồi. Hãy chọn tên khác.',
  'GROUP_REQUIRED': 'Hãy chọn nhóm nguyên liệu.',
  'GROUP_NOT_EMPTY': 'Nhóm còn nguyên liệu đang dùng. Chuyển chúng sang nhóm khác trước.',
  'UNIT_INVALID': 'Đơn vị kho không hợp lệ.',
  'UNIT_LOCKED': 'Nguyên liệu đã có phiếu hoặc công thức nên không đổi được đơn vị kho.',
  'IMPORTANCE_INVALID': 'Mức quan trọng không hợp lệ.',
  'INGREDIENT_IN_RECIPE': 'Nguyên liệu còn nằm trong công thức đang bán nên chưa ngừng dùng được.',
  'STOCK_NOT_EMPTY': 'Kho vẫn còn nguyên liệu này. Hãy dùng hết hoặc ghi hao hụt trước khi ngừng dùng.',
  'LEAD_DAYS_INVALID': 'Số ngày giao hàng từ 0 đến 30.',
  'SUPPLIER_REQUIRED': 'Hãy chọn nhà cung cấp.',
  'LINES_REQUIRED': 'Phiếu chưa có dòng nguyên liệu nào.',
  'PRICE_REQUIRED': 'Còn dòng chưa có đơn giá. Điền đủ giá rồi xác nhận.',
  'ORDER_NOT_DRAFT': 'Phiếu này đã chốt hoặc đã hủy, không sửa được nữa.',
  'ORDER_NOT_PRICEABLE': 'Phiếu này không cần bổ sung giá.',
  'DATE_INVALID': 'Ngày nhận hàng không hợp lệ.',
  'INPUT_INVALID': 'Có ô nhập chưa đúng. Kiểm tra lại rồi thử.',
  'COUNT_INCOMPLETE': 'Còn dòng chưa đếm. Chưa đếm không có nghĩa là 0.',
  'STOCKTAKE_LOCKED': 'Phiếu kiểm kê này đã gửi hoặc đã duyệt, không sửa được.',
  'DECISION_INVALID': 'Quyết định điều chỉnh không hợp lệ.',
  'ADDRESS_REQUIRED': 'Hãy nhập địa chỉ hiển thị của quán.',
  'MEMBER_HAS_OPEN_SHIFT': 'Người này đang giữ ca. Hãy chốt ca trước khi thu hồi.',
  'OWNER_PROTECTED': 'Không thể thay đổi hay thu hồi chủ quán.',
  'PERMISSION_DENIED': 'Bạn chưa được cấp quyền cho việc này. Hãy nhờ chủ quán.',
  'PERMISSION_UNKNOWN': 'Quyền này không có trong hệ thống.',
  'SHOP_PHONE_INVALID': 'Số điện thoại quán chưa đúng. Ví dụ: 0901234567.',
  'ROLE_INVALID': 'Vai trò không hợp lệ.',
  'SEATS_INVALID': 'Số chỗ từ 1 đến 50.',
  'SELF_PROTECTED': 'Bạn không thể tự thu hồi quyền của chính mình.',
  'TABLE_IN_USE': 'Bàn đang có đơn mở. Hoàn tất hoặc hủy đơn trước.',
  'TAX_CODE_INVALID': 'Mã số thuế gồm 10 số (hoặc 10 số, gạch ngang, 3 số chi nhánh).',
  'TIMEZONE_INVALID': 'Múi giờ không hợp lệ.',
  'TIME_INVALID': 'Giờ mở và giờ đóng cửa chưa đúng (không được trùng nhau).',
  'APP_API_MISSING':
      'Database chưa có API giao diện mới. Hãy chạy database/03_read_apis.sql trên Supabase rồi tải lại.',
};
