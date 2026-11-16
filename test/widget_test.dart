// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:fore/app/app.dart';
import 'package:fore/features/auth/domain/auth_repository.dart';
import 'package:fore/features/shift/domain/shift_repository.dart';
import 'package:fore/features/shop/domain/shop_repository.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_shift_repository.dart';
import 'support/fake_shop_repository.dart';

void main() {
  testWidgets('Fore app boots to its splash route', (WidgetTester tester) async {
    final AuthRepository auth = FakeAuthRepository();
    final ShiftRepository shift = FakeShiftRepository();
    final ShopRepository shop = FakeShopRepository();
    await tester.pumpWidget(ForeApp(
      authRepository: auth,
      shiftRepository: shift,
      shopRepository: shop,
    ));
    expect(find.byType(ForeApp), findsOneWidget);
    // Chờ kiểm tra phiên và hoạt ảnh mở đầu kết thúc để không bỏ timer chạy nền.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
