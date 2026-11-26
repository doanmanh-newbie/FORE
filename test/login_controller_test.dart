import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/application/login_controller.dart';
import 'package:fore/features/auth/domain/auth_repository.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late LoginController controller;

  setUp(() {
    repo = FakeAuthRepository()..registered.add('an@quan.vn');
    controller = LoginController(repo);
  });

  test('ô trống: báo lỗi, không gọi server', () async {
    final ok = await controller.submit(email: '', password: '');
    expect(ok, isFalse);
    expect(controller.emailError, 'Nhập email.');
    expect(controller.passwordError, 'Nhập mật khẩu.');
  });

  test('sai mật khẩu: lỗi chung phía trên nút', () async {
    final ok =
        await controller.submit(email: 'an@quan.vn', password: 'saimatkhau');
    expect(ok, isFalse);
    expect(controller.formError, 'Email hoặc mật khẩu chưa đúng.');
    expect(controller.loading, isFalse);
  });

  test('đúng: trả về true, email được chuẩn hóa', () async {
    final ok =
        await controller.submit(email: ' AN@Quan.vn ', password: 'matkhau123');
    expect(ok, isTrue);
    expect(controller.formError, isNull);
    expect(repo.user?.email, 'an@quan.vn');
  });

  test('Google: tự hủy thì không báo lỗi, lỗi cấu hình thì có câu dễ hiểu', () async {
    repo.socialCancelled = true;
    expect(await controller.signInWithSocial(SocialProvider.google), isFalse);
    expect(controller.formError, isNull);
    expect(controller.loading, isFalse);

    repo
      ..socialCancelled = false
      ..failure = const SocialSignInFailure();
    expect(await controller.signInWithSocial(SocialProvider.google), isFalse);
    expect(controller.formError, contains('Chưa đăng nhập được'));

    repo.failure = null;
    expect(await controller.signInWithSocial(SocialProvider.facebook), isTrue);
    expect(controller.socialLoading, isNull);
  });
}
