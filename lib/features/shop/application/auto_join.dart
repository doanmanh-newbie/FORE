import '../../../core/errors/app_failure.dart';
import '../domain/shop_repository.dart';

/// Chế độ thử nghiệm: nhân viên vừa đăng nhập, chưa thuộc quán nào mà đang có
/// ĐÚNG MỘT lời mời của chủ quán thì vào quán luôn, không bắt bấm "Chấp nhận".
///
/// Có từ hai lời mời trở lên thì không tự chọn thay họ: để nhân viên vào hộp thư
/// chọn quán. Lỗi (mất mạng, lời mời vừa bị hủy...) cũng không làm hỏng đăng nhập:
/// trả về `false` và nhân viên vẫn thấy hộp thư như trước.
///
/// Trả về `true` nếu đã vào được một quán (gọi tiếp `refreshAfterSignIn`).
Future<bool> autoJoinSingleInvite(ShopRepository repository) async {
  try {
    final invites = await repository.myInvites();
    if (invites.length != 1) return false;
    await repository.acceptInvite(invites.single.id);
    return true;
  } on AppFailure {
    return false;
  }
}
