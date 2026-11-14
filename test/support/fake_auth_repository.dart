import 'dart:async';

import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/auth/domain/auth_repository.dart';
import 'package:fore/features/auth/domain/staff_contact.dart';

/// Bản giả của [AuthRepository] cho test: không cần mạng, không cần Supabase.
/// Đặt `failure` để mô phỏng lỗi ở mọi lệnh gọi.
class FakeAuthRepository implements AuthRepository {
  AuthUser? user;
  Profile? profile;
  SessionContext? sessionContext;
  String? rememberedShopId;
  AppFailure? failure;
  bool staffDeviceTrustValid = true;

  /// Lỗi riêng cho đăng xuất (ví dụ mất mạng lúc đăng xuất).
  AppFailure? signOutFailure;
  Duration delay = Duration.zero;

  final registered = <String>{};
  int signUpCalls = 0;
  int signOutCalls = 0;
  int fetchSessionContextCalls = 0;

  /// Mô phỏng phản hồi chậm/nhanh khác nhau theo tài khoản (để dựng race).
  final contextByUser = <String, SessionContext>{};
  final fetchDelayByUser = <String, Duration>{};

  @override
  AuthUser? get currentUser => user;

  final _userIds = StreamController<String?>.broadcast();

  @override
  Stream<String?> get userIdChanges => _userIds.stream;

  /// Mô phỏng phiên Auth đổi từ nơi khác (tab khác).
  void emitUserId(String? id) => _userIds.add(id);

  @override
  Future<AuthUser> signIn({
    required String email,
    required String password,
  }) async {
    await _wait();
    if (failure != null) throw failure!;
    if (!registered.contains(email) || password != 'matkhau123') {
      throw const InvalidCredentialsFailure();
    }
    return user = AuthUser(
      id: 'u1',
      email: email,
      accountKind: AccountKind.owner,
    );
  }

  @override
  Future<bool> signUp({
    required String fullName,
    required String email,
    required String password,
    required AccountKind accountKind,
  }) async {
    signUpCalls++;
    await _wait();
    if (failure != null) throw failure!;
    if (registered.contains(email)) throw const EmailAlreadyRegisteredFailure();
    registered.add(email);
    return false;
  }

  /// Tài khoản nhân viên đã tạo, theo `StaffContact.value`.
  final staffAccounts = <String>{};
  int staffOtpRequestCount = 0;
  int staffOtpVerifyCount = 0;
  bool? lastStaffOtpCreateUser;
  String? lastStaffOtpFullName;
  String? lastStaffOtpContact;
  String? lastStaffOtpBirthDate;

  @override
  Future<void> requestStaffOtp(
    StaffContact contact, {
    required bool createUser,
    String? fullName,
    DateTime? birthDate,
  }) async {
    staffOtpRequestCount++;
    lastStaffOtpCreateUser = createUser;
    lastStaffOtpFullName = fullName;
    lastStaffOtpContact = contact.value;
    lastStaffOtpBirthDate = birthDate == null
        ? null
        : '${birthDate.year.toString().padLeft(4, '0')}-'
            '${birthDate.month.toString().padLeft(2, '0')}-'
            '${birthDate.day.toString().padLeft(2, '0')}';
    await _wait();
    if (failure != null) throw failure!;
    if (createUser && staffAccounts.contains(contact.value)) {
      throw const StaffAlreadyExistsFailure();
    }
    if (createUser) staffAccounts.add(contact.value);
  }

  @override
  Future<AuthUser> verifyStaffOtp(StaffContact contact, String token) async {
    staffOtpVerifyCount++;
    await _wait();
    if (failure != null) throw failure!;
    if (token != '123456' || !staffAccounts.contains(contact.value)) {
      throw const InvalidOtpFailure();
    }
    return user = AuthUser(
      id: 'staff-${contact.value}',
      email: contact.email ?? '',
      phone: contact.phone?.substring(1) ?? '',
      displayName: lastStaffOtpFullName ?? '',
      birthDate: lastStaffOtpBirthDate ?? '',
      accountKind: AccountKind.staff,
    );
  }

  @override
  Future<bool> validateStaffDeviceTrust() async => staffDeviceTrustValid;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (signOutFailure != null) throw signOutFailure!;
    user = null;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (failure != null) throw failure!;
  }

  @override
  Future<Profile?> fetchProfile() async {
    await _wait();
    if (failure != null) throw failure!;
    return profile;
  }

  @override
  Future<SessionContext> fetchSessionContext({String? preferredShopId}) async {
    fetchSessionContextCalls++;
    final byUser = contextByUser[user?.id];
    if (byUser != null) {
      await Future<void>.delayed(fetchDelayByUser[user?.id] ?? Duration.zero);
      return byUser;
    }
    await _wait();
    if (failure != null) throw failure!;
    if (sessionContext != null) return sessionContext!;
    final currentProfile = profile;
    if (currentProfile == null || !currentProfile.active) {
      return SessionContext(
        accountKind: user?.accountKind ?? AccountKind.staff,
        shops: const [],
        pendingInviteCount: 0,
      );
    }
    return SessionContext(
      accountKind: user?.accountKind ?? AccountKind.staff,
      shops: [
        SessionShop(
          shopId:
              currentProfile.shopId.isEmpty ? 'shop-1' : currentProfile.shopId,
          shopName: currentProfile.shopName,
          staffId: currentProfile.staffId,
          fullName: currentProfile.fullName,
          role: currentProfile.role,
          active: currentProfile.active,
          hasPin: currentProfile.hasPin,
          isCurrent: true,
        ),
      ],
      pendingInviteCount: 0,
    );
  }

  @override
  Future<void> selectShop(String shopId) async {
    if (failure != null) throw failure!;
    rememberedShopId = shopId;
  }

  @override
  Future<String?> lastActiveShopId() async => rememberedShopId;

  @override
  Future<void> rememberShop(String shopId) async => rememberedShopId = shopId;

  Future<void> _wait() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
  }
}
