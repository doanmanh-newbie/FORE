import 'ops_shift_models.dart';

abstract interface class OpsShiftRepository {
  /// Hồ sơ quán; `null` nếu quán chưa có hồ sơ.
  Future<ShopInfo?> shopInfo();

  /// Ca đang mở; `null` nếu chưa mở ca.
  Future<OpsCurrentShift?> currentShift();

  Future<void> openShift(int openingCash);

  Future<CloseStatus> closeStatus();

  Future<void> closeShift(int closingCash);
}
