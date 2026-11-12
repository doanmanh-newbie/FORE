import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/settings/domain/settings_models.dart';
import 'package:fore/features/settings/domain/settings_repository.dart';
import 'package:fore/features/settings/presentation/team_screens.dart';
import 'package:provider/provider.dart';

import '../../support/fake_settings_repository.dart';

Widget _app(FakeSettingsRepository repo) => MultiProvider(
      providers: [Provider<SettingsRepository>.value(value: repo)],
      child: const MaterialApp(home: TeamHubScreen()),
    );

void main() {
  testWidgets('chủ quán thấy người đang làm, nút mời và các tab', (tester) async {
    await tester.pumpWidget(_app(FakeSettingsRepository()));
    await tester.pumpAndSettle();

    expect(find.text('Nhân sự'), findsOneWidget);
    expect(find.textContaining('Minh Anh'), findsOneWidget);
    expect(find.text('Ngọc Lan'), findsOneWidget);
    expect(find.text('Thu Hà'), findsNothing, reason: 'đã nghỉ nằm ở tab khác');
    expect(find.text('Đang giữ ca'), findsOneWidget);
    expect(find.text('Mời nhân viên'), findsOneWidget);
    expect(find.text('Đang làm · 3'), findsOneWidget);
    expect(find.text('Lời mời · 2'), findsOneWidget);
    expect(find.text('Đã nghỉ · 1'), findsOneWidget);
  });

  testWidgets('tab Lời mời: hết hạn có nhãn, chủ gia hạn và hủy được', (tester) async {
    final repo = FakeSettingsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lời mời · 2'));
    await tester.pumpAndSettle();

    expect(find.text('Bảo Trân'), findsOneWidget);
    expect(find.text('Hết hạn'), findsOneWidget);
    await tester.tap(find.text('Gửi lại').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy lời mời').first);
    await tester.pumpAndSettle();
    expect(repo.calls, ['resend:i1', 'cancel:i1']);
  });

  testWidgets('quản lý có quyền thành viên: thấy danh sách nhưng không có nút mời', (tester) async {
    const mgr = MyPermissions(
        isOwner: false,
        jobRole: JobRole.manager,
        granted: {'members.manage'});
    await tester.pumpWidget(_app(FakeSettingsRepository(me: mgr)));
    await tester.pumpAndSettle();
    expect(find.text('Ngọc Lan'), findsOneWidget);
    expect(find.text('Mời nhân viên'), findsNothing);
  });

  testWidgets('thu hồi cần tick xác nhận, rồi gọi đúng thành viên', (tester) async {
    final repo = FakeSettingsRepository();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngọc Lan'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Thu hồi quyền truy cập'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Thu hồi quyền truy cập'));
    await tester.pumpAndSettle();

    // Chưa tick: nút Thu hồi bị khóa
    await tester.tap(find.text('Thu hồi'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thu hồi'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['revoke:a']);
  });
}
