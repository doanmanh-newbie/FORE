import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/data/fake_admin_repositories.dart';
import 'package:fore/admin/presentation/shops_screen.dart';
import 'package:fore/core/design/empty_state.dart';
import 'package:fore/core/design/error_state.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/errors/app_failure.dart';

import 'admin_test_helpers.dart';

void main() {
  group('AdminShopsScreen', () {
    testWidgets('renders loading skeletons then shop list and supports local filtering',
        (tester) async {
      final repo = FakeAdminShopsRepository(
        delay: const Duration(milliseconds: 100),
      );

      await pumpAdminScreen(tester, AdminShopsScreen(repository: repo));
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Cà Phê Sân Vườn Fore'), findsOneWidget);
      expect(find.text('Trà Sữa Mây Chiều'), findsOneWidget);

      await tester.enterText(find.byKey(const Key('shops_filter_field')), 'MAYCH2');
      await tester.pump();
      expect(find.text('Trà Sữa Mây Chiều'), findsOneWidget);
      expect(find.text('Cà Phê Sân Vườn Fore'), findsNothing);
    });

    testWidgets('renders empty state when there are no shops', (tester) async {
      final repo = FakeAdminShopsRepository(items: const []);

      await pumpAdminScreen(tester, AdminShopsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Chưa có quán nào'), findsOneWidget);
    });

    testWidgets('renders error state and recovers on retry', (tester) async {
      final repo = FakeAdminShopsRepository(
        failure: const DatabaseFailure('FORBIDDEN'),
      );

      await pumpAdminScreen(tester, AdminShopsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('super-admin'), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();

      expect(find.text('Cà Phê Sân Vườn Fore'), findsOneWidget);
    });
  });
}
