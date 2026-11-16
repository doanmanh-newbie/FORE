import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/shift/application/shift_controller.dart';
import 'package:fore/features/shift/domain/shift_models.dart';

import 'support/fake_shift_repository.dart';

void main() {
  late FakeShiftRepository repo;
  late ShiftController controller;

  setUp(() {
    repo = FakeShiftRepository();
    controller = ShiftController(repo);
  });

  group('phạm vi tài khoản/quán', () {
    CurrentShift shiftOf(String id) => CurrentShift(
          id: id,
          openedByName: 'An',
          openedAt: DateTime(2026, 10, 25, 8, 2),
        );

    test('đổi phạm vi thì quên ca của người/quán trước', () async {
      controller.bindScope('quan-a|an');
      repo.shift = shiftOf('s1');
      await controller.load();
      expect(controller.state, isA<ShiftOpen>());

      controller.bindScope('quan-b|binh');

      expect(controller.state, isA<ShiftLoading>());
    });

    test('đăng xuất (phạm vi null) cũng xóa ca đã tải', () async {
      controller.bindScope('quan-a|an');
      repo.shift = shiftOf('s1');
      await controller.load();

      controller.bindScope(null);

      expect(controller.state, isA<ShiftLoading>());
    });

    test('kết quả tải về sau khi đổi phạm vi bị bỏ', () async {
      controller.bindScope('quan-a|an');
      repo.shift = shiftOf('ca-cua-a');
      repo.delay = const Duration(milliseconds: 50);
      final pending = controller.load();

      controller.bindScope('quan-b|binh');
      await pending;

      expect(controller.state, isA<ShiftLoading>());
    });
  });

  group('load', () {
    test('chưa có ca -> ShiftNone', () async {
      await controller.load();
      expect(controller.state, isA<ShiftNone>());
    });

    test('đã có ca -> ShiftOpen kèm tên người mở', () async {
      repo.shift = CurrentShift(
        id: 's1',
        openedByName: 'An',
        openedAt: DateTime(2026, 10, 25, 8, 2),
      );
      await controller.load();
      final state = controller.state;
      expect(state, isA<ShiftOpen>());
      expect((state as ShiftOpen).shift.openedByName, 'An');
    });

    test('làm mới im lặng: lỗi thì giữ nguyên ca đang hiện', () async {
      repo.shift = CurrentShift(
        id: 's1',
        openedByName: 'An',
        openedAt: DateTime(2026, 10, 25, 8, 2),
      );
      await controller.load();
      expect(controller.state, isA<ShiftOpen>());

      repo.failure = const NoNetworkFailure();
      await controller.load(quiet: true);
      expect(controller.state, isA<ShiftOpen>());
    });

    test('mất mạng -> ShiftLoadFailed, thử lại được', () async {
      repo.failure = const NoNetworkFailure();
      await controller.load();
      expect(controller.state, isA<ShiftLoadFailed>());

      repo.failure = null;
      await controller.load();
      expect(controller.state, isA<ShiftNone>());
    });
  });

  group('validateOpeningCash', () {
    test('để trống -> báo lỗi theo lời thiết kế', () {
      expect(ShiftController.validateOpeningCash(''), 'Nhập số tiền hợp lệ.');
      expect(ShiftController.validateOpeningCash('  '), 'Nhập số tiền hợp lệ.');
    });

    test('không có chữ số -> báo lỗi', () {
      expect(ShiftController.validateOpeningCash('abc'), isNotNull);
    });

    test('số hợp lệ, kể cả có dấu chấm -> null', () {
      expect(ShiftController.validateOpeningCash('500000'), isNull);
      expect(ShiftController.validateOpeningCash('500.000'), isNull);
      expect(ShiftController.validateOpeningCash('0'), isNull);
    });

    test('quá lớn -> báo lỗi', () {
      expect(ShiftController.validateOpeningCash('100000001'), isNotNull);
      expect(ShiftController.validateOpeningCash('1234567890'), isNotNull);
    });
  });

  group('openShift', () {
    test('thành công -> opened; tải lại thì thấy ca đang mở', () async {
      final result = await controller.openShift('500.000');
      expect(result, OpenShiftResult.opened);
      expect(repo.openedWith, [500000]);

      // Màn hình tải lại sau khi đóng màn mở ca.
      await controller.load(quiet: true);
      expect(controller.state, isA<ShiftOpen>());
      expect(controller.opening, isFalse);
      expect(controller.openError, isNull);
    });

    test('nhập sai -> failed, không gọi database', () async {
      final result = await controller.openShift('');
      expect(result, OpenShiftResult.failed);
      expect(repo.openedWith, isEmpty);
      expect(controller.openError, isNotNull);
    });

    test('người khác mở trước -> joinedExisting, vào ca của họ', () async {
      repo.someoneOpensFirst = true;
      final result = await controller.openShift('500000');
      expect(result, OpenShiftResult.joinedExisting);
      final state = controller.state;
      expect(state, isA<ShiftOpen>());
      expect((state as ShiftOpen).shift.openedByName, 'An');
      expect(controller.openError, isNull);
    });

    test('xóa lỗi khi người dùng sửa lại ô nhập', () async {
      await controller.openShift('');
      expect(controller.openError, isNotNull);
      controller.clearOpenError();
      expect(controller.openError, isNull);
    });

    test('mất mạng -> failed kèm thông báo', () async {
      repo.failure = const NoNetworkFailure();
      final result = await controller.openShift('500000');
      expect(result, OpenShiftResult.failed);
      expect(controller.openError, contains('mạng'));
      expect(controller.opening, isFalse);
    });
  });
}
