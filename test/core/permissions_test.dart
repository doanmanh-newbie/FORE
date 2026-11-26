import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/design/app_theme.dart';
import 'package:fore/core/permissions/app_permissions.dart';
import 'package:fore/core/permissions/permission_setup.dart';
import 'package:fore/features/settings/presentation/permissions_screen.dart';
import 'package:provider/provider.dart';

Widget _host(PermissionGateway gateway, Widget child) => Provider.value(
      value: gateway,
      child: MaterialApp(theme: AppTheme.light(), home: child),
    );

void main() {
  testWidgets('màn giải thích: "Cho phép" xin quyền, "Để sau" không xin',
      (tester) async {
    final gateway = MemoryPermissionGateway();
    PermissionAccess? result = PermissionAccess.unsupported;
    await tester.pumpWidget(_host(
      gateway,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                result = await askPermission(context, AppPermission.camera),
            child: const Text('mở'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text(AppPermission.camera.purpose), findsOneWidget);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(gateway.states[AppPermission.camera], isNull);

    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cho phép truy cập'));
    await tester.pumpAndSettle();
    expect(result, PermissionAccess.granted);
    expect(gateway.states[AppPermission.camera], PermissionAccess.granted);
  });

  testWidgets('quyền bị chặn: nút chính mở Cài đặt thay vì hỏi lại',
      (tester) async {
    final gateway = MemoryPermissionGateway(
        {AppPermission.location: PermissionAccess.blocked});
    await tester.pumpWidget(_host(
      gateway,
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => askPermission(context, AppPermission.location),
            child: const Text('mở'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('mở'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mở cài đặt'));
    await tester.pumpAndSettle();
    expect(gateway.settingsOpened, 1);
  });

  testWidgets('màn Quyền truy cập hiện trạng thái từng quyền và bật được',
      (tester) async {
    final gateway = MemoryPermissionGateway({
      AppPermission.notification: PermissionAccess.granted,
      AppPermission.photos: PermissionAccess.unsupported,
    });
    await tester.pumpWidget(_host(gateway, const PermissionsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Đã bật'), findsOneWidget);
    expect(find.text('Không áp dụng'), findsOneWidget);
    expect(find.text('Chưa bật'), findsNWidgets(2));

    await tester.tap(find.text('Bật').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cho phép truy cập'));
    await tester.pumpAndSettle();
    expect(gateway.states[AppPermission.camera], PermissionAccess.granted);
    expect(find.text('Đã bật'), findsNWidgets(2));
  });
}
