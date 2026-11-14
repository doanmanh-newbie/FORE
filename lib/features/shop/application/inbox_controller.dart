import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/failure_messages.dart';
import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';

/// Hộp thư lời mời của nhân viên: tải, tự làm mới định kỳ, chấp nhận, từ chối.
class InboxController extends ChangeNotifier {
  InboxController(this._repository);

  final ShopRepository _repository;

  List<Invite> _invites = const [];
  List<Invite> get invites => _invites;

  bool _loading = true;
  bool get loading => _loading;

  /// Lỗi lần tải gần nhất (null nếu ổn).
  String? _error;
  String? get error => _error;

  /// Id lời mời đang được xử lý (chặn bấm hai lần).
  String? _busyId;
  String? get busyId => _busyId;

  /// Tăng mỗi khi có lời mời MỚI xuất hiện lúc đang xem (để màn hình rung nhẹ).
  int _newArrivals = 0;
  int get newArrivals => _newArrivals;

  Timer? _poll;
  bool _disposed = false;

  /// Làm mới theo chu kỳ (dùng ở màn chờ lời mời).
  void startPolling([Duration every = const Duration(seconds: 15)]) {
    _poll?.cancel();
    _poll = Timer.periodic(every, (_) => load(quiet: true));
  }

  Future<void> load({bool quiet = false}) async {
    if (!quiet) {
      _loading = true;
      notifyListeners();
    }
    try {
      final next = await _repository.myInvites();
      final known = _invites.map((i) => i.id).toSet();
      final fresh = next.where((i) => !known.contains(i.id)).length;
      if (_hasLoadedOnce && fresh > 0) _newArrivals += fresh;
      _hasLoadedOnce = true;
      _invites = next;
      _error = null;
    } on AppFailure catch (f) {
      if (!quiet) _error = f.userMessage;
    }
    _loading = false;
    if (!_disposed) notifyListeners();
  }

  bool _hasLoadedOnce = false;

  /// Chấp nhận. Trả về `null` nếu xong, hoặc câu lỗi để hiện cho người dùng.
  Future<String?> accept(Invite invite) =>
      _act(invite, () => _repository.acceptInvite(invite.id));

  Future<String?> decline(Invite invite) =>
      _act(invite, () => _repository.declineInvite(invite.id));

  Future<String?> _act(Invite invite, Future<void> Function() action) async {
    if (_busyId != null) return null;
    _busyId = invite.id;
    notifyListeners();
    String? error;
    try {
      await action();
      _invites = _invites.where((i) => i.id != invite.id).toList();
    } on InviteNotFoundFailure catch (f) {
      // Lời mời đã bị hủy/xử lý: bỏ khỏi danh sách cho khỏi bấm lại.
      _invites = _invites.where((i) => i.id != invite.id).toList();
      error = f.userMessage;
    } on AppFailure catch (f) {
      error = f.userMessage;
    }
    _busyId = null;
    if (!_disposed) notifyListeners();
    return error;
  }

  @override
  void dispose() {
    _disposed = true;
    _poll?.cancel();
    super.dispose();
  }
}
