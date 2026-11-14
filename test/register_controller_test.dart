import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/application/register_controller.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  late RegisterController controller;

  setUp(() {
    repo = FakeAuthRepository();
    controller = RegisterController(repo);
  });

  Future<void> submit({
    String name = 'Nguyễn An',
    String email = 'An@Quan.vn',
    String password = 'matkhau123',
    String confirm = 'matkhau123',
  }) =>
      controller.submit(
        fullName: name,
        email: email,
        password: password,
        confirm: confirm,
      );

  test('thiếu thông tin: báo lỗi từng ô và không gọi server', () async {
    await submit(name: '', email: 'sai', password: '123', confirm: '456');
    expect(controller.nameError, 'Nhập họ tên.');
    expect(controller.emailError, 'Email chưa đúng định dạng.');
    expect(controller.passwordError, 'Mật khẩu cần ít nhất 8 ký tự.');
    expect(controller.confirmError, 'Hai mật khẩu chưa giống nhau.');
    expect(repo.signUpCalls, 0);
    expect(controller.status, RegisterStatus.editing);
  });

  test('thành công: chuẩn hóa email về chữ thường', () async {
    await submit();
    expect(controller.status, RegisterStatus.success);
    expect(controller.registeredEmail, 'an@quan.vn');
    expect(repo.registered, contains('an@quan.vn'));
  });

  test('email đã đăng ký: lỗi gắn vào ô email, ở lại màn nhập', () async {
    repo.registered.add('an@quan.vn');
    await submit();
    expect(controller.emailError, 'Email này đã được đăng ký.');
    expect(controller.status, RegisterStatus.editing);
  });

  test('mất mạng: lỗi chung, không gắn vào ô nào', () async {
    repo.failure = const NoNetworkFailure();
    await submit();
    expect(controller.formError,
        'Không có mạng. Kiểm tra kết nối rồi thử lại.');
    expect(controller.emailError, isNull);
    expect(controller.status, RegisterStatus.editing);
  });

  test('sửa lỗi rồi gửi lại thì xóa lỗi cũ', () async {
    await submit(name: '');
    expect(controller.nameError, isNotNull);
    await submit();
    expect(controller.nameError, isNull);
    expect(controller.status, RegisterStatus.success);
  });
}
