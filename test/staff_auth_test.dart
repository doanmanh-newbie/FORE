import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/auth/application/staff_login_controller.dart';
import 'package:fore/features/auth/application/staff_register_controller.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:fore/features/auth/domain/staff_contact.dart';

import 'support/fake_auth_repository.dart';

void main() {
  group('employee OTP login', () {
    late FakeAuthRepository repo;

    setUp(() => repo = FakeAuthRepository());

    test('dispose khi yêu cầu mã đang chạy thì không ném lỗi', () async {
      repo.delay = const Duration(milliseconds: 20);
      final controller = StaffLoginController(repo, resendDelay: Duration.zero);

      final pending = controller.submit('0901234567');
      controller.dispose();

      await expectLater(pending, completes);
    });

    test('requests a code without creating an account, then verifies it', () async {
      repo.staffAccounts.add('+84901234567');
      final controller = StaffLoginController(repo, resendDelay: Duration.zero);

      expect(await controller.submit('0901 234 567'), isTrue);
      expect(controller.otpRequested, isTrue);
      expect(repo.staffOtpRequestCount, 1);
      expect(repo.lastStaffOtpCreateUser, isFalse);
      expect(repo.user, isNull);

      expect(await controller.verifyOtp('123456'), isTrue);
      expect(repo.staffOtpVerifyCount, 1);
      expect(repo.user?.accountKind, AccountKind.staff);
    });

    test('invalid contact sends no code', () async {
      final controller = StaffLoginController(repo, resendDelay: Duration.zero);
      expect(await controller.submit('12'), isFalse);
      expect(repo.staffOtpRequestCount, 0);
      expect(controller.contactError, isNotNull);
    });

    test('invalid OTP keeps challenge active and shows a retryable error', () async {
      repo.staffAccounts.add('lan@example.com');
      final controller = StaffLoginController(repo, resendDelay: Duration.zero);
      controller.setKind(ContactKind.email);
      await controller.submit('lan@example.com');
      repo.failure = const InvalidOtpFailure();

      expect(await controller.verifyOtp('000000'), isFalse);
      expect(controller.otpRequested, isTrue);
      expect(controller.otpError, isNotNull);
      expect(repo.user, isNull);
    });

    test('resend requests another code for the same contact', () async {
      final controller = StaffLoginController(repo, resendDelay: Duration.zero);
      controller.setKind(ContactKind.email);
      await controller.submit('lan@example.com');
      await controller.resendOtp();

      expect(repo.staffOtpRequestCount, 2);
      expect(repo.lastStaffOtpCreateUser, isFalse);
    });
  });

  group('employee OTP registration', () {
    late FakeAuthRepository repo;

    setUp(() => repo = FakeAuthRepository());

    test('validates profile fields before requesting a code', () async {
      final controller = StaffRegisterController(repo);
      final ok = await controller.submit(
        contactText: '0901234567',
        fullName: ' ',
        birthDate: null,
      );
      expect(ok, isFalse);
      expect(controller.nameError, isNotNull);
      expect(controller.birthDateError, isNotNull);
      expect(repo.staffOtpRequestCount, 0);
    });

    test('requests account-creating OTP with profile metadata and verifies',
        () async {
      final controller = StaffRegisterController(repo);
      controller.setKind(ContactKind.email);
      expect(
        await controller.submit(
          contactText: 'lan@example.com',
          fullName: 'Lan',
          birthDate: DateTime(2001, 5, 20),
        ),
        isTrue,
      );
      expect(controller.otpRequested, isTrue);
      expect(repo.lastStaffOtpCreateUser, isTrue);
      expect(repo.lastStaffOtpFullName, 'Lan');
      expect(repo.user, isNull);

      expect(await controller.verifyOtp('123456'), isTrue);
      expect(repo.user?.displayName, 'Lan');
      expect(repo.user?.birthDate, '2001-05-20');
    });

    test('an Auth error does not complete registration', () async {
      repo.failure = const OtpSendFailure();
      final controller = StaffRegisterController(repo);
      controller.setKind(ContactKind.email);

      expect(
        await controller.submit(
          contactText: 'lan@example.com',
          fullName: 'Lan',
          birthDate: DateTime(2001, 5, 20),
        ),
        isFalse,
      );
      expect(controller.otpRequested, isFalse);
      expect(controller.formError, isNotNull);
    });
  });
}
