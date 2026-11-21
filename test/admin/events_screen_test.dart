import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/data/fake_admin_repositories.dart';
import 'package:fore/admin/presentation/events_screen.dart';
import 'package:fore/core/design/empty_state.dart';
import 'package:fore/core/design/error_state.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/errors/app_failure.dart';

import 'admin_test_helpers.dart';

void main() {
  group('AdminEventsScreen', () {
    testWidgets('shows loading state, charts, table and updates range on preset tap',
        (tester) async {
      final repo = FakeAdminEventsRepository(
        delay: const Duration(milliseconds: 80),
      );

      await pumpAdminScreen(tester, AdminEventsScreen(repository: repo));
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Biểu đồ lượt sự kiện theo ngày'), findsOneWidget);
      expect(find.text('bill_paid'), findsWidgets);

      await tester.tap(find.byKey(const Key('events_preset_30')));
      await tester.pumpAndSettle();
      expect(repo.lastTo!.difference(repo.lastFrom!).inDays, 30);
    });

    testWidgets('shows empty state when no events match range', (tester) async {
      final repo = FakeAdminEventsRepository(items: const []);

      await pumpAdminScreen(tester, AdminEventsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Không có sự kiện trong khoảng ngày này'), findsOneWidget);
    });

    testWidgets('shows error state on DATE_RANGE_INVALID and recovers on retry',
        (tester) async {
      final repo = FakeAdminEventsRepository(
        failure: const DatabaseFailure('DATE_RANGE_INVALID'),
      );

      await pumpAdminScreen(tester, AdminEventsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('366 ngày'), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Biểu đồ lượt sự kiện theo ngày'), findsOneWidget);
    });
  });
}
