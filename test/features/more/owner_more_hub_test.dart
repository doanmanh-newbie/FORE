import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/more/more_prefs.dart';
import 'package:fore/features/more/owner_more_hub.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<MoreEntry> _entries(List<String> taps, {bool locked = false}) => [
      MoreEntry(
        id: 'team',
        group: 'Đội ngũ',
        icon: Icons.groups_outlined,
        title: 'Nhân sự',
        subtitle: 'Thêm và quản lý nhân viên',
        keywords: const ['nhan vien'],
        onTap: () => taps.add('team'),
      ),
      MoreEntry(
        id: 'suppliers',
        group: 'Kho và nhập hàng',
        icon: Icons.local_shipping_outlined,
        title: 'Nhà cung cấp',
        subtitle: 'Người giao hàng, lịch giao',
        onTap: () => taps.add('suppliers'),
      ),
      MoreEntry(
        id: 'waste',
        group: 'Vận hành hằng ngày',
        icon: Icons.warning_amber_rounded,
        title: 'Ghi hao hụt',
        subtitle: locked ? 'Mở ca để dùng' : 'Đổ bỏ, làm sai',
        onTap: locked ? null : () => taps.add('waste'),
      ),
    ];

Widget _app(List<MoreEntry> entries, MorePrefs prefs,
        {VoidCallback? onSignOut, VoidCallback? onSwitch}) =>
    MaterialApp(
      home: Scaffold(
        body: OwnerMoreHub(
          personName: 'Minh Anh',
          shopName: 'Fore Nguyễn Du',
          entries: entries,
          prefs: prefs,
          onSwitchShop: onSwitch ?? () {},
          onSignOut: onSignOut ?? () {},
        ),
      ),
    );

void main() {
  testWidgets('hiện hồ sơ, quán, các nhóm và mục ghim mặc định', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(_app(_entries(taps), MorePrefs.memory()));

    expect(find.text('Chăm quán, từ những điều nhỏ'), findsOneWidget);
    expect(find.text('Minh Anh'), findsOneWidget);
    expect(find.text('Fore Nguyễn Du'), findsOneWidget);
    expect(find.text('Đã ghim'), findsOneWidget);
    for (final g in ['Đội ngũ', 'Kho và nhập hàng', 'Vận hành hằng ngày']) {
      await tester.scrollUntilVisible(find.text(g), 240,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(g), findsOneWidget);
    }
  });

  testWidgets('tìm không dấu vẫn ra kết quả có dấu và ẩn phần còn lại', (tester) async {
    await tester.pumpWidget(_app(_entries([]), MorePrefs.memory()));
    await tester.enterText(find.byType(TextField), 'nhan su');
    await tester.pump();

    expect(find.text('Nhân sự'), findsOneWidget);
    expect(find.text('Nhà cung cấp'), findsNothing);
    expect(find.text('Đã ghim'), findsNothing, reason: 'đang tìm thì ẩn mục ghim');

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump();
    expect(find.textContaining('Không có chức năng nào khớp'), findsOneWidget);
  });

  testWidgets('mục khóa không bấm được và nói rõ lý do', (tester) async {
    final taps = <String>[];
    await tester.pumpWidget(
        _app(_entries(taps, locked: true), MorePrefs.memory(pinned: const [])));
    await tester.scrollUntilVisible(find.text('Ghi hao hụt'), 240,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Mở ca để dùng'), findsOneWidget);
    await tester.tap(find.text('Ghi hao hụt'));
    await tester.pump();
    expect(taps, isEmpty);
    await tester.tap(find.text('Nhân sự'));
    await tester.pump();
    expect(taps, ['team']);
  });

  testWidgets('chế độ gọn ẩn dòng mô tả của mục bình thường', (tester) async {
    await tester.pumpWidget(
        _app(_entries([]), MorePrefs.memory(compact: true, pinned: const [])));
    expect(find.text('Thêm và quản lý nhân viên'), findsNothing);
    expect(find.text('Nhân sự'), findsOneWidget);
  });

  testWidgets('đổi quán và đăng xuất gọi đúng hàm', (tester) async {
    var switched = 0, out = 0;
    await tester.pumpWidget(_app(_entries([]), MorePrefs.memory(),
        onSwitch: () => switched++, onSignOut: () => out++));
    await tester.tap(find.text('Đổi quán'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Đăng xuất'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Đăng xuất'));
    await tester.pump();
    expect([switched, out], [1, 1]);
  });

  group('MorePrefs', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('ghim tối đa 3 mục và nhớ sau khi mở lại', () async {
      final p = await MorePrefs.load();
      expect(p.pinned, MorePrefs.defaultPinned);
      expect(await p.togglePin('team'), isTrue, reason: 'bỏ ghim mục đang ghim');
      expect(await p.togglePin('a'), isTrue);
      expect(p.pinned.length, 3);
      expect(await p.togglePin('b'), isFalse, reason: 'đủ 3 mục');
      await p.setCompact(true);

      final again = await MorePrefs.load();
      expect(again.pinned, p.pinned);
      expect(again.compact, isTrue);
    });
  });

  test('foldVietnamese bỏ dấu và hạ chữ thường', () {
    expect(foldVietnamese('Đối soát · Ca làm'), 'doi soat · ca lam');
    expect(foldVietnamese('Nhân Sự'), 'nhan su');
  });
}
