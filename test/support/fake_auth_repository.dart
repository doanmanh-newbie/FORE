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

  /// Đăng nhập Google/Facebook: `true` để mô phỏng người dùng tự hủy.
  bool socialCancelled = false;
  final socialCalls = <SocialProvider>[];

  @override
  Future<AuthUser?> signInWithSocial(SocialProvider provider) async {
    await _wait();
    socialCalls.add(provider);
    if (failure != null) throw failure!;
    if (socialCancelled) return null;
    return user = const AuthUser(
      id: 'u1',
      email: 'chu@gmail.com',
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

  /// Tài khoản nhân viên đã tạo (`StaffContact.value` -> mật khẩu).
  final staffAccounts = <String, String>{};
  int staffSignUpCalls = 0;
  String? lastStaffFullName;
  String? lastStaffBirthDate;

  @override
  Future<AuthUser> signInStaff(StaffContact contact, String password) async {
    await _wait();
    if (failure != null) throw failure!;
    if (staffAccounts[contact.value] != password) {
      throw const InvalidCredentialsFailure();
    }
    return user = AuthUser(
      id: 'staff-${contact.value}',
      email: contact.email ?? '',
      phone: contact.phone?.substring(1) ?? '',
      accountKind: AccountKind.staff,
    );
  }

  @override
  Future<AuthUser> signUpStaff(
    StaffContact contact,
    String password, {
    required String fullName,
    required DateTime birthDate,
  }) async {
    staffSignUpCalls++;
    lastStaffFullName = fullName;
    lastStaffBirthDate = '${birthDate.year.toString().padLeft(4, '0')}-'
        '${birthDate.month.toString().padLeft(2, '0')}-'
        '${birthDate.day.toString().padLeft(2, '0')}';
    await _wait();
    if (failure != null) throw failure!;
    if (staffAccounts.containsKey(contact.value)) {
      throw const StaffAlreadyExistsFailure();
    }
    staffAccounts[contact.value] = password;
    return user = AuthUser(
      id: 'staff-${contact.value}',
      email: contact.email ?? '',
      phone: contact.phone?.substring(1) ?? '',
      displayName: fullName,
      birthDate: lastStaffBirthDate!,
      accountKind: AccountKind.staff,
    );
  }

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

  final _recoveries = StreamController<void>.broadcast();
  String? updatedPassword;

  /// Mô phỏng app được mở từ link đặt lại mật khẩu.
  void emitPasswordRecovery() => _recoveries.add(null);

  @override
  Stream<void> get passwordRecoveries => _recoveries.stream;

  @override
  Future<void> updatePassword(String newPassword) async {
    await _wait();
    if (failure != null) throw failure!;
    updatedPassword = newPassword;
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
