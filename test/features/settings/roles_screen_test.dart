import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/settings/domain/settings_models.dart';
import 'package:fore/features/settings/domain/settings_repository.dart';
import 'package:fore/features/settings/presentation/roles_screen.dart';
import 'package:provider/provider.dart';

class _SlowRolesRepo implements SettingsRepository {
  final roleConfigGate = Completer<RoleConfig>();
  int branchesCalls = 0;

  @override
  Future<RoleConfig> roleConfig(JobRole role) => roleConfigGate.future;

  @override
  Future<List<Branch>> branches() async {
    branchesCalls++;
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('rời màn hình khi đang tải quyền thì không gọi tiếp danh sách quán',
      (tester) async {
    final repo = _SlowRolesRepo();
    await tester.pumpWidget(MultiProvider(
      providers: [Provider<SettingsRepository>.value(value: repo)],
      child: const MaterialApp(home: RolesScreen()),
    ));

    // Rời màn hình trong lúc roleConfig còn đang chờ.
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    repo.roleConfigGate.complete(const RoleConfig(
      role: JobRole.manager,
      members: [],
      permissions: {},
    ));
    await tester.pump();

    expect(repo.branchesCalls, 0);
  });
}
