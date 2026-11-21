import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/data/fake_admin_repositories.dart';
import 'package:fore/admin/presentation/errors_screen.dart';
import 'package:fore/core/design/empty_state.dart';
import 'package:fore/core/design/error_state.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/errors/app_failure.dart';

import 'admin_test_helpers.dart';

void main() {
  group('AdminErrorsScreen', () {
    testWidgets('shows loading state, error rows, stack dialog and load more pagination',
        (tester) async {
      final repo = FakeAdminErrorsRepository(
        delay: const Duration(milliseconds: 80),
      );

      await pumpAdminScreen(
        tester,
        AdminErrorsScreen(repository: repo, pageSize: 1),
      );
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error_row_102')), findsOneWidget);
      expect(find.byKey(const Key('error_row_101')), findsNothing);

      // Mở dialog chi tiết stack trace
      await tester.tap(find.byKey(const Key('error_row_102')));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết lỗi #102'), findsOneWidget);
      expect(find.byKey(const Key('error_detail_stack')), findsOneWidget);
      expect(find.textContaining('BillController.pay'), findsOneWidget);

      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      // Tải thêm lỗi cũ hơn (p_before)
      await tester.tap(find.byKey(const Key('errors_load_more')));
      await tester.pumpAndSettle();
      expect(repo.lastBefore, isNotNull);
      expect(find.byKey(const Key('error_row_101')), findsOneWidget);
    });

    testWidgets('shows empty state when no errors exist', (tester) async {
      final repo = FakeAdminErrorsRepository(items: const []);

      await pumpAdminScreen(tester, AdminErrorsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Chưa ghi nhận lỗi nào'), findsOneWidget);
    });

    testWidgets('shows error state and retries', (tester) async {
      final repo = FakeAdminErrorsRepository(
        failure: const MissingRpcFailure('admin_list_errors'),
      );

      await pumpAdminScreen(tester, AdminErrorsScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('09_admin.sql'), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('error_row_102')), findsOneWidget);
    });
  });
}
