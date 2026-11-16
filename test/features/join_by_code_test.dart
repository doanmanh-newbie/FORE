import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/application/session_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/shift/application/shift_controller.dart';
import 'package:fore/features/shop/domain/shop_repository.dart';
import 'package:fore/features/shop/presentation/join_by_code_card.dart';
import 'package:provider/provider.dart';

import '../support/fake_auth_repository.dart';
import '../support/fake_shift_repository.dart';
import '../support/fake_shop_repository.dart';

void main() {
  testWidgets('nhập sai mã thì báo lỗi, nhập đúng mã thì vào quán',
      (tester) async {
    final shops = FakeShopRepository()..joinCode = 'K7M2QX';
    final auth = FakeAuthRepository()
      ..user = const AuthUser(id: 'u1', accountKind: AccountKind.staff);
    final session = SessionController(auth, minVisible: Duration.zero);
    addTearDown(session.dispose);

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ShopRepository>.value(value: shops),
        ChangeNotifierProvider<SessionController>.value(value: session),
        ChangeNotifierProvider(
            create: (_) => ShiftController(FakeShiftRepository())),
      ],
      child: MaterialApp(
        home: const Scaffold(
            body: SingleChildScrollView(child: JoinByCodeCard())),
        onGenerateRoute: (s) => MaterialPageRoute<void>(
            builder: (_) => Text('route:${s.name}')),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'zzz999');
    await tester.tap(find.text('Vào quán'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mã quán không đúng'), findsOneWidget);
    expect(shops.joinedCodes, isEmpty);

    await tester.enterText(find.byType(TextField), 'k7m2qx');
    expect(find.text('K7M2QX'), findsOneWidget); // tự viết hoa
    await tester.tap(find.text('Vào quán'));
    await tester.pumpAndSettle();
    expect(shops.joinedCodes, ['K7M2QX']);
    expect(find.textContaining('route:'), findsOneWidget); // đã chuyển màn
  });

  test('tài khoản đăng ký bằng số điện thoại hiện lại số, không hiện email nội bộ',
      () {
    const user = AuthUser(id: 'u1', email: 'p84978091479@phone.fore-staff.app');
    expect(user.contact, '0978 091 479');
  });
}
