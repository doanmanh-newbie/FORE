import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/data/json_row.dart';
import 'package:fore/core/data/rpc_errors.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/core/errors/failure_messages.dart';
import 'package:fore/core/format.dart';
import 'package:fore/core/text.dart';
import 'package:fore/features/inventory/domain/inventory_models.dart';
import 'package:fore/features/sales/domain/sales_models.dart';

void main() {
  group('formatVnd', () {
    test('ngăn cách hàng nghìn bằng dấu chấm', () {
      expect(formatVnd(0), equals('0đ'));
      expect(formatVnd(999), equals('999đ'));
      expect(formatVnd(1000), equals('1.000đ'));
      expect(formatVnd(29000), equals('29.000đ'));
      expect(formatVnd(1250000), equals('1.250.000đ'));
      expect(formatVnd(-50000), equals('-50.000đ'));
    });
  });

  group('formatQuantity', () {
    test('dùng dấu chấm ngăn nghìn và giữ đơn vị nguyên liệu', () {
      expect(formatQuantity(4400, unit: 'g'), '4.400 g');
      expect(formatQuantity(20000, unit: 'ml'), '20.000 ml');
      expect(formatQuantity(-2680, unit: 'g'), '-2.680 g');
      expect(formatQuantity(0, unit: 'cái'), '0 cái');
      expect(formatQuantity(149, unit: 'piece'), '149 cái');
      expect(formatServings(1000, 'ly'), '1.000 ly');
    });
  });

  group('parseMoney', () {
    test('đọc các kiểu người dùng hay gõ', () {
      expect(parseMoney('1.250.000'), equals(1250000));
      expect(parseMoney('1250000đ'), equals(1250000));
      expect(parseMoney(' 50 000 '), equals(50000));
      expect(parseMoney('0'), equals(0));
    });
    test('trống hoặc vô nghĩa thì null; quá lớn thì null', () {
      expect(parseMoney(''), isNull);
      expect(parseMoney('abc'), isNull);
      expect(parseMoney('9999999999999'), isNull);
    });
  });

  group('thời gian', () {
    test('formatClock không đệm số 0 ở giờ', () {
      expect(formatClock(DateTime(2026, 10, 23, 8, 2)), equals('8:02'));
      expect(formatClock(DateTime(2026, 10, 23, 13, 5)), equals('13:05'));
      expect(formatClock(DateTime(2026, 10, 23, 0, 0)), equals('0:00'));
    });
    test('formatWait', () {
      expect(formatWait(const Duration(seconds: 30)), equals('vừa xong'));
      expect(formatWait(const Duration(minutes: 5)), equals('5 phút'));
      expect(formatWait(const Duration(minutes: 60)), equals('1 giờ'));
      expect(formatWait(const Duration(minutes: 65)), equals('1 giờ 5 phút'));
    });
    test('formatBillNo đệm 3 chữ số', () {
      expect(formatBillNo(84), equals('#084'));
      expect(formatBillNo(7), equals('#007'));
      expect(formatBillNo(1234), equals('#1234'));
    });
  });

  group('foldVietnamese', () {
    test('bỏ dấu và chữ hoa', () {
      expect(foldVietnamese('Bàn 1'), equals('ban 1'));
      expect(foldVietnamese('Cà phê SỮA'), equals('ca phe sua'));
      expect(foldVietnamese('Đường'), equals('duong'));
      expect(foldVietnamese('Trà ĐÀO cam sả'), equals('tra dao cam sa'));
      expect(foldVietnamese('Bánh mì trứng'), equals('banh mi trung'));
    });
  });

  group('mapPostgrestError', () {
    test('mã chữ in hoa là lỗi nghiệp vụ', () {
      final f = mapPostgrestError(message: 'NO_OPEN_SHIFT', code: 'P0001');
      expect(
          f,
          isA<DatabaseFailure>()
              .having((e) => e.code, 'code', 'NO_OPEN_SHIFT'));
    });
    test('có khoảng trắng thừa vẫn nhận ra', () {
      expect(mapPostgrestError(message: ' LAST_OWNER \n', code: '42501'),
          isA<DatabaseFailure>());
    });
    test('JWT hết hạn là lỗi phiên', () {
      expect(mapPostgrestError(message: 'JWT expired', code: 'PGRST301'),
          isA<SessionExpiredFailure>());
      expect(mapPostgrestError(message: 'Invalid JWT', code: null),
          isA<SessionExpiredFailure>());
    });
    test('lỗi lạ là UnknownFailure', () {
      expect(
          mapPostgrestError(
              message: 'permission denied for table staff', code: '42501'),
          isA<UnknownFailure>());
      expect(
          mapPostgrestError(message: 'ab', code: null), isA<UnknownFailure>());
    });
  });

  group('FailureMessage', () {
    test('lời mời hết hạn có hướng xử lý cụ thể', () {
      expect(const InviteExpiredFailure().userMessage,
          contains('Nhờ chủ quán gửi lời mời mới'));
    });

    test('mã database có câu tiếng Việt, mã lạ có câu chung', () {
      expect(const DatabaseFailure('NO_OPEN_SHIFT').userMessage,
          contains('Chưa có ca đang mở'));
      expect(const DatabaseFailure('DISCOUNT_INVALID').userMessage,
          contains('Giảm giá'));
      expect(const DatabaseFailure('MA_LA_CHUA_CO').userMessage,
          equals('Có lỗi xảy ra. Thử lại sau ít phút.'));
    });
    test('mọi mã trong bảng đều có câu không rỗng', () {
      for (final e in databaseMessages.entries) {
        expect(e.value.trim().isNotEmpty, isTrue, reason: e.key);
      }
    });
    test('lỗi máy khác gây ra thì tự tải lại', () {
      for (final c in [
        'TABLE_HAS_OPEN_BILL',
        'BILL_NOT_OPEN',
        'NO_OPEN_SHIFT',
        'LINE_ALREADY_VOIDED'
      ]) {
        expect(DatabaseFailure(c).shouldRefresh, isTrue, reason: c);
      }
      expect(const DatabaseFailure('REASON_REQUIRED').shouldRefresh, isFalse);
      expect(const NoNetworkFailure().shouldRefresh, isFalse);
    });
    test('lỗi tài khoản đưa về đăng nhập', () {
      expect(const SessionExpiredFailure().isSessionProblem, isTrue);
      expect(const DatabaseFailure('NOT_STAFF').isSessionProblem, isTrue);
      expect(const DatabaseFailure('NOT_LOGGED_IN').isSessionProblem, isTrue);
      expect(const DatabaseFailure('BILL_EMPTY').isSessionProblem, isFalse);
    });
  });

  group('RowReader', () {
    test('đọc đúng kiểu', () {
      final row = <String, dynamic>{
        's': 'x',
        'n': 5,
        'f': true,
        't': '2026-10-23T08:02:00+07:00',
        'z': null
      };
      expect(row.str('s'), equals('x'));
      expect(row.integer('n'), equals(5));
      expect(row.flag('f'), isTrue);
      expect(row.strOrNull('z'), isNull);
      expect(row.intOrNull('z'), isNull);
      expect(row.time('t').isAtSameMomentAs(DateTime.utc(2026, 10, 23, 1, 2)),
          isTrue); // 08:02 giờ +07 = 01:02 UTC
    });
    test('sai kiểu hoặc thiếu thì báo rõ tên trường', () {
      final row = <String, dynamic>{'n': 'abc'};
      expect(
          () => row.integer('n'),
          throwsA(isA<FormatException>()
              .having((e) => e.message, 'message', contains('"n"'))));
      expect(() => row.str('thieu'), throwsA(isA<FormatException>()));
      expect(() => row.flag('n'), throwsA(isA<FormatException>()));
      expect(() => row.time('n'), throwsA(isA<FormatException>()));
    });
    test('số thực nguyên (3.0) được chấp nhận, 3.5 thì không', () {
      expect(<String, dynamic>{'n': 3.0}.integer('n'), equals(3));
      expect(() => <String, dynamic>{'n': 3.5}.integer('n'),
          throwsA(isA<FormatException>()));
    });
    test('asRows / asObject kiểm tra kiểu', () {
      expect(
          asRows([
            <String, dynamic>{'a': 1}
          ]),
          hasLength(1));
      expect(() => asRows('x'), throwsA(isA<FormatException>()));
      expect(() => asRows([1]), throwsA(isA<FormatException>()));
      expect(asObject(<String, dynamic>{'a': 1}), equals({'a': 1}));
      expect(() => asObject([]), throwsA(isA<FormatException>()));
    });
  });

  group('groupMenuRows', () {
    test('gộp size theo món và giữ thứ tự database', () {
      final items = groupMenuRows([
        {
          'item_id': 'bm',
          'item_name': 'Bánh mì trứng',
          'group_name': 'Ăn nhẹ',
          'size_id': 'bm-1',
          'size_name': 'Phần',
          'price': 20000
        },
        {
          'item_id': 'cf',
          'item_name': 'Cà phê sữa',
          'group_name': null,
          'size_id': 'cf-m',
          'size_name': 'M',
          'price': 25000
        },
        {
          'item_id': 'cf',
          'item_name': 'Cà phê sữa',
          'group_name': null,
          'size_id': 'cf-l',
          'size_name': 'L',
          'price': 30000
        },
      ]);
      expect(items.map((i) => i.name).toList(),
          equals(['Bánh mì trứng', 'Cà phê sữa']));
      expect(items[1].sizes.map((s) => s.name).toList(), equals(['M', 'L']));
      expect(items[1].group, isNull);
    });
  });

  group('BillView', () {
    Map<String, dynamic> json() => {
          'id': 'b1',
          'bill_no': 84,
          'status': 'open',
          'bill_type': 'dine_in',
          'table_id': 't',
          'table_name': 'Bàn 2',
          'area_name': 'Tầng 1',
          'guests': 2,
          'opened_at': '2026-10-23T08:16:00+00:00',
          'discount': 5000,
          'discount_reason': 'khách quen',
          'payment_method': null,
          'prep_done': false,
          'subtotal': 70000,
          'payable': 65000,
          'lines': [
            {
              'id': 'l1',
              'size_id': 's',
              'item_name': 'Cà phê',
              'size_name': 'M',
              'qty': 2,
              'unit_price': 25000,
              'voided': false
            },
            {
              'id': 'l2',
              'size_id': 's2',
              'item_name': 'Bánh',
              'size_name': 'P',
              'qty': 3,
              'unit_price': 20000,
              'voided': true
            },
          ],
        };
    test('đọc đủ trường, dòng đã bỏ không tính vào số phần', () {
      final b = BillView.fromJson(json());
      expect(b.isOpen, isTrue);
      expect(b.title, equals('Bàn 2'));
      expect(b.lines, hasLength(2));
      expect(b.activeLines, hasLength(1));
      expect(b.portions, equals(2));
      expect(b.payable, equals(65000));
    });
    test('đơn mang đi có tiêu đề kèm số bill', () {
      final j = json()
        ..['bill_type'] = 'take_away'
        ..['table_name'] = null;
      expect(BillView.fromJson(j).title, equals('Mang đi #084'));
    });
    test('trạng thái hoặc loại lạ thì báo lỗi, không đoán', () {
      expect(() => BillView.fromJson(json()..['status'] = 'void'),
          throwsA(isA<FormatException>()));
      expect(() => BillView.fromJson(json()..['bill_type'] = 'delivery'),
          throwsA(isA<FormatException>()));
    });
  });

  group('quantityInBase (nhập hàng / hao hụt)', () {
    const ml = UnitChoice('ml', 1);
    const lit = UnitChoice('lít', 1000);
    test('đơn vị gốc', () {
      expect(quantityInBase('500', ml), equals(500));
      expect(quantityInBase(' 250 ', ml), equals(250));
    });
    test('lít sang ml, chấp nhận dấu phẩy hoặc chấm', () {
      expect(quantityInBase('1', lit), equals(1000));
      expect(quantityInBase('1,5', lit), equals(1500));
      expect(quantityInBase('2.25', lit), equals(2250));
    });
    test('không hợp lệ: trống, 0, âm, chữ, không ra số nguyên', () {
      expect(quantityInBase('', ml), isNull);
      expect(quantityInBase('0', ml), isNull);
      expect(quantityInBase('-5', ml), isNull);
      expect(quantityInBase('abc', ml), isNull);
      expect(quantityInBase('0,5', ml), isNull); // 0,5 ml không phải số nguyên
      expect(quantityInBase('0,0004', lit), isNull); // 0,4 ml
      expect(quantityInBase('1e12', ml), isNull);
    });
    test('unitChoices theo đơn vị gốc', () {
      expect(unitChoices('ml').map((u) => u.label).toList(),
          equals(['ml', 'lít']));
      expect(unitChoices('g').map((u) => u.factor).toList(), equals([1, 1000]));
      expect(
          unitChoices('piece').map((u) => u.label).toList(), equals(['cái']));
    });
  });
}
