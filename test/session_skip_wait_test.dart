import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/application/session_controller.dart';

import 'support/fake_auth_repository.dart';

void main() {
  test('skipMinWait bỏ thời gian chờ tối thiểu (người dùng tắt hoạt ảnh)', () async {
    final c = SessionController(
      FakeAuthRepository(),
      minVisible: const Duration(milliseconds: 400),
      timeout: const Duration(seconds: 1),
    );
    final watch = Stopwatch()..start();
    await c.restore(skipMinWait: true);
    expect(watch.elapsedMilliseconds, lessThan(200));
    expect(c.state, isA<SessionSignedOut>());
  });

  test('mặc định vẫn chờ đủ minVisible', () async {
    final c = SessionController(
      FakeAuthRepository(),
      minVisible: const Duration(milliseconds: 120),
      timeout: const Duration(seconds: 1),
    );
    final watch = Stopwatch()..start();
    await c.restore();
    expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(110));
  });
}
