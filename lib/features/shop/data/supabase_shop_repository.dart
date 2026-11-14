import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/rpc_errors.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/errors/network_errors.dart';
import '../domain/shop_models.dart';
import '../domain/shop_repository.dart';

/// Cài đặt [ShopRepository] bằng các hàm database ở `008_staff_setup.sql`.
class SupabaseShopRepository implements ShopRepository {
  SupabaseShopRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> createShop({
    required String shopName,
    required String ownerName,
  }) =>
      _guard(() async {
        await _client.rpc('create_shop', params: {
          'p_shop_name': shopName,
          'p_owner_name': ownerName,
        });
      });

  @override
  Future<List<ShopMembership>> myShops() => _guard(() async {
        final rows = await _client.rpc('my_shops') as List<dynamic>;
        return [
          for (final r in rows)
            ShopMembership.fromMap(r as Map<String, dynamic>),
        ];
      });

  @override
  Future<void> selectShop(String shopId) => _guard(() async {
        await _client.rpc('select_shop', params: {'p_shop': shopId});
      });

  @override
  Future<List<Invite>> myInvites() => _guard(() async {
        final rows = await _client.rpc('my_invites') as List<dynamic>;
        return [
          for (final r in rows) Invite.fromMap(r as Map<String, dynamic>)
        ];
      });

  @override
  Future<void> acceptInvite(String inviteId) => _guard(() async {
        await _expireInvites();
        await _client.rpc('accept_invite', params: {'p_invite': inviteId});
      });

  @override
  Future<void> declineInvite(String inviteId) => _guard(() async {
        await _expireInvites();
        await _client.rpc('decline_invite', params: {'p_invite': inviteId});
      });

  @override
  Future<List<TeamMember>> team() => _guard(() async {
        await _expireInvites();
        final rows = await _client.rpc('shop_team') as List<dynamic>;
        return [
          for (final r in rows) TeamMember.fromMap(r as Map<String, dynamic>),
        ];
      });

  @override
  Future<List<PendingInvite>> inviteHistory() => _guard(() async {
        await _expireInvites();
        final rows = await _client
            .from('shop_invites')
            .select(
                'id, phone, email, full_name, created_at, status, responded_at')
            .order('created_at', ascending: false) as List<dynamic>;
        return [
          for (final r in rows.where((row) => row['status'] != 'cancelled'))
            PendingInvite.fromMap(r as Map<String, dynamic>),
        ];
      });

  Future<void> _expireInvites() async {
    try {
      await _client.rpc('expire_my_invites');
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST202') {
        throw const MissingRpcFailure('expire_my_invites');
      }
      rethrow;
    }
  }

  @override
  Future<void> inviteStaff({
    String? phone,
    required String fullName,
    String? email,
  }) =>
      _guard(() async {
        await _client.rpc('invite_staff', params: {
          'p_phone': phone,
          'p_full_name': fullName,
          'p_email': (email == null || email.trim().isEmpty) ? null : email,
        });
      });

  @override
  Future<void> cancelInvite(String inviteId) => _guard(() async {
        await _client.rpc('cancel_invite', params: {'p_invite': inviteId});
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on PostgrestException catch (e) {
      // Lỗi nghiệp vụ của database là mã chữ nằm trong `message`.
      final m = e.message;
      if (m.contains('PHONE_INVALID')) throw const InvalidPhoneFailure();
      if (m.contains('ALREADY_MEMBER')) throw const AlreadyMemberFailure();
      if (m.contains('ALREADY_INVITED')) throw const AlreadyInvitedFailure();
      if (m.contains('INVITE_NOT_FOUND') || m.contains('NOT_FOUND')) {
        throw const InviteNotFoundFailure();
      }
      if (m.contains('INVITE_EXPIRED')) throw const InviteExpiredFailure();
      if (m.contains('OWNER_ONLY') || m.contains('NOT_STAFF')) {
        throw const OwnerOnlyFailure();
      }
      // Các mã nghiệp vụ còn lại (CONTACT_REQUIRED, EMAIL_INVALID, NAME_REQUIRED...) có câu
      // tiếng Việt trong `databaseMessages`, không để rơi vào "Có lỗi xảy ra".
      final mapped = mapPostgrestError(message: m, code: e.code);
      if (mapped is DatabaseFailure) throw mapped;
      if (looksLikeNetworkError(e)) throw const NoNetworkFailure();
      debugPrint('Fore: lỗi database: ${e.code} ${e.message}');
      throw UnknownFailure(e);
    } catch (e) {
      if (looksLikeNetworkError(e)) throw const NoNetworkFailure();
      debugPrint('Fore: lỗi không rõ: $e');
      throw UnknownFailure(e);
    }
  }
}
