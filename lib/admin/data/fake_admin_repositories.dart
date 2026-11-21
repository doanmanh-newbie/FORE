import '../../core/errors/app_failure.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';

/// Các bản fake dùng cho phát triển độc lập, chế độ demo web và widget test.
/// Hỗ trợ tùy chỉnh độ trễ, trạng thái rỗng và lỗi để test đủ mọi nhánh UI.

class FakeAdminAuthRepository implements AdminAuthRepository {
  FakeAdminAuthRepository({
    this.initialSession,
    this.delay = Duration.zero,
    this.signInFailure,
    this.adminEmail = 'admin@fore.vn',
    this.adminPassword = 'admin1234',
    this.nonAdminEmail = 'user@fore.vn',
    this.nonAdminPassword = 'user1234',
  });

  AdminIdentity? initialSession;
  final Duration delay;
  AppFailure? signInFailure;
  final String adminEmail;
  final String adminPassword;
  final String nonAdminEmail;
  final String nonAdminPassword;

  AdminIdentity? _current;
  int signOutCount = 0;

  @override
  Future<AdminIdentity?> restoreSession() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    _current ??= initialSession;
    return _current;
  }

  @override
  Future<AdminIdentity> signIn({
    required String email,
    required String password,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (signInFailure != null) throw signInFailure!;

    final normalized = email.trim().toLowerCase();
    if (normalized == nonAdminEmail.toLowerCase() &&
        password == nonAdminPassword) {
      signOutCount++;
      _current = null;
      throw const DatabaseFailure('FORBIDDEN');
    }
    if (normalized == adminEmail.toLowerCase() && password == adminPassword) {
      final identity = AdminIdentity(
        userId: '00000000-0000-0000-0000-000000000001',
        email: normalized,
      );
      _current = identity;
      return identity;
    }
    throw const InvalidCredentialsFailure();
  }

  @override
  Future<void> signOut() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    signOutCount++;
    _current = null;
    initialSession = null;
  }
}

class FakeAdminShopsRepository implements AdminShopsRepository {
  FakeAdminShopsRepository({
    List<AdminShop>? items,
    this.delay = Duration.zero,
    this.failure,
  }) : items = items ?? _defaultShops();

  List<AdminShop> items;
  final Duration delay;
  AppFailure? failure;
  int callCount = 0;

  @override
  Future<List<AdminShop>> listShops() async {
    callCount++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    return List.unmodifiable(items);
  }

  static List<AdminShop> _defaultShops() => [
        AdminShop(
          id: '11111111-1111-1111-1111-111111111111',
          name: 'Cà Phê Sân Vườn Fore',
          code: 'FORE01',
          createdAt: DateTime.utc(2026, 9, 10, 2, 30),
          ownerUserId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
          ownerName: 'Nguyễn Minh Hùng',
          ownerEmail: 'hung.chuquan@fore.vn',
          memberCount: 7,
          lastBillAt: DateTime.utc(2026, 11, 21, 7, 15),
        ),
        AdminShop(
          id: '22222222-2222-2222-2222-222222222222',
          name: 'Trà Sữa Mây Chiều',
          code: 'MAYCH2',
          createdAt: DateTime.utc(2026, 10, 4, 8, 0),
          ownerUserId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
          ownerName: 'Trần Thị Lan',
          ownerEmail: 'lan.tran@fore.vn',
          memberCount: 4,
          lastBillAt: DateTime.utc(2026, 11, 20, 14, 45),
        ),
        AdminShop(
          id: '33333333-3333-3333-3333-333333333333',
          name: 'Tiệm Bánh Bơ Sữa',
          code: 'BOSUA3',
          createdAt: DateTime.utc(2026, 11, 15, 5, 10),
          ownerUserId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa3',
          ownerName: 'Lê Hoàng Nam',
          ownerEmail: 'nam.le@fore.vn',
          memberCount: 1,
          lastBillAt: null,
        ),
      ];
}

class FakeAdminUsersRepository implements AdminUsersRepository {
  FakeAdminUsersRepository({
    List<AdminUser>? items,
    this.delay = Duration.zero,
    this.failure,
  }) : items = items ?? _defaultUsers();

  List<AdminUser> items;
  final Duration delay;
  AppFailure? failure;
  String? lastSearch;
  int? lastLimit;
  int? lastOffset;

  @override
  Future<AdminUserPage> listUsers({
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    lastSearch = search;
    lastLimit = limit;
    lastOffset = offset;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;

    final q = search?.trim().toLowerCase() ?? '';
    final filtered = q.isEmpty
        ? items
        : items.where((u) {
            final email = (u.email ?? '').toLowerCase();
            final phone = (u.phone ?? '').toLowerCase();
            final name = (u.fullName ?? '').toLowerCase();
            return email.contains(q) || phone.contains(q) || name.contains(q);
          }).toList();

    final safeOffset = offset.clamp(0, filtered.length);
    final end = (safeOffset + limit).clamp(0, filtered.length);
    final slice = filtered.sublist(safeOffset, end);

    return AdminUserPage(
      items: [
        for (final u in slice)
          AdminUser(
            userId: u.userId,
            email: u.email,
            phone: u.phone,
            fullName: u.fullName,
            shopCount: u.shopCount,
            shopNames: u.shopNames,
            lastLoginAt: u.lastLoginAt,
            isPlatformAdmin: u.isPlatformAdmin,
            totalCount: filtered.length,
          ),
      ],
      totalCount: filtered.length,
      limit: limit,
      offset: safeOffset,
    );
  }

  static List<AdminUser> _defaultUsers() => [
        AdminUser(
          userId: '00000000-0000-0000-0000-000000000001',
          email: 'admin@fore.vn',
          phone: '0901000001',
          fullName: 'Lộc Quản Trị',
          shopCount: 0,
          shopNames: null,
          lastLoginAt: DateTime.utc(2026, 11, 21, 8, 30),
          isPlatformAdmin: true,
          totalCount: 4,
        ),
        AdminUser(
          userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
          email: 'hung.chuquan@fore.vn',
          phone: '0902111222',
          fullName: 'Nguyễn Minh Hùng',
          shopCount: 1,
          shopNames: 'Cà Phê Sân Vườn Fore',
          lastLoginAt: DateTime.utc(2026, 11, 21, 7, 10),
          isPlatformAdmin: false,
          totalCount: 4,
        ),
        AdminUser(
          userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
          email: 'lan.tran@fore.vn',
          phone: '0903222333',
          fullName: 'Trần Thị Lan',
          shopCount: 2,
          shopNames: 'Cà Phê Sân Vườn Fore, Trà Sữa Mây Chiều',
          lastLoginAt: DateTime.utc(2026, 11, 20, 12, 0),
          isPlatformAdmin: false,
          totalCount: 4,
        ),
        const AdminUser(
          userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa4',
          email: 'nhanvien.kho@fore.vn',
          phone: '0904333444',
          fullName: 'Phạm Quốc Bảo',
          shopCount: 1,
          shopNames: 'Trà Sữa Mây Chiều',
          lastLoginAt: null,
          isPlatformAdmin: false,
          totalCount: 4,
        ),
      ];
}

class FakeAdminErrorsRepository implements AdminErrorsRepository {
  FakeAdminErrorsRepository({
    List<AdminErrorLog>? items,
    this.delay = Duration.zero,
    this.failure,
  }) : items = items ?? _defaultErrors();

  List<AdminErrorLog> items;
  final Duration delay;
  AppFailure? failure;
  DateTime? lastBefore;

  @override
  Future<List<AdminErrorLog>> listErrors({
    int limit = 50,
    DateTime? before,
  }) async {
    lastBefore = before;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;

    final sorted = [...items]
      ..sort((a, b) {
        final cmp = b.createdAt.compareTo(a.createdAt);
        return cmp != 0 ? cmp : b.id.compareTo(a.id);
      });
    final filtered = before == null
        ? sorted
        : sorted.where((e) => e.createdAt.isBefore(before)).toList();
    return filtered.take(limit).toList();
  }

  static List<AdminErrorLog> _defaultErrors() => [
        AdminErrorLog(
          id: 102,
          createdAt: DateTime.utc(2026, 11, 21, 7, 45),
          userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
          userEmail: 'hung.chuquan@fore.vn',
          shopId: '11111111-1111-1111-1111-111111111111',
          shopName: 'Cà Phê Sân Vườn Fore',
          appVersion: '0.1.0+1',
          platform: 'android',
          message: 'StateError: Bad state: Không thể thanh toán khi bill rỗng',
          stack: '#0      BillController.pay (package:fore/features/sales/bill_controller.dart:142:7)\n'
              '#1      _BillScreenState._onPay (package:fore/features/sales/bill_screen.dart:88:19)\n'
              '#2      _InkResponseState.handleTap (package:flutter/src/material/ink_well.dart:1170:21)',
          context: const {
            'screen': 'bill_screen',
            'bill_id': 'b-9081',
            'network': 'wifi',
          },
        ),
        AdminErrorLog(
          id: 101,
          createdAt: DateTime.utc(2026, 11, 20, 15, 20),
          userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
          userEmail: 'lan.tran@fore.vn',
          shopId: '22222222-2222-2222-2222-222222222222',
          shopName: 'Trà Sữa Mây Chiều',
          appVersion: '0.1.0+1',
          platform: 'ios',
          message: 'TimeoutException after 0:00:15.000000: Kết nối Supabase quá hạn',
          stack: '#0      SupabaseRpcClient.call (package:fore/core/data/rpc_client.dart:26:7)\n'
              '#1      ShiftController.openShift (package:fore/features/shift/shift_controller.dart:54:12)',
          context: const {
            'rpc': 'open_shift',
            'retry': 1,
          },
        ),
      ];
}

class FakeAdminEventsRepository implements AdminEventsRepository {
  FakeAdminEventsRepository({
    List<AdminEventCount>? items,
    this.delay = Duration.zero,
    this.failure,
  }) : items = items ?? _defaultEvents();

  List<AdminEventCount> items;
  final Duration delay;
  AppFailure? failure;
  DateTime? lastFrom;
  DateTime? lastTo;

  @override
  Future<List<AdminEventCount>> fetchEventCounts({
    required DateTime from,
    required DateTime to,
  }) async {
    lastFrom = from;
    lastTo = to;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    if (!from.isBefore(to) || to.difference(from).inDays > 366) {
      throw const DatabaseFailure('DATE_RANGE_INVALID');
    }

    final fromDate = DateTime(from.year, from.month, from.day);
    final toDate = DateTime(to.year, to.month, to.day);
    return items
        .where((e) {
          final d = DateTime(e.day.year, e.day.month, e.day.day);
          return !d.isBefore(fromDate) && !d.isAfter(toDate);
        })
        .toList()
      ..sort((a, b) {
        final cmp = a.day.compareTo(b.day);
        return cmp != 0 ? cmp : a.name.compareTo(b.name);
      });
  }

  static List<AdminEventCount> _defaultEvents() {
    final now = DateTime.now();
    DateTime dayAgo(int n) {
      final d = now.subtract(Duration(days: n));
      return DateTime(d.year, d.month, d.day);
    }

    return [
      AdminEventCount(day: dayAgo(3), name: 'shift_open', eventCount: 6, userCount: 4),
      AdminEventCount(day: dayAgo(3), name: 'bill_paid', eventCount: 48, userCount: 5),
      AdminEventCount(day: dayAgo(3), name: 'shift_close', eventCount: 6, userCount: 4),
      AdminEventCount(day: dayAgo(2), name: 'shift_open', eventCount: 8, userCount: 5),
      AdminEventCount(day: dayAgo(2), name: 'bill_paid', eventCount: 64, userCount: 6),
      AdminEventCount(day: dayAgo(2), name: 'shift_close', eventCount: 7, userCount: 5),
      AdminEventCount(day: dayAgo(1), name: 'shift_open', eventCount: 7, userCount: 5),
      AdminEventCount(day: dayAgo(1), name: 'bill_paid', eventCount: 71, userCount: 6),
      AdminEventCount(day: dayAgo(1), name: 'shift_close', eventCount: 7, userCount: 5),
      AdminEventCount(day: dayAgo(0), name: 'shift_open', eventCount: 5, userCount: 4),
      AdminEventCount(day: dayAgo(0), name: 'bill_paid', eventCount: 39, userCount: 4),
    ];
  }
}

class FakeAdminLoginsRepository implements AdminLoginsRepository {
  FakeAdminLoginsRepository({
    List<AdminLoginIp>? items,
    this.delay = Duration.zero,
    this.failure,
  }) : items = items ?? _defaultLogins();

  List<AdminLoginIp> items;
  final Duration delay;
  AppFailure? failure;
  String? lastUserId;
  int? lastLimit;

  @override
  Future<List<AdminLoginIp>> listLogins({
    String? userId,
    int limit = 100,
  }) async {
    lastUserId = userId;
    lastLimit = limit;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;

    final target = userId?.trim();
    final filtered = (target == null || target.isEmpty)
        ? items
        : items.where((e) => e.userId == target).toList();
    return filtered.take(limit).toList();
  }

  static List<AdminLoginIp> _defaultLogins() => [
        AdminLoginIp(
          id: 503,
          userId: '00000000-0000-0000-0000-000000000001',
          userEmail: 'admin@fore.vn',
          ip: '113.161.74.22',
          userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/130.0',
          createdAt: DateTime.utc(2026, 11, 21, 8, 30),
        ),
        AdminLoginIp(
          id: 502,
          userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
          userEmail: 'hung.chuquan@fore.vn',
          ip: '14.161.33.105',
          userAgent: 'Dart/3.6 (dart:io) Android 14',
          createdAt: DateTime.utc(2026, 11, 21, 7, 10),
        ),
        AdminLoginIp(
          id: 501,
          userId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2',
          userEmail: 'lan.tran@fore.vn',
          ip: '171.244.19.88',
          userAgent: 'Dart/3.6 (dart:io) iOS 18.1',
          createdAt: DateTime.utc(2026, 11, 20, 12, 0),
        ),
      ];
}

class FakeAdminConfigRepository implements AdminConfigRepository {
  FakeAdminConfigRepository({
    List<AdminConfigEntry>? items,
    this.delay = Duration.zero,
    this.failure,
    this.saveFailure,
  }) : items = items ?? _defaultConfigs();

  static final _keyPattern = RegExp(r'^[a-z0-9_.]{1,64}$');

  List<AdminConfigEntry> items;
  final Duration delay;
  AppFailure? failure;
  AppFailure? saveFailure;

  @override
  Future<List<AdminConfigEntry>> listConfigs() async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (failure != null) throw failure!;
    return List.unmodifiable(
      [...items]..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  @override
  Future<AdminConfigEntry> setConfig({
    required String key,
    required dynamic value,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (saveFailure != null) throw saveFailure!;
    final normalized = key.trim().toLowerCase();
    if (!_keyPattern.hasMatch(normalized) || value == null) {
      throw const DatabaseFailure('INPUT_INVALID');
    }
    final entry = AdminConfigEntry(
      key: normalized,
      value: value,
      updatedAt: DateTime.now().toUtc(),
      updatedBy: '00000000-0000-0000-0000-000000000001',
    );
    items = [
      ...items.where((e) => e.key != normalized),
      entry,
    ]..sort((a, b) => a.key.compareTo(b.key));
    return entry;
  }

  static List<AdminConfigEntry> _defaultConfigs() => [
        AdminConfigEntry(
          key: 'maintenance',
          value: false,
          updatedAt: DateTime.utc(2026, 11, 20, 10, 0),
          updatedBy: '00000000-0000-0000-0000-000000000001',
        ),
        AdminConfigEntry(
          key: 'maintenance_message',
          value: 'Hệ thống đang bảo trì định kỳ, vui lòng quay lại sau 15 phút.',
          updatedAt: DateTime.utc(2026, 11, 20, 10, 0),
          updatedBy: '00000000-0000-0000-0000-000000000001',
        ),
        AdminConfigEntry(
          key: 'min_version',
          value: '0.1.0',
          updatedAt: DateTime.utc(2026, 11, 18, 4, 30),
          updatedBy: '00000000-0000-0000-0000-000000000001',
        ),
      ];
}
