import 'package:flutter/foundation.dart';

import '../domain/owner_dashboard_models.dart';
import 'reconcile_models.dart';

enum ReconcileFilter { all, attention, unhandled, pending }

extension ReconcileFilterX on ReconcileFilter {
  String get apiValue => switch (this) {
        ReconcileFilter.all => 'all',
        ReconcileFilter.attention => 'attention',
        ReconcileFilter.unhandled => 'unhandled',
        ReconcileFilter.pending => 'pending',
      };

  String get label => switch (this) {
        ReconcileFilter.all => 'Tất cả',
        ReconcileFilter.attention => 'Cần xem',
        ReconcileFilter.unhandled => 'Chưa xử lý',
        ReconcileFilter.pending => 'Cần xử lý',
      };
}

typedef ReconcilePageLoader = Future<OwnerShiftPage> Function({
  required DateTime from,
  required DateTime to,
  required String filter,
  DateTime? before,
});

/// Giữ trạng thái danh sách đối soát (ngày, bộ lọc, các trang đã tải) để không mất
/// khi chủ mở chi tiết một ca rồi quay lại.
class ReconcileListController extends ChangeNotifier {
  ReconcileListController({required this.loader, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final ReconcilePageLoader loader;
  final DateTime Function() _clock;

  /// Số ngày được xem khi chưa chọn ngày cụ thể (database cho tối đa 62 ngày).
  static const recentDays = 60;

  DateTime? date;
  ReconcileFilter filter = ReconcileFilter.all;
  List<ReconcileReport> items = const [];
  bool loading = false;
  bool loadingMore = false;
  bool hasMore = false;
  bool loaded = false;
  bool hasOpenShift = false;
  Object? failure;
  Object? moreFailure;

  DateTime? _next;
  int _generation = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Ngày làm việc bắt đầu lúc 6 giờ sáng, giống tổng quan.
  (DateTime, DateTime) get _range {
    final picked = date;
    if (picked != null) {
      final start = DateTime(picked.year, picked.month, picked.day, 6);
      return (start, start.add(const Duration(days: 1)));
    }
    final now = _clock();
    return (
      now.subtract(const Duration(days: recentDays)),
      now.add(const Duration(days: 1)),
    );
  }

  Future<void> ensureLoaded() {
    if (loaded || loading) return Future.value();
    return reload();
  }

  void setDate(DateTime? value) {
    date = value == null ? null : DateTime(value.year, value.month, value.day);
    reload();
  }

  void setFilter(ReconcileFilter value) {
    if (value == filter) return;
    filter = value;
    reload();
  }

  void clearSelection() {
    date = null;
    filter = ReconcileFilter.all;
    reload();
  }

  /// `silent` giữ danh sách hiện tại trong lúc tải lại (kéo để làm mới, sau khi lưu).
  Future<void> reload({bool silent = false}) async {
    final generation = ++_generation;
    failure = null;
    moreFailure = null;
    loadingMore = false;
    if (!silent) {
      loading = true;
      items = const [];
      hasMore = false;
    }
    _notify();
    try {
      final (from, to) = _range;
      final page = await loader(
        from: from,
        to: to,
        filter: filter.apiValue,
      );
      if (generation != _generation) return;
      items = page.items.map(ReconcileReport.fromOwner).toList(growable: false);
      hasMore = page.hasMore;
      _next = page.nextBefore;
      hasOpenShift = page.openShift != null;
    } catch (error) {
      if (generation != _generation) return;
      failure = error;
    } finally {
      if (generation == _generation) {
        loading = false;
        loaded = true;
        _notify();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || _next == null) return;
    final generation = _generation;
    loadingMore = true;
    moreFailure = null;
    _notify();
    try {
      final (from, to) = _range;
      final page = await loader(
        from: from,
        to: to,
        filter: filter.apiValue,
        before: _next,
      );
      if (generation != _generation) return;
      items = [
        ...items,
        ...page.items.map(ReconcileReport.fromOwner),
      ];
      hasMore = page.hasMore;
      _next = page.nextBefore;
    } catch (error) {
      if (generation != _generation) return;
      moreFailure = error;
    } finally {
      if (generation == _generation) {
        loadingMore = false;
        _notify();
      }
    }
  }
}
