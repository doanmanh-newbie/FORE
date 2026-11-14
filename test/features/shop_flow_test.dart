import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/app/app_routes.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/shop/application/inbox_controller.dart';
import 'package:fore/features/shop/application/team_controller.dart';
import 'package:fore/features/shop/domain/shop_models.dart';
import 'package:fore/features/shop/domain/shop_repository.dart';
import 'package:fore/features/shop/presentation/team_screen.dart';
import 'package:fore/features/shop/presentation/invite_list.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_shop_repository.dart';

void main() {
  late FakeShopRepository repository;

  setUp(() => repository = FakeShopRepository());

  test('chủ tạo quán, tạo lỗi quyền được giữ lại cho UI xử lý', () async {
    await repository.createShop(shopName: 'Quán An', ownerName: 'An');
    expect(repository.createdShopName, 'Quán An');
    expect(repository.createdOwnerName, 'An');

    repository.failure = const OwnerOnlyFailure();
    await expectLater(
      repository.createShop(shopName: 'Quán khác', ownerName: 'An'),
      throwsA(isA<OwnerOnlyFailure>()),
    );
    expect(repository.createdShopName, 'Quán An');
  });

  test('chuyển quán chỉ cập nhật lựa chọn khi database chấp thuận', () async {
    await repository.selectShop('shop-2');
    expect(repository.selectedShopId, 'shop-2');

    repository.failure = const OwnerOnlyFailure();
    await expectLater(repository.selectShop('shop-forbidden'),
        throwsA(isA<OwnerOnlyFailure>()));
    expect(repository.selectedShopId, 'shop-2');
  });

  test('hộp thư nhận và từ chối lời mời, bỏ lời mời đã xử lý', () async {
    final first = _invite('invite-1');
    final second = _invite('invite-2');
    repository.invites = [first, second];
    final inbox = InboxController(repository);
    await inbox.load();

    expect(await inbox.accept(first), isNull);
    expect(repository.acceptedInviteIds, ['invite-1']);
    expect(inbox.invites.map((i) => i.id), ['invite-2']);

    expect(await inbox.decline(second), isNull);
    expect(repository.declinedInviteIds, ['invite-2']);
    expect(inbox.invites, isEmpty);
    inbox.dispose();
  });

  test('hộp thư đang mở tự tải lời mời mới theo chu kỳ', () async {
    final inbox = InboxController(repository);
    await inbox.load();
    expect(repository.myInvitesCalls, 1);

    inbox.startPolling(const Duration(milliseconds: 5));
    repository.invites = [_invite('new-invite')];
    await Future<void>.delayed(const Duration(milliseconds: 25));

    expect(repository.myInvitesCalls, greaterThan(1));
    expect(inbox.invites.map((invite) => invite.id), ['new-invite']);
    expect(inbox.newArrivals, 1);
    inbox.dispose();
  });

  testWidgets('route Hộp thư tự làm mới và hiện lời mời mới', (tester) async {
    await tester.pumpWidget(
      Provider<ShopRepository>.value(
        value: repository,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  AppRoutes.generate(
                    const RouteSettings(name: AppRoutes.inbox),
                  ),
                ),
                child: const Text('Mở Hộp thư'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Mở Hộp thư'));
    await tester.pumpAndSettle();
    expect(repository.myInvitesCalls, 1);

    repository.invites = [_invite('route-invite')];
    await tester.pump(const Duration(seconds: 15));
    await tester.pumpAndSettle();

    expect(repository.myInvitesCalls, greaterThan(1));
    expect(find.text('Quán An'), findsOneWidget);
  });

  testWidgets('hộp thư cho thử lại khi tải lỗi và hiện lời mời sau đó',
      (tester) async {
    repository.failure = const OwnerOnlyFailure();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => InboxController(repository)..load(),
        child: const MaterialApp(
          home: Scaffold(body: InviteListView()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);

    repository.failure = null;
    repository.invites = [_invite('retry-invite')];
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(find.text('Quán An'), findsOneWidget);
    expect(find.text('Chấp nhận và vào quán'), findsOneWidget);
  });

  test('lỗi quyền khi xử lý lời mời được báo và không xóa lời mời', () async {
    final invite = _invite('invite-1');
    repository.invites = [invite];
    final inbox = InboxController(repository);
    await inbox.load();
    repository.failure = const OwnerOnlyFailure();

    final message = await inbox.accept(invite);
    expect(message, isNotNull);
    expect(inbox.invites, [invite]);
    inbox.dispose();
  });

  test('mời nhân viên yêu cầu tên và ít nhất một kênh liên hệ', () async {
    final team = TeamController(repository);
    expect(await team.invite(fullName: ''), isFalse);
    expect(team.nameError, isNotNull);
    expect(team.formError, isNotNull);
    expect(repository.inviteStaffCalls, 0);

    expect(
      await team.invite(
        phone: '0901 234 567',
        email: 'AN@EXAMPLE.COM',
        fullName: ' An ',
      ),
      isTrue,
    );
    expect(repository.inviteStaffCalls, 1);
  });

  test('chủ xem lịch sử lời mời với trạng thái phản hồi', () async {
    repository.pending = [
      _pendingInvite('wait-1', status: 'pending'),
      _pendingInvite('accepted-1', status: 'accepted'),
      _pendingInvite('declined-1', status: 'declined'),
      _pendingInvite('expired-1', status: 'expired'),
    ];
    final team = TeamController(repository);
    await team.load();

    expect(team.inviteHistory, hasLength(4));
    expect(team.pending.map((invite) => invite.id), ['wait-1']);
    expect(
      team.inviteHistory.map((invite) => invite.statusLabel),
      ['Đang chờ', 'Đã tham gia', 'Đã từ chối', 'Đã hết hạn'],
    );
    team.dispose();
  });

  testWidgets('màn Nhân viên hiện trạng thái và chỉ cho hủy lời mời đang chờ',
      (tester) async {
    repository.pending = [
      _pendingInvite('wait-1', status: 'pending'),
      _pendingInvite('accepted-1', status: 'accepted'),
      _pendingInvite('declined-1', status: 'declined'),
      _pendingInvite('expired-1', status: 'expired'),
    ];
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TeamController(repository)..load(),
        child: const MaterialApp(home: TeamScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Đang chờ'), findsOneWidget);
    expect(find.text('Đã tham gia'), findsOneWidget);
    expect(find.text('Đã từ chối'), findsOneWidget);
    expect(find.text('Đã hết hạn'), findsOneWidget);
    expect(find.byTooltip('Hủy lời mời'), findsOneWidget);
  });

  testWidgets('màn Nhân viên có nút tải lại khi lỗi và thử lại được',
      (tester) async {
    repository.failure = const OwnerOnlyFailure();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TeamController(repository)..load(),
        child: const MaterialApp(home: TeamScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Thử lại'), findsOneWidget);
    final callsBeforeRetry = repository.teamCalls;

    repository.failure = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();

    expect(repository.teamCalls, callsBeforeRetry + 1);
    expect(find.text('Thử lại'), findsNothing);
    expect(find.text('THÀNH VIÊN'), findsOneWidget);
  });

  testWidgets('chủ quán gửi lời mời thành công từ màn Nhân viên',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuthRepository()
      ..user = const AuthUser(
        id: 'owner-1',
        email: 'owner@example.test',
        accountKind: AccountKind.owner,
      )
      ..profile = const Profile(
        staffId: 'owner-staff-1',
        fullName: 'Chủ quán',
        role: StaffRole.owner,
        hasPin: false,
        active: true,
        shopId: 'shop-1',
        shopName: 'Quán An',
      );
    final session = SessionController(auth, minVisible: Duration.zero);
    addTearDown(session.dispose);
    await session.restore(skipMinWait: true);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionController>.value(value: session),
          ChangeNotifierProvider(
              create: (_) => TeamController(repository)..load()),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const TeamScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Thêm nhân viên'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Điền số điện thoại, email hoặc cả hai.'),
      findsOneWidget,
    );
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), '0901 234 567');
    await tester.enterText(fields.at(2), 'Lan');
    await tester.tap(find.text('Gửi lời mời'));
    await tester.pumpAndSettle();

    expect(repository.inviteStaffCalls, 1);
    expect(find.textContaining('Đã gửi lời mời Lan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('hộp thư vừa màn 360x800 ở cỡ chữ $scale', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.invites = [
        Invite(
          id: 'long-invite',
          shopId: 'shop-1',
          shopName: 'Quán Trà Sữa Và Cà Phê Đặc Sản Nguyễn Huệ',
          invitedName: 'Nguyễn Thị Lan Anh',
          invitedByName: 'Trần Minh Tuấn',
          createdAt: DateTime.utc(2026, 10, 30),
        ),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => InboxController(repository)..load(),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: InviteListView()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Chấp nhận và vào quán'), findsOneWidget);
    });

    testWidgets('danh sách nhân viên vừa màn 360x800 ở cỡ chữ $scale',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      repository.members = [
        const TeamMember(
          staffId: 'staff-1',
          fullName: 'Nguyễn Thị Lan Anh Nhân viên ca sáng',
          isOwner: false,
          active: true,
          phone: '+84901234567',
          email: '',
        ),
      ];

      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => TeamController(repository)..load(),
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const TeamScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Nguyễn Thị Lan Anh Nhân viên ca sáng'), findsOneWidget);
    });
  }

  test('lỗi quyền khi mời nhân viên không giả thành công', () async {
    repository.failure = const OwnerOnlyFailure();
    final team = TeamController(repository);

    expect(
      await team.invite(phone: '0901 234 567', fullName: 'An'),
      isFalse,
    );
    expect(team.formError, contains('Phiên đăng nhập'));
    expect(repository.inviteStaffCalls, 0);
  });
}

Invite _invite(String id) => Invite(
      id: id,
      shopId: 'shop-1',
      shopName: 'Quán An',
      invitedName: 'Bình',
      invitedByName: 'An',
      createdAt: DateTime.utc(2026),
    );

PendingInvite _pendingInvite(String id, {required String status}) =>
    PendingInvite(
      id: id,
      phone: '84901234567',
      fullName: 'Lan',
      createdAt: DateTime.utc(2026, 10, 30),
      status: status,
    );
