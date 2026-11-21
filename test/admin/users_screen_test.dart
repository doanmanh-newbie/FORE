import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/data/fake_admin_repositories.dart';
import 'package:fore/admin/domain/admin_models.dart';
import 'package:fore/admin/presentation/users_screen.dart';
import 'package:fore/core/design/empty_state.dart';
import 'package:fore/core/design/error_state.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/errors/app_failure.dart';

import 'admin_test_helpers.dart';

void main() {
  group('AdminUsersScreen', () {
    testWidgets('shows loading state, pagination, search and inspect IP callback',
        (tester) async {
      final repo = FakeAdminUsersRepository(
        delay: const Duration(milliseconds: 80),
      );
      AdminUser? inspected;

      await pumpAdminScreen(
        tester,
        AdminUsersScreen(
          repository: repo,
          pageSize: 2,
          onInspectLogins: (user) => inspected = user,
        ),
      );
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Lộc Quản Trị'), findsOneWidget);
      expect(find.text('Nguyễn Minh Hùng'), findsOneWidget);
      expect(find.text('Trần Thị Lan'), findsNothing);

      // Chuyển sang trang 2
      await tester.tap(find.byKey(const Key('users_next_page')));
      await tester.pumpAndSettle();
      expect(repo.lastOffset, 2);
      expect(find.text('Trần Thị Lan'), findsOneWidget);

      // Tìm theo email
      await tester.enterText(
        find.byKey(const Key('users_search_field')),
        'lan.tran',
      );
      await tester.tap(find.byKey(const Key('users_search_submit')));
      await tester.pumpAndSettle();
      expect(repo.lastSearch, 'lan.tran');
      expect(repo.lastOffset, 0);
      expect(find.text('Trần Thị Lan'), findsOneWidget);

      // Nhấn Xem IP
      await tester.tap(
        find.byKey(
          const Key('inspect_logins_aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2'),
        ),
      );
      expect(inspected?.email, 'lan.tran@fore.vn');
    });

    testWidgets('shows empty state when no users exist', (tester) async {
      final repo = FakeAdminUsersRepository(items: const []);

      await pumpAdminScreen(tester, AdminUsersScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Chưa có người dùng nào'), findsOneWidget);
    });

    testWidgets('shows error state and retries successfully', (tester) async {
      final repo = FakeAdminUsersRepository(
        failure: const NoNetworkFailure(),
      );

      await pumpAdminScreen(tester, AdminUsersScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('Không có mạng'), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Lộc Quản Trị'), findsOneWidget);
    });
  });
}
