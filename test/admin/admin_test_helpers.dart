import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/admin/admin_theme.dart';
import 'package:fore/core/design/palette_sync.dart';

/// Bọc widget màn hình Admin bằng [AdminTheme] + [AppPaletteSync] và viewport rộng
/// tương tự trình duyệt desktop để test không bị overflow giả trên màn mặc định 800x600.
Future<void> pumpAdminScreen(
  WidgetTester tester,
  Widget child, {
  Size surfaceSize = const Size(1280, 900),
}) async {
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      theme: AdminTheme.light(),
      builder: (context, inner) => AppPaletteSync(child: inner!),
      home: Scaffold(body: child),
    ),
  );
}
