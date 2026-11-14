import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/shop/domain/shop_models.dart';
import 'package:fore/features/shop/domain/shop_repository.dart';

/// Bản giả của [ShopRepository] cho test.
class FakeShopRepository implements ShopRepository {
  List<ShopMembership> shops = [];
  List<Invite> invites = [];
  List<TeamMember> members = [];
  List<PendingInvite> pending = [];
  AppFailure? failure;
  String? selectedShopId;
  String? createdShopName;
  String? createdOwnerName;
  final acceptedInviteIds = <String>[];
  final declinedInviteIds = <String>[];
  int inviteStaffCalls = 0;
  int myInvitesCalls = 0;
  int teamCalls = 0;

  @override
  Future<void> createShop(
      {required String shopName, required String ownerName}) async {
    if (failure != null) throw failure!;
    createdShopName = shopName;
    createdOwnerName = ownerName;
  }

  @override
  Future<List<ShopMembership>> myShops() async {
    if (failure != null) throw failure!;
    return shops;
  }

  @override
  Future<void> selectShop(String shopId) async {
    if (failure != null) throw failure!;
    selectedShopId = shopId;
  }

  @override
  Future<List<Invite>> myInvites() async {
    myInvitesCalls++;
    if (failure != null) throw failure!;
    return invites;
  }

  @override
  Future<void> acceptInvite(String inviteId) async {
    if (failure != null) throw failure!;
    acceptedInviteIds.add(inviteId);
    invites = invites.where((i) => i.id != inviteId).toList();
  }

  @override
  Future<void> declineInvite(String inviteId) async {
    if (failure != null) throw failure!;
    declinedInviteIds.add(inviteId);
    invites = invites.where((i) => i.id != inviteId).toList();
  }

  @override
  Future<List<TeamMember>> team() async {
    teamCalls++;
    if (failure != null) throw failure!;
    return members;
  }

  @override
  Future<List<PendingInvite>> inviteHistory() async {
    if (failure != null) throw failure!;
    return pending;
  }

  @override
  Future<void> inviteStaff({
    String? phone,
    required String fullName,
    String? email,
  }) async {
    if (failure != null) throw failure!;
    inviteStaffCalls++;
  }

  @override
  Future<void> cancelInvite(String inviteId) async {}
}
