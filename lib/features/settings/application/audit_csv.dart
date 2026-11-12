import 'dart:convert';

import '../domain/settings_models.dart';

/// Tên tiếng Việt cho các hành động ghi trong nhật ký; hành động lạ thì giữ nguyên mã để không che mất dữ liệu.
String auditLabel(String action) => switch (action) {
      'roles_save' => 'Đổi quyền của vai trò',
      'set_job_role' => 'Đổi vai trò thành viên',
      'revoke_member' => 'Thu hồi thành viên',
      'invite_role' => 'Chọn vai trò cho lời mời',
      'resend_invite' => 'Gia hạn lời mời',
      'shop_profile_save' => 'Sửa hồ sơ quán',
      'area_save' => 'Lưu khu vực',
      'area_set_active' => 'Ẩn/hiện khu vực',
      'table_save' => 'Lưu bàn',
      'table_set_active' => 'Ẩn/hiện bàn',
      'po_confirm' => 'Xác nhận phiếu nhập',
      'po_set_prices' => 'Bổ sung giá phiếu nhập',
      'st_approve' => 'Duyệt kiểm kê',
      'st_recount' => 'Yêu cầu đếm lại',
      'ingredient_create' => 'Thêm nguyên liệu',
      'ingredient_update' => 'Sửa nguyên liệu',
      'ingredient_set_active' => 'Ngừng/dùng lại nguyên liệu',
      _ => action,
    };

String _cell(String s) {
  // Chống "CSV injection": ô bắt đầu bằng = + - @ sẽ bị Excel hiểu là công thức.
  final safe = RegExp(r'^[=+\-@\t\r]').hasMatch(s) ? "'$s" : s;
  return '"${safe.replaceAll('"', '""')}"';
}

/// Dựng CSV (UTF-8) từ các dòng nhật ký: thời gian, người làm, hành động, đối tượng, chi tiết.
String auditCsv(List<AuditEvent> events) {
  final b = StringBuffer('Thời gian,Người thực hiện,Hành động,Đối tượng,Chi tiết\r\n');
  for (final e in events) {
    final t = e.at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    final when =
        '${t.year}-${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
    b.write([
      _cell(when),
      _cell(e.actorName ?? ''),
      _cell(auditLabel(e.action)),
      _cell(e.entity),
      _cell(e.detail == null ? '' : jsonEncode(e.detail)),
    ].join(','));
    b.write('\r\n');
  }
  return b.toString();
}
