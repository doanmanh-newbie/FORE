import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/theme/app_colors.dart';
import 'package:fore/core/widgets/status_chip.dart';

void main() {
  testWidgets('mỗi trạng thái có chữ và màu ngữ nghĩa riêng', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Wrap(
            children: [
              StatusChip(label: 'Ổn', severity: StatusSeverity.healthy),
              StatusChip(
                label: 'Dưới ngưỡng',
                severity: StatusSeverity.attention,
              ),
              StatusChip(label: 'Lệch lớn', severity: StatusSeverity.critical),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Ổn'), findsOneWidget);
    expect(find.text('Dưới ngưỡng'), findsOneWidget);
    expect(find.text('Lệch lớn'), findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded))
          .color,
      AppColors.statusOk,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.warning_amber_rounded)).color,
      AppColors.statusWatch,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.error_outline_rounded)).color,
      AppColors.statusOff,
    );
  });
}
