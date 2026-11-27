import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/config/app_config.dart';
import '../../../core/data/rpc_errors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/network_errors.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';

/// Cài đặt [AuthRepository] bằng Supabase. Là nơi duy nhất trong tính năng
/// đăng nhập biết về Supabase và đổi lỗi của nó thành [AppFailure].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  @override
  AuthUser? get currentUser {
    final user = _client.auth.currentUser;
    return user == null ? null : _toAuthUser(user);
  }

  @override
  Stream<String?> get userIdChanges => _client.auth.onAuthStateChange
      .map((change) => change.session?.user.id)
      .distinct();

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final res = await _client.auth
            .signInWithPassword(email: email, password: password);
        final user = res.user;
        if (user == null) throw const InvalidCredentialsFailure();
        return _toAuthUser(user);
      });

  @override
  Future<AuthUser?> signInWithSocial(SocialProvider provider) =>
      // Google và Facebook cùng đi qua trang đăng nhập của nhà cung cấp (Custom Tab trên máy,
      // chuyển trang trên web). Không dùng Credential Manager: lỗi cấu hình SHA-1/test user ở đó
      // bị báo thành "người dùng hủy" nên app im lặng, khó biết vì sao không vào được.
      _guard(() => _signInWithOAuth(_oauthOf(provider)));

  static OAuthProvider _oauthOf(SocialProvider p) => switch (p) {
        SocialProvider.google => OAuthProvider.google,
        SocialProvider.facebook => OAuthProvider.facebook,
      };

  /// Đăng nhập qua trang web của nhà cung cấp. Trên máy: mở trình duyệt, chờ deep link
  /// [AppConfig.oauthRedirectUrl] đưa phiên về. Quay lại app mà không có phiên (đóng trình duyệt)
  /// thì coi như hủy.
  Future<AuthUser?> _signInWithOAuth(OAuthProvider provider) async {
    if (kIsWeb) {
      // Quay về đúng trang đang chạy app (không phải Site URL mặc định của Supabase).
      await _client.auth.signInWithOAuth(provider, redirectTo: Uri.base.origin);
      return null;
    }
    final done = Completer<AuthUser?>();
    final sub = _client.auth.onAuthStateChange.listen((change) {
      final user = change.session?.user;
      if (change.event == AuthChangeEvent.signedIn &&
          user != null &&
          !done.isCompleted) {
        done.complete(_toAuthUser(user));
      }
    }, onError: (Object e) {
      // Nhà cung cấp/Supabase trả lỗi qua deep link (vd sai client secret, chưa là test user).
      debugPrint('Fore auth: đăng nhập OAuth lỗi: $e');
      if (!done.isCompleted) done.completeError(SocialSignInFailure(e));
    });
    final lifecycle = AppLifecycleListener(onResume: () {
      // Deep link cần vài giây để đổi mã lấy phiên; quá lâu thì người dùng đã bỏ ngang.
      Future<void>.delayed(const Duration(seconds: 6), () {
        if (!done.isCompleted) done.complete(null);
      });
    });
    try {
      final launched = await _client.auth
          .signInWithOAuth(provider, redirectTo: AppConfig.oauthRedirectUrl);
      if (!launched) throw const SocialSignInFailure('Không mở được trình duyệt');
      return await done.future
          .timeout(const Duration(minutes: 5), onTimeout: () => null);
    } finally {
      await sub.cancel();
      lifecycle.dispose();
    }
  }

  @override
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    required AccountKind accountKind,
  }) =>
      _guard(() async {
        final res = await _client.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': fullName,
            'account_kind': accountKind.name,
          },
        );
        // Khi bật xác nhận email, Supabase không báo lỗi nếu email đã tồn tại
        // mà trả về user không có `identities`.
        if (res.user?.identities?.isEmpty ?? false) {
          throw const EmailAlreadyRegisteredFailure();
        }
        // Tắt xác nhận email: đăng ký xong là đã đăng nhập (đi tiếp tạo quán).
        // Bật xác nhận email: chưa có phiên, người dùng xác nhận email rồi đăng nhập.
        return res.session != null;
      });

  @override
  Future<AuthUser> signInStaff(StaffContact contact, String password) =>
      _guard(() async {
        final res = await _client.auth
            .signInWithPassword(email: contact.loginEmail, password: password);
        final user = res.user;
        if (user == null) throw const InvalidCredentialsFailure();
        final appUser = _toAuthUser(user);
        // Chủ quán đăng nhập ở tab Chủ quán, không qua đường nhân viên.
        if (appUser.accountKind == AccountKind.owner) {
          await _client.auth.signOut();
          throw const InvalidCredentialsFailure();
        }
        return appUser;
      });

  @override
  Future<AuthUser> signUpStaff(
    StaffContact contact,
    String password, {
    required String fullName,
    required DateTime birthDate,
  }) =>
      _guard(() async {
        final res = await _client.auth.signUp(
          email: contact.loginEmail,
          password: password,
          data: {
            'account_kind': 'staff',
            'full_name': fullName.trim(),
            'birth_date': _dateOnly(birthDate),
          },
        );
        // Email đã đăng ký: Supabase trả user không có identities (không báo lỗi).
        if (res.user?.identities?.isEmpty ?? false) {
          throw const StaffAlreadyExistsFailure();
        }
        final user = res.user;
        if (user == null || res.session == null) {
          // Dự án đang bắt xác nhận email nên chưa có phiên: báo rõ thay vì treo.
          throw const EmailConfirmRequiredFailure();
        }
        return _toAuthUser(user);
      });

  @override
  Future<void> signOut() => _guard(() async {
        await _client.auth.signOut();
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      // Link trong email mở thẳng app (deep link), không về Site URL.
      _guard(() => _client.auth.resetPasswordForEmail(email,
          redirectTo: kIsWeb ? null : AppConfig.oauthRedirectUrl));

  @override
  Stream<void> get passwordRecoveries => _client.auth.onAuthStateChange
      .where((c) => c.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> updatePassword(String newPassword) => _guard(() async {
        await _client.auth.updateUser(UserAttributes(password: newPassword));
      });

  @override
  Future<Profile?> fetchProfile() => _guard(() async {
        try {
          final rows = await _client.rpc('my_profile') as List<dynamic>;
          if (rows.isEmpty) return null;
          return Profile.fromMap(rows.first as Map<String, dynamic>);
        } on PostgrestException catch (e) {
          // Database chưa có hàm này (chưa chạy migration): nói rõ thay vì "Có lỗi xảy ra".
          if (e.code == 'PGRST202') throw const MissingRpcFailure('my_profile');
          rethrow;
        }
      });

  @override
  Future<SessionContext> fetchSessionContext({String? preferredShopId}) =>
      _guard(() async {
        try {
          final result = await _client.rpc(
            'my_session_context',
            params: {'p_preferred_shop': preferredShopId},
          );
          return SessionContext.fromMap(result as Map<String, dynamic>);
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST202') {
            throw const MissingRpcFailure('my_session_context');
          }
          rethrow;
        }
      });

  @override
  Future<void> selectShop(String shopId) => _guard(() async {
        await _client.rpc('select_shop', params: {'p_shop': shopId});
        await rememberShop(shopId);
      });

  @override
  Future<String?> lastActiveShopId() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_lastShopKey(userId));
  }

  @override
  Future<void> rememberShop(String shopId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastShopKey(userId), shopId);
  }

  String _lastShopKey(String userId) => 'fore.last_active_shop.$userId';

  AuthUser _toAuthUser(User user) {
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      phone: (user.phone ?? '').replaceFirst(RegExp(r'^\+'), ''),
      displayName: (user.userMetadata?['full_name'] as String?) ?? '',
      birthDate: (user.userMetadata?['birth_date'] as String?) ?? '',
      accountKind: accountKindOf(user),
    );
  }

  /// Loại tài khoản lấy từ `app_metadata` (do trigger `stamp_account_kind` đóng dấu, người
  /// dùng không sửa được). `user_metadata` tự sửa được nên không tin ở đây.
  /// Cần đã chạy migration 04; tài khoản chưa có dấu là `unknown`.
  @visibleForTesting
  static AccountKind accountKindOf(User user) =>
      AccountKind.parse(user.appMetadata['fore_account_kind']);

  static String _dateOnly(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  /// Bọc mọi lệnh gọi: lỗi của Supabase/mạng đổi thành [AppFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on AuthRetryableFetchException catch (e) {
      // Có mã trạng thái (5xx) là máy chủ trả lỗi, không phải mất mạng.
      if (e.statusCode != null) {
        debugPrint('Fore auth: máy chủ lỗi ${e.statusCode}: ${e.message}');
        throw ServerFailure(e);
      }
      throw const NoNetworkFailure();
    } on AuthWeakPasswordException {
      throw const WeakPasswordFailure();
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } on PostgrestException catch (e) {
      // Lỗi từ database (không phải đăng nhập): mã nghiệp vụ thì có câu tiếng Việt, còn lại ghi log.
      final mapped = mapPostgrestError(message: e.message, code: e.code);
      if (mapped is UnknownFailure) {
        debugPrint(
            'Fore auth: lỗi database code=${e.code} message=${e.message}');
      }
      throw mapped;
    } on SocketException {
      throw const NoNetworkFailure();
    } on TimeoutException {
      throw const NoNetworkFailure();
    } catch (e) {
      if (looksLikeNetworkError(e)) throw const NoNetworkFailure();
      debugPrint('Fore auth: lỗi không rõ (${e.runtimeType}): $e');
      throw UnknownFailure(e);
    }
  }

  AppFailure _mapAuthException(AuthException e) {
    final code = e.code ?? '';
    final message = e.message.toLowerCase();
    if (code == 'invalid_credentials' ||
        message.contains('invalid login credentials')) {
      return const InvalidCredentialsFailure();
    }
    if (code == 'user_already_exists' ||
        code == 'email_exists' ||
        message.contains('already registered')) {
      return const EmailAlreadyRegisteredFailure();
    }
    if (code == 'weak_password') return const WeakPasswordFailure();
    if (code == 'over_request_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('for security purposes')) {
      return const TooManyRequestsFailure();
    }
    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return const ContactInvalidFailure();
    }
    if (code == 'email_not_confirmed') return const EmailNotConfirmedFailure();
    // Ghi nguyên nhân thật ra log (terminal của `flutter run` hoặc Console của trình duyệt).
    debugPrint(
        'Fore auth: lỗi chưa nhận diện code=$code status=${e.statusCode} '
        'message=${e.message}');
    return UnknownFailure(e);
  }
}
