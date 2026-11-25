import 'package:fore/core/realtime/live_feed.dart';

/// Bản giả của [LiveFeed]: test tự phát sự kiện và trạng thái kênh.
class FakeLiveFeed implements LiveFeed {
  final List<FakeLiveSubscription> subscriptions = [];

  /// Đặt để mô phỏng không tạo được kênh (ném ngay khi đăng ký).
  Object? throwOnWatch;

  /// Kênh được tạo gần nhất.
  FakeLiveSubscription get last => subscriptions.last;

  /// Các kênh chưa bị gỡ.
  Iterable<FakeLiveSubscription> get active =>
      subscriptions.where((s) => !s.cancelled);

  @override
  LiveSubscription watchShop(
    String? shopId, {
    required void Function(LiveChange change) onChange,
    required void Function(LiveStatus status, Object? error) onStatus,
  }) {
    if (throwOnWatch != null) throw throwOnWatch!;
    final sub = FakeLiveSubscription(shopId, onChange, onStatus);
    subscriptions.add(sub);
    return sub;
  }
}

class FakeLiveSubscription implements LiveSubscription {
  FakeLiveSubscription(this.shopId, this._onChange, this._onStatus);

  final String? shopId;
  final void Function(LiveChange change) _onChange;
  final void Function(LiveStatus status, Object? error) _onStatus;
  bool cancelled = false;

  /// Kênh đã kết nối (`SUBSCRIBED`).
  void connect() => _onStatus(LiveStatus.live, null);

  /// Kênh lỗi / hết thời gian / bị đóng.
  void fail([Object? error = 'CHANNEL_ERROR']) =>
      _onStatus(LiveStatus.offline, error);

  void emit(LiveTable table, {String? billId}) =>
      _onChange(LiveChange(table, billId: billId));

  @override
  Future<void> cancel() async => cancelled = true;
}
