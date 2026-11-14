import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../../../core/data/rpc_errors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/network_errors.dart';
import '../domain/auth_models.dart';
import '../domain/auth_repository.dart';
import '../domain/staff_contact.dart';
import 'staff_device_trust_store.dart';

/// Cài đặt [AuthRepository] bằng Supabase. Là nơi duy nhất trong tính năng
/// đăng nhập biết về Supabase và đổi lỗi của nó thành [AppFailure].
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(
    this._client, {
    StaffDeviceTrustStore? deviceTrustStore,
  }) : _deviceTrustStore = deviceTrustStore ?? StaffDeviceTrustStore();

  final SupabaseClient _client;
  final StaffDeviceTrustStore _deviceTrustStore;

  static const _deviceHeader = 'x-fore-device-token';

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
  Future<void> requestStaffOtp(
    StaffContact contact, {
    required bool createUser,
    String? fullName,
    DateTime? birthDate,
  }) =>
      _guard(() async {
        try {
          await _client.auth.signInWithOtp(
            email: contact.email,
            phone: contact.phone,
            shouldCreateUser: createUser,
            data: createUser
                ? {
                    'account_kind': 'staff',
                    'full_name': fullName?.trim() ?? '',
                    if (birthDate != null) 'birth_date': _dateOnly(birthDate),
                  }
                : null,
          );
        } on AuthException catch (e) {
          if (createUser && _isAlreadyRegistered(e)) {
            throw const StaffAlreadyExistsFailure();
          }
          if (!createUser &&
              (_isInvalidLogin(e) || e.code == 'user_not_found')) {
            // Supabase may distinguish missing accounts in its response; do not expose that fact.
            throw const OtpSendFailure();
          }
          rethrow;
        }
      });

  @override
  Future<AuthUser> verifyStaffOtp(StaffContact contact, String token) =>
      _guard(() async {
        final response = await _client.auth.verifyOTP(
          email: contact.email,
          phone: contact.phone,
          token: token,
          type: contact.kind == ContactKind.email ? OtpType.email : OtpType.sms,
        );
        final user = response.user;
        if (user == null || response.session == null) {
          throw const SessionExpiredFailure();
        }
        final appUser = _toAuthUser(user);
        if (appUser.accountKind == AccountKind.owner) {
          await _client.auth.signOut();
          throw const InvalidCredentialsFailure();
        }

        try {
          final secret = await _deviceTrustStore.createSecret(user.id);
          _setDeviceHeader(secret);
          try {
            await _client.rpc(
              'register_staff_device',
              params: {'p_secret': secret},
            );
          } on PostgrestException catch (e) {
            if (e.code == 'PGRST202') {
              throw const MissingRpcFailure('register_staff_device');
            }
            rethrow;
          }
          return appUser;
        } catch (_) {
          _removeDeviceHeader();
          try {
            await _deviceTrustStore.clearSecret(user.id);
          } finally {
            await _client.auth.signOut();
          }
          rethrow;
        }
      });

  @override
  Future<bool> validateStaffDeviceTrust() => _guard(() async {
        final user = _client.auth.currentUser;
        if (user == null) return false;
        final kind = _toAuthUser(user).accountKind;
        if (kind == AccountKind.owner) return true;

        final secret = await _deviceTrustStore.readSecret(user.id);
        if (secret == null || secret.isEmpty) {
          _removeDeviceHeader();
          if (kind == AccountKind.staff) return false;
        } else {
          _setDeviceHeader(secret);
        }
        try {
          final result = await _client.rpc('validate_staff_device');
          return result == true;
        } on PostgrestException catch (e) {
          if (e.code == 'PGRST202') {
            throw const MissingRpcFailure('validate_staff_device');
          }
          rethrow;
        }
      });

  @override
  Future<void> signOut() => _guard(() async {
        final userId = _client.auth.currentUser?.id;
        _removeDeviceHeader();
        await _client.auth.signOut();
        if (userId != null) await _deviceTrustStore.clearSecret(userId);
      });

  void _setDeviceHeader(String secret) {
    _client.headers = {..._client.headers, _deviceHeader: secret};
  }

  void _removeDeviceHeader() {
    final headers = {..._client.headers}..remove(_deviceHeader);
    _client.headers = headers;
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _client.auth.resetPasswordForEmail(email));

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

  static bool _isInvalidLogin(AuthException e) =>
      e.code == 'invalid_credentials' ||
      e.message.toLowerCase().contains('invalid login credentials');

  static bool _isAlreadyRegistered(AuthException e) =>
      e.code == 'user_already_exists' ||
      e.code == 'email_exists' ||
      e.message.toLowerCase().contains('already registered');

  /// Bọc mọi lệnh gọi: lỗi của Supabase/mạng đổi thành [AppFailure].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on AuthRetryableFetchException {
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
    if (code == 'otp_expired' ||
        code == 'otp_disabled' ||
        message.contains('token has expired') ||
        message.contains('invalid') && message.contains('token')) {
      return const InvalidOtpFailure();
    }
    if (code == 'over_sms_send_rate_limit' ||
        code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('for security purposes')) {
      return const TooManyRequestsFailure();
    }
    if (code == 'sms_send_failed' ||
        code == 'phone_provider_disabled' ||
        code == 'validation_failed' ||
        code == 'unexpected_failure' && message.contains('sms')) {
      return const OtpSendFailure();
    }
    if (code == 'email_not_confirmed') return const EmailNotConfirmedFailure();
    // Ghi nguyên nhân thật ra log (terminal của `flutter run` hoặc Console của trình duyệt).
    debugPrint(
        'Fore auth: lỗi chưa nhận diện code=$code status=${e.statusCode} '
        'message=${e.message}');
    return UnknownFailure(e);
  }
}
