import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/theme/app_colors.dart';
import 'package:fore/core/theme/app_text_styles.dart';
import 'package:fore/core/widgets/fore_header.dart';

void main() {
  testWidgets('header làm nổi bật tên quán và vẫn vừa màn hình hẹp',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ForeHeader(
            shopName: 'Quán Cà phê của Mạnh',
            subtitle: 'Chủ quán · Mạnh',
            onBack: _goBack,
            pill: ShiftPill(label: 'Ca của Minh Anh đang mở', active: true),
          ),
        ),
      ),
    );

    // Header sáng (bộ Navy): tên quán Inter đậm màu mực, lời chào theo tên người dùng,
    // trạng thái ca là một dòng dưới tên quán (không có banner).
    final shopName = tester.widget<Text>(find.text('Quán Cà phê của Mạnh'));
    expect(shopName.style?.fontFamily, AppFonts.body);
    expect(shopName.style?.fontWeight, FontWeight.w700);
    expect(shopName.style?.color, AppColors.textPrimary);
    expect(find.text('Xin chào, Mạnh'), findsOneWidget);
    expect(find.byTooltip('Về màn quản lý'), findsOneWidget);
    expect(find.text('Ca của Minh Anh đang mở'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _goBack() {}
