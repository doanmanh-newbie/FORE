import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/application/staff_login_controller.dart';
import 'package:fore/features/auth/application/staff_register_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/auth/domain/staff_contact.dart';

import 'support/fake_auth_repository.dart';

void main() {
  late FakeAuthRepository repo;
  setUp(() => repo = FakeAuthRepository());

  group('đăng nhập nhân viên bằng mật khẩu', () {
    test('đúng số và mật khẩu thì đăng nhập, sai mật khẩu thì báo lỗi chung',
        () async {
      repo.staffAccounts['+84901234567'] = 'matkhau123';
      final c = StaffLoginController(repo);

      expect(await c.submit('0901 234 567', 'sai-mat-khau'), isFalse);
      expect(c.formError, isNotNull);
      expect(repo.user, isNull);

      expect(await c.submit('0901 234 567', 'matkhau123'), isTrue);
      expect(repo.user?.accountKind, AccountKind.staff);
    });

    test('thiếu mật khẩu hoặc số sai thì không gọi máy chủ', () async {
      final c = StaffLoginController(repo);
      expect(await c.submit('12', ''), isFalse);
      expect(c.contactError, isNotNull);
      expect(c.passwordError, isNotNull);
    });

    test('dispose khi đang đăng nhập thì không ném lỗi', () async {
      repo.delay = const Duration(milliseconds: 20);
      final c = StaffLoginController(repo);
      final pending = c.submit('0901234567', 'matkhau123');
      c.dispose();
      await expectLater(pending, completes);
    });
  });

  group('đăng ký nhân viên bằng mật khẩu', () {
    test('kiểm tra hồ sơ và mật khẩu trước khi gọi máy chủ', () async {
      final c = StaffRegisterController(repo);
      final ok = await c.submit(
        contactText: '0901234567',
        fullName: ' ',
        birthDate: null,
        password: 'ngan',
        confirm: 'khac',
      );
      expect(ok, isFalse);
      expect(c.nameError, isNotNull);
      expect(c.birthDateError, isNotNull);
      expect(c.passwordError, isNotNull);
      expect(c.confirmError, isNotNull);
      expect(repo.staffSignUpCalls, 0);
    });

    test('tạo tài khoản là đăng nhập luôn, kèm tên và ngày sinh', () async {
      final c = StaffRegisterController(repo)..setKind(ContactKind.email);
      expect(
        await c.submit(
          contactText: 'lan@example.com',
          fullName: 'Lan',
          birthDate: DateTime(2001, 5, 20),
          password: 'matkhau123',
          confirm: 'matkhau123',
        ),
        isTrue,
      );
      expect(repo.user?.displayName, 'Lan');
      expect(repo.user?.birthDate, '2001-05-20');
    });

    test('số đã có tài khoản thì báo ở ô liên hệ', () async {
      repo.staffAccounts['+84901234567'] = 'matkhau123';
      final c = StaffRegisterController(repo);
      expect(
        await c.submit(
          contactText: '0901234567',
          fullName: 'Lan',
          birthDate: DateTime(2001, 5, 20),
          password: 'matkhau123',
          confirm: 'matkhau123',
        ),
        isFalse,
      );
      expect(c.contactError, isNotNull);
    });
  });

  test('số điện thoại đăng nhập bằng email giả mà máy chủ nhận ra', () {
    final phone =
        StaffContact.tryParse(ContactKind.phone, '0901 234 567').contact!;
    expect(phone.loginEmail, 'p84901234567@phone.fore-staff.app');
    final email =
        StaffContact.tryParse(ContactKind.email, 'Lan@Example.com').contact!;
    expect(email.loginEmail, 'lan@example.com');
  });
}
