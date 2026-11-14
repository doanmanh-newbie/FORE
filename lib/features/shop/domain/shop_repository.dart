import 'shop_models.dart';

/// Hợp đồng truy cập quán, nhân viên và lời mời. Mọi lỗi ném ra là một `AppFailure`.
abstract interface class ShopRepository {
  /// Tạo quán mới; người tạo là chủ và quán được chọn làm quán hiện tại.
  Future<void> createShop(
      {required String shopName, required String ownerName});

  /// Các quán tôi thuộc về.
  Future<List<ShopMembership>> myShops();

  /// Chuyển sang làm việc ở quán khác.
  Future<void> selectShop(String shopId);

  /// Hộp thư: lời mời đang chờ gửi tới số điện thoại/email đã xác thực của tôi.
  Future<List<Invite>> myInvites();

  /// Chấp nhận lời mời: trở thành nhân viên và chuyển sang quán đó.
  Future<void> acceptInvite(String inviteId);

  Future<void> declineInvite(String inviteId);

  // ---- Chủ quán ----
  Future<List<TeamMember>> team();
  Future<List<PendingInvite>> inviteHistory();

  /// Mời nhân viên bằng số điện thoại (`phone` nhập thế nào cũng được, database chuẩn hóa).
  Future<void> inviteStaff({
    String? phone,
    required String fullName,
    String? email,
  });

  Future<void> cancelInvite(String inviteId);
}
