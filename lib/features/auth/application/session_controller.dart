import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';

sealed class SessionState {
  const SessionState();
}

class SessionChecking extends SessionState {
  const SessionChecking();
}

class SessionSignedOut extends SessionState {
  const SessionSignedOut();
}

class SessionOffline extends SessionState {
  const SessionOffline();
}

/// Đã đăng nhập nhưng máy chủ trả lỗi khi tải phiên (không phải mất mạng).
/// KHÔNG phải đăng xuất: hiện nút thử lại, không đẩy về màn đăng nhập.
class SessionFailed extends SessionState {
  const SessionFailed(this.failure);

  final AppFailure failure;
}

/// Đã đăng nhập nhưng chưa có thành viên quán; tài khoản này cần tạo quán.
class SessionNeedsShop extends SessionState {
  const SessionNeedsShop(this.user, this.context);

  final AuthUser user;
  final SessionContext context;
}

/// Nhân viên chưa được thêm vào quán; hộp thư lời mời vẫn khả dụng.
class SessionAwaitingInvite extends SessionState {
  const SessionAwaitingInvite(this.user, this.context);

  final AuthUser user;
  final SessionContext context;
}

/// Tài khoản từng có quán gần nhất nhưng server không còn membership hoạt động.
class SessionMembershipRevoked extends SessionState {
  const SessionMembershipRevoked(this.user, this.previousShopId);

  final AuthUser user;
  final String previousShopId;
}

/// Quyền hiện tại luôn đến từ membership của quán đang chọn trên máy chủ.
class SessionReady extends SessionState {
  const SessionReady(
    this.profile, {
    this.shops = const [],
    this.pendingInviteCount = 0,
  });

  final Profile profile;
  final List<SessionShop> shops;
  final int pendingInviteCount;
}

/// Tương thích với các widget cũ trong lúc P2 được chuyển đổi dần.
typedef SessionSignedIn = SessionReady;

class SessionController extends ChangeNotifier {
  SessionController(
    this._repository, {
    this.minVisible = const Duration(milliseconds: 1400),
    this.timeout = const Duration(seconds: 10),
  });

  final AuthRepository _repository;
  final Duration minVisible;
  final Duration timeout;

  SessionState _state = const SessionChecking();
  SessionState get state => _state;

  Future<void> restore({bool skipMinWait = false}) async {
    _listenAuth();
    _set(const SessionChecking());
    final minDelay =
        skipMinWait ? Future<void>.value() : Future<void>.delayed(minVisible);
    SessionState next;
    try {
      final seq = ++_resolveSeq;
      next = await _resolve().timeout(timeout);
      if (seq != _resolveSeq) return; // đã có lần tải mới hơn đảm nhận
    } on TimeoutException {
      next = const SessionOffline();
    } on NoNetworkFailure {
      next = const SessionOffline();
    } on SessionExpiredFailure {
      next = const SessionSignedOut();
    } on AppFailure catch (failure) {
      // Chỉ coi là đăng xuất khi thật sự không còn người dùng; lỗi dịch vụ
      // (RPC, database...) giữ phiên và cho thử lại.
      next = _repository.currentUser == null
          ? const SessionSignedOut()
          : SessionFailed(failure);
    } catch (error) {
      // Lỗi không lường trước không được để Splash kẹt mãi.
      next = _repository.currentUser == null
          ? const SessionSignedOut()
          : SessionFailed(UnknownFailure(error));
    }
    await minDelay;
    _set(next);
  }

  StreamSubscription<String?>? _authSub;
  String? _knownUserId;
  bool _disposed = false;

  /// Số thứ tự của lần tải phiên mới nhất. Kết quả của lần tải cũ hơn bị bỏ,
  /// nên một phản hồi chậm không ghi đè trạng thái mới hơn.
  int _resolveSeq = 0;

  /// Tải phiên rồi áp dụng; trả `false` nếu đã có lần tải mới hơn thay thế.
  Future<bool> _resolveAndSet() async {
    final seq = ++_resolveSeq;
    final next = await _resolve();
    if (seq != _resolveSeq) return false;
    _set(next);
    return true;
  }

  /// Theo dõi đổi phiên Auth (đăng nhập/đăng xuất ở tab khác).
  void _listenAuth() {
    _authSub ??= _repository.userIdChanges.listen(_onAuthUserChanged);
  }

  Future<void> _onAuthUserChanged(String? id) async {
    if (_disposed || id == _knownUserId) return;
    final state = _state;
    if (state is SessionChecking || state is SessionSignedOut) return;
    if (id == null) {
      _knownUserId = null;
      _set(const SessionSignedOut());
      return;
    }
    // Đổi sang tài khoản khác: tải lại vai trò và quán, không qua màn chờ.
    final seq = _resolveSeq + 1;
    try {
      await _resolveAndSet();
    } on NoNetworkFailure {
      if (seq == _resolveSeq) _set(const SessionOffline());
    } on AppFailure catch (failure) {
      if (seq == _resolveSeq) _set(SessionFailed(failure));
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _authSub?.cancel();
    super.dispose();
  }

  Future<AppFailure?> refreshAfterSignIn() async {
    try {
      await _resolveAndSet();
      return null;
    } on AppFailure catch (failure) {
      return failure;
    }
  }

  Future<AppFailure?> chooseShop(String shopId) async {
    try {
      await _repository.selectShop(shopId);
      await _resolveAndSet();
      return null;
    } on AppFailure catch (failure) {
      return failure;
    }
  }

  Future<AppFailure?> signOut() async {
    try {
      await _repository.signOut();
    } on AppFailure catch (failure) {
      return failure;
    }
    _resolveSeq++; // bỏ kết quả tải phiên đang chạy dở, tránh ghi đè SignedOut
    _knownUserId = null;
    _set(const SessionSignedOut());
    return null;
  }

  Future<SessionState> _resolve() async {
    final user = _repository.currentUser;
    _knownUserId = user?.id;
    if (user == null) return const SessionSignedOut();

    // Validate employee device proof before any RPC can return tenant data.
    if (user.accountKind != AccountKind.owner &&
        !await _repository.validateStaffDeviceTrust()) {
      await _repository.signOut();
      _knownUserId = null;
      return const SessionSignedOut();
    }

    final preferredShopId = await _repository.lastActiveShopId();
    final context = await _repository.fetchSessionContext(
      preferredShopId: preferredShopId,
    );
    final currentShop = context.currentShop;
    if (currentShop != null && currentShop.active) {
      await _repository.rememberShop(currentShop.shopId);
      return SessionReady(
        currentShop.profile,
        shops: context.shops,
        pendingInviteCount: context.pendingInviteCount,
      );
    }

    // Defensive recovery for older server records with members but no selected shop.
    final membership = context.shops.where((s) => s.active).firstOrNull;
    if (membership != null) {
      await _repository.selectShop(membership.shopId);
      final refreshed = await _repository.fetchSessionContext(
        preferredShopId: membership.shopId,
      );
      final selected = refreshed.currentShop;
      if (selected != null && selected.active) {
        await _repository.rememberShop(selected.shopId);
        return SessionReady(
          selected.profile,
          shops: refreshed.shops,
          pendingInviteCount: refreshed.pendingInviteCount,
        );
      }
    }

    if (preferredShopId != null &&
        context.pendingInviteCount == 0 &&
        context.accountKind == AccountKind.staff) {
      return SessionMembershipRevoked(user, preferredShopId);
    }

    return switch (context.accountKind) {
      AccountKind.owner => SessionNeedsShop(user, context),
      AccountKind.staff ||
      AccountKind.unknown =>
        SessionAwaitingInvite(user, context),
    };
  }

  void _set(SessionState next) {
    if (_disposed) return;
    _state = next;
    notifyListeners();
  }
}
