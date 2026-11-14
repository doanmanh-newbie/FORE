import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/data/staff_device_trust_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> backingStore;

  setUp(() {
    backingStore = {};
    FlutterSecureStoragePlatform.instance =
        TestFlutterSecureStoragePlatform(backingStore);
  });

  test('creates a random secret persisted separately for each user', () async {
    final store = StaffDeviceTrustStore(const FlutterSecureStorage());

    final first = await store.createSecret('user-1');
    final sameUser = await store.readSecret('user-1');
    final second = await store.createSecret('user-2');

    expect(first, sameUser);
    expect(second, isNot(first));
    expect(first.length, greaterThanOrEqualTo(40));
    expect(backingStore.values, containsAll([first, second]));
  });

  test('clear removes only the selected user secret', () async {
    final store = StaffDeviceTrustStore(const FlutterSecureStorage());
    final userOne = await store.createSecret('user-1');
    await store.createSecret('user-2');

    await store.clearSecret('user-1');

    expect(await store.readSecret('user-1'), isNull);
    expect(await store.readSecret('user-2'), isNotNull);
    expect(backingStore.values, isNot(contains(userOne)));
  });
}
