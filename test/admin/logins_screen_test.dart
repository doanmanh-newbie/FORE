import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/data/fake_admin_repositories.dart';
import 'package:fore/admin/presentation/logins_screen.dart';
import 'package:fore/core/design/empty_state.dart';
import 'package:fore/core/design/error_state.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/errors/app_failure.dart';

import 'admin_test_helpers.dart';

void main() {
  group('AdminLoginsScreen', () {
    testWidgets('shows loading state, login IP table and filters by user_id',
        (tester) async {
      final repo = FakeAdminLoginsRepository(
        delay: const Duration(milliseconds: 80),
      );

      await pumpAdminScreen(tester, AdminLoginsScreen(repository: repo));
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('113.161.74.22'), findsOneWidget);
      expect(find.text('14.161.33.105'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('logins_user_filter_field')),
        'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1',
      );
      await tester.tap(find.byKey(const Key('logins_filter_submit')));
      await tester.pumpAndSettle();

      expect(repo.lastUserId, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1');
      expect(find.text('14.161.33.105'), findsOneWidget);
      expect(find.text('113.161.74.22'), findsNothing);

      await tester.tap(find.byKey(const Key('logins_filter_clear')));
      await tester.pumpAndSettle();
      expect(repo.lastUserId, isNull);
      expect(find.text('113.161.74.22'), findsOneWidget);
    });

    testWidgets('shows empty state when no logins exist', (tester) async {
      final repo = FakeAdminLoginsRepository(items: const []);

      await pumpAdminScreen(tester, AdminLoginsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Chưa có lịch sử IP đăng nhập'), findsOneWidget);
    });

    testWidgets('shows error state and retries', (tester) async {
      final repo = FakeAdminLoginsRepository(
        failure: const NoNetworkFailure(),
      );

      await pumpAdminScreen(tester, AdminLoginsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('Không có mạng'), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('113.161.74.22'), findsOneWidget);
    });
  });
}
