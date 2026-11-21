import 'dart:async';

import 'package:flutter/foundation.dart';

import 'live_feed.dart';

/// Biến sự kiện realtime thành lệnh tải lại, và lo vòng đời kết nối:
///
/// - Gộp nhiều sự kiện liên tiếp (thanh toán = sửa bill + nhiều dòng) thành MỘT lần tải lại.
/// - Mỗi khi kênh chuyển sang `live` (lần đầu và sau khi mất kết nối) thì gọi [onResync]
///   để bù các thay đổi bị lỡ.
/// - Kênh lỗi / hết thời gian / bị đóng: báo `offline` (màn hình bật lại tải theo giờ)
///   và tự đăng ký lại sau [retryDelays] (tăng dần, giữ mức cuối).
/// - [stop] / [dispose] luôn gỡ kênh; sự kiện của kênh cũ về muộn bị bỏ qua.
class LiveSyncController extends ChangeNotifier {
  LiveSyncController(
    this._feed, {
    required this.onShiftChanged,
    required this.onBillsChanged,
    required this.onResync,
    this.debounce = const Duration(milliseconds: 300),
    this.retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ],
  }) : assert(retryDelays.isNotEmpty);

  final LiveFeed _feed;

  /// Ca của quán vừa đổi (mở/đóng ca ở máy nào đó).
  final VoidCallback onShiftChanged;

  /// Bill vừa đổi; tập mã bill bị ảnh hưởng (có thể rỗng nếu không đọc được mã).
  final void Function(Set<String> billIds) onBillsChanged;

  /// Vừa kết nối (lại): tải lại toàn bộ.
  final VoidCallback onResync;

  final Duration debounce;
  final List<Duration> retryDelays;

  LiveStatus _status = LiveStatus.offline;
  LiveStatus get status => _status;
  bool get isLive => _status == LiveStatus.live;

  bool _started = false;
  bool get started => _started;
  String? _shopId;
  LiveSubscription? _sub;
  int _generation = 0;
  int _attempt = 0;
  Timer? _retryTimer;
  Timer? _shiftTimer;
  Timer? _billTimer;
  final Set<String> _pendingBills = {};
  bool _disposed = false;

  /// Bắt đầu nghe quán `shopId`. Gọi lại với cùng quán thì không làm gì;
  /// đổi quán thì gỡ kênh cũ rồi nghe quán mới.
  void start(String? shopId) {
    if (_disposed) return;
    if (_started && shopId == _shopId) return;
    _teardown();
    _started = true;
    _shopId = shopId;
    _attempt = 0;
    _subscribe();
  }

  /// Ngừng nghe và gỡ kênh (thoát màn hình, đăng xuất).
  void stop() {
    if (!_started) return;
    _teardown();
    _started = false;
    _setStatus(LiveStatus.offline);
  }

  /// Thử kết nối lại ngay (ví dụ app vừa quay lại từ nền) nếu đang không `live`.
  void reconnectNow() {
    if (!_started || _disposed || isLive) return;
    _teardown();
    _subscribe();
  }

  void _subscribe() {
    final generation = ++_generation;
    _setStatus(LiveStatus.connecting);
    try {
      _sub = _feed.watchShop(
        _shopId,
        onChange: (change) {
          if (generation == _generation) _onChange(change);
        },
        onStatus: (status, error) {
          if (generation == _generation) _onStatus(status, error);
        },
      );
    } catch (e) {
      // Không tạo được kênh (ví dụ chưa khởi tạo Supabase): xử lý như mất kết nối.
      _onStatus(LiveStatus.offline, e);
    }
  }

  void _onStatus(LiveStatus status, Object? error) {
    if (_disposed) return;
    switch (status) {
      case LiveStatus.live:
        _retryTimer?.cancel();
        _attempt = 0;
        final wasLive = isLive;
        _setStatus(LiveStatus.live);
        if (!wasLive) _safely(onResync);
      case LiveStatus.connecting:
        _setStatus(LiveStatus.connecting);
      case LiveStatus.offline:
        if (error != null) debugPrint('Fore: kênh realtime ngắt: $error');
        _setStatus(LiveStatus.offline);
        _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive ?? false) return;
    final delay = retryDelays[_attempt.clamp(0, retryDelays.length - 1)];
    _attempt++;
    _retryTimer = Timer(delay, () {
      if (_disposed || !_started || isLive) return;
      _teardown();
      _subscribe();
    });
  }

  void _onChange(LiveChange change) {
    if (_disposed) return;
    if (change.table == LiveTable.shifts) {
      _shiftTimer?.cancel();
      _shiftTimer = Timer(debounce, () => _safely(onShiftChanged));
      return;
    }
    if (change.billId != null) _pendingBills.add(change.billId!);
    _billTimer?.cancel();
    _billTimer = Timer(debounce, () {
      final ids = Set<String>.of(_pendingBills);
      _pendingBills.clear();
      _safely(() => onBillsChanged(ids));
    });
  }

  /// Gỡ kênh hiện tại và hủy mọi hẹn giờ; sự kiện của kênh cũ bị bỏ qua nhờ `_generation`.
  void _teardown() {
    _generation++;
    _retryTimer?.cancel();
    _shiftTimer?.cancel();
    _billTimer?.cancel();
    _pendingBills.clear();
    final sub = _sub;
    _sub = null;
    if (sub != null) {
      unawaited(sub.cancel().catchError((Object e) {
        debugPrint('Fore: gỡ kênh realtime lỗi: $e');
      }));
    }
  }

  void _setStatus(LiveStatus status) {
    if (_status == status || _disposed) return;
    _status = status;
    notifyListeners();
  }

  /// Lỗi trong lệnh tải lại không được làm hỏng vòng nghe realtime.
  void _safely(VoidCallback action) {
    try {
      action();
    } catch (e) {
      debugPrint('Fore: xử lý sự kiện realtime lỗi: $e');
    }
  }

  @override
  void dispose() {
    _teardown();
    _started = false;
    _disposed = true;
    super.dispose();
  }
}
