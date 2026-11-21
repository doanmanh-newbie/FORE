import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data/rpc_client.dart';
import '../../core/data/rpc_errors.dart';
import '../../core/errors/app_failure.dart';
import '../../core/errors/network_errors.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';

/// Xác thực super-admin bằng Supabase Auth + RPC `is_platform_admin()`.
class SupabaseAdminAuthRepository implements AdminAuthRepository {
  SupabaseAdminAuthRepository(this._client, this._rpc);

  final SupabaseClient _client;
  final RpcClient _rpc;

  @override
  Future<AdminIdentity?> restoreSession() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final ok = await _isPlatformAdmin();
      if (!ok) {
        await _safeSignOut();
        return null;
      }
      return AdminIdentity(userId: user.id, email: user.email ?? '');
    } on AppFailure {
      await _safeSignOut();
      return null;
    }
  }

  @override
  Future<AdminIdentity> signIn({
    required String email,
    required String password,
  }) =>
      _guard(() async {
        final response = await _client.auth.signInWithPassword(
          email: email.trim(),
          password: password,
        );
        final user = response.user;
        if (user == null) throw const InvalidCredentialsFailure();

        final ok = await _isPlatformAdmin();
        if (!ok) {
          await _safeSignOut();
          throw const DatabaseFailure('FORBIDDEN');
        }
        return AdminIdentity(userId: user.id, email: user.email ?? email.trim());
      });

  @override
  Future<void> signOut() => _guard(() => _client.auth.signOut());

  Future<bool> _isPlatformAdmin() async {
    final raw = await _rpc.call('is_platform_admin');
    return raw == true;
  }

  Future<void> _safeSignOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Bỏ qua lỗi phụ khi tự động đăng xuất tài khoản không đủ quyền.
    }
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw const NoNetworkFailure();
    } on AuthException catch (e) {
      throw _mapAuthException(e);
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') throw const MissingRpcFailure('is_platform_admin');
      throw mapPostgrestError(message: e.message, code: e.code);
    } on TimeoutException {
      throw const NoNetworkFailure();
    } catch (e) {
      if (looksLikeNetworkError(e)) throw const NoNetworkFailure();
      debugPrint('Fore admin auth: lỗi không rõ (${e.runtimeType}): $e');
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
    if (code == 'over_request_rate_limit' ||
        message.contains('rate limit') ||
        message.contains('for security purposes')) {
      return const TooManyRequestsFailure();
    }
    if (code == 'email_not_confirmed') {
      return const EmailNotConfirmedFailure();
    }
    if (code == 'email_address_invalid' || code == 'validation_failed') {
      return const ContactInvalidFailure();
    }
    return UnknownFailure(e);
  }
}
