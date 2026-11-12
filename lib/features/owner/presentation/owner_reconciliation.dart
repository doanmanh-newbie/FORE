part of 'owner_home_screen.dart';

/// Tab Đối soát: danh sách ca và chi tiết từng ca. Giao diện nằm ở `../reconcile/`;
/// file này chỉ nối dữ liệu của dashboard và các thao tác (lưu xử lý, mở thực đơn).
extension _OwnerReconciliation on _OwnerHomeContentState {
  Widget _reconcileList() => ReconcileListView(
        header: _pageHeader(),
        controller: _reconcile,
        onOpen: (report) => _updateState(() => _selectedReport = report.source),
        onOpenOverview: () => _updateState(() {
          _tab = 0;
          _selectedReport = null;
        }),
      );

  Widget _reconcileDetail(OwnerShiftReport report) => ReconcileDetailView(
        key: ValueKey<String>('reconcile-${report.shift['id']}'),
        report: ReconcileReport.fromOwner(report),
        header: _pageHeader(),
        onBack: () => _updateState(() => _selectedReport = null),
        onSaveReview: (handled, note) =>
            _saveShiftReview(report, handled, note),
        onCorrect: (kind, id, qty, reason) =>
            _correctReportEntry(report, kind, id, qty, reason),
        onOpenMenu: () => _updateState(() {
          _tab = 2;
          _selectedReport = null;
        }),
      );
}
