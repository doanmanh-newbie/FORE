import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/shop/application/auto_join.dart';
import 'package:fore/features/shop/domain/shop_models.dart';

import '../support/fake_shop_repository.dart';

void main() {
  late FakeShopRepository repository;

  setUp(() => repository = FakeShopRepository());

  test('đúng một lời mời thì nhận luôn', () async {
    repository.invites = [_invite('invite-1')];

    expect(await autoJoinSingleInvite(repository), isTrue);
    expect(repository.acceptedInviteIds, ['invite-1']);
  });

  test('không có lời mời thì không làm gì', () async {
    expect(await autoJoinSingleInvite(repository), isFalse);
    expect(repository.acceptedInviteIds, isEmpty);
  });

  test('từ hai lời mời trở lên thì để nhân viên tự chọn', () async {
    repository.invites = [_invite('invite-1'), _invite('invite-2')];

    expect(await autoJoinSingleInvite(repository), isFalse);
    expect(repository.acceptedInviteIds, isEmpty);
  });

  test('lỗi máy chủ không làm hỏng đăng nhập', () async {
    repository.invites = [_invite('invite-1')];
    repository.failure = const NoNetworkFailure();

    expect(await autoJoinSingleInvite(repository), isFalse);
    expect(repository.acceptedInviteIds, isEmpty);
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
