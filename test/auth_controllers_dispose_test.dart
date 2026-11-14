import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/application/forgot_password_controller.dart';
import 'package:fore/features/auth/application/login_controller.dart';
import 'package:fore/features/auth/application/register_controller.dart';
import 'package:fore/features/auth/application/staff_register_controller.dart';

import 'support/fake_auth_repository.dart';

/// Đóng màn hình khi request đang chạy không được làm app ném lỗi.
void main() {
  late FakeAuthRepository repo;

  setUp(() {
    repo = FakeAuthRepository()..delay = const Duration(milliseconds: 20);
  });

  test('LoginController', () async {
    final c = LoginController(repo);
    final pending = c.submit(email: 'an@quan.vn', password: 'matkhau123');
    c.dispose();
    await expectLater(pending, completes);
  });

  test('RegisterController', () async {
    final c = RegisterController(repo);
    final pending = c.submit(
      fullName: 'Nguyễn An',
      email: 'an@quan.vn',
      password: 'matkhau123',
      confirm: 'matkhau123',
    );
    c.dispose();
    await expectLater(pending, completes);
  });

  test('ForgotPasswordController', () async {
    final c = ForgotPasswordController(repo);
    final pending = c.submit('an@quan.vn');
    c.dispose();
    await expectLater(pending, completes);
  });

  test('StaffRegisterController', () async {
    final c = StaffRegisterController(repo, resendDelay: Duration.zero);
    final pending = c.submit(
      contactText: '0901234567',
      fullName: 'Lan',
      birthDate: DateTime(2001, 5, 20),
    );
    c.dispose();
    await expectLater(pending, completes);
  });
}
