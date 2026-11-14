import 'package:flutter/widgets.dart';

/// Chuyển động của app tôn trọng cài đặt "tắt hoạt ảnh" của hệ thống:
/// khi người dùng tắt, mọi thời lượng thành 0 (hiện ngay trạng thái cuối).
abstract final class Motion {
  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);

  static Duration of(BuildContext context, Duration normal) =>
      reduced(context) ? Duration.zero : normal;
}
