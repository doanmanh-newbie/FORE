import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fore/features/owner/menu/menu_home_view.dart';
import 'package:fore/features/owner/menu/menu_repository.dart';
import 'package:fore/features/owner/menu/menu_store.dart';

import '../../../support/fake_menu_repository.dart';

Future<MenuStore> _pump(WidgetTester tester, FakeMenuRepository repo) async {
  final store = MenuStore(repo, shopKey: 'a', cache: MemoryMenuCache());
  await tester.pumpWidget(
    ChangeNotifierProvider<MenuStore>.value(
      value: store,
      child: const MaterialApp(
        home: Scaffold(body: MenuHomeView(header: SizedBox(height: 8))),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return store;
}

void main() {
  testWidgets('hiện danh sách món và nút quản lý danh mục', (tester) async {
    await _pump(tester, FakeMenuRepository());
    expect(find.text('QA-Trà'), findsOneWidget);
    expect(find.text('Trà đào'), findsOneWidget);
    expect(find.text('Quản lý danh mục'), findsOneWidget);
  });

  testWidgets('tìm không dấu thu hẹp danh sách', (tester) async {
    await _pump(tester, FakeMenuRepository());
    await tester.enterText(find.byType(TextField).first, 'tra dao');
    await tester.pumpAndSettle();
    expect(find.text('Trà đào'), findsOneWidget);
    expect(find.text('QA-Trà'), findsNothing);
  });

  testWidgets('lỗi tải mà chưa có dữ liệu thì hiện cách thử lại', (tester) async {
    final repo = FakeMenuRepository(overviewError: StateError('hỏng'));
    await _pump(tester, repo);
    expect(find.text('QA-Trà'), findsNothing);
    expect(find.textContaining('Thử lại'), findsWidgets);
  });
}
