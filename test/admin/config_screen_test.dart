import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/data/fake_admin_repositories.dart';
import 'package:fore/admin/presentation/config_screen.dart';
import 'package:fore/core/design/empty_state.dart';
import 'package:fore/core/design/error_state.dart';
import 'package:fore/core/design/skeleton_box.dart';
import 'package:fore/core/errors/app_failure.dart';

import 'admin_test_helpers.dart';

void main() {
  group('AdminConfigScreen', () {
    testWidgets('shows loading state, toggles maintenance preset and saves custom JSON key',
        (tester) async {
      final repo = FakeAdminConfigRepository(
        delay: const Duration(milliseconds: 80),
      );

      await pumpAdminScreen(tester, AdminConfigScreen(repository: repo));
      expect(find.byType(SkeletonBox), findsWidgets);

      await tester.pumpAndSettle();
      expect(find.text('Hoạt động bình thường'), findsOneWidget);

      // Bật preset bảo trì
      await tester.tap(find.byKey(const Key('preset_maintenance_switch')));
      await tester.pumpAndSettle();
      expect(find.text('Đang bảo trì'), findsOneWidget);
      expect(
        repo.items.firstWhere((e) => e.key == 'maintenance').value,
        isTrue,
      );

      // Mở dialog thêm khóa mới và kiểm tra validate JSON sai trước khi lưu hợp lệ
      await tester.tap(find.byKey(const Key('config_add_button')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('config_key_field')),
        'feature.promo',
      );
      await tester.enterText(
        find.byKey(const Key('config_value_field')),
        '{bad json',
      );
      await tester.tap(find.byKey(const Key('config_dialog_save')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('config_dialog_error')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('config_value_field')),
        '{"enabled": true}',
      );
      await tester.tap(find.byKey(const Key('config_dialog_save')));
      await tester.pumpAndSettle();

      expect(find.text('feature.promo'), findsOneWidget);
      expect(
        repo.items.firstWhere((e) => e.key == 'feature.promo').value,
        {'enabled': true},
      );
    });

    testWidgets('shows empty state list when app_config has no entries',
        (tester) async {
      final repo = FakeAdminConfigRepository(items: const []);

      await pumpAdminScreen(tester, AdminConfigScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Chưa có khóa cấu hình nào'), findsOneWidget);
    });

    testWidgets('shows error state and retries', (tester) async {
      final repo = FakeAdminConfigRepository(
        failure: const DatabaseFailure('FORBIDDEN'),
      );

      await pumpAdminScreen(tester, AdminConfigScreen(repository: repo));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorState), findsOneWidget);
      expect(find.textContaining('super-admin'), findsOneWidget);

      repo.failure = null;
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Thiết lập nhanh'), findsOneWidget);
    });
  });
}
