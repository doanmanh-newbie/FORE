import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/owner/data/owner_dashboard_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  recipeCoverageTests();
  test('lỗi dịch vụ -> dùng giá trị dự phòng và ghi nhận thiếu nguồn', () async {
    var missing = 0;
    final value = await optionalOrFallback<List<int>>(
      Future.error(const PostgrestException(message: 'boom', code: '500')),
      const [],
      () => missing++,
    );
    expect(value, isEmpty);
    expect(missing, 1);
  });

  for (final error in <Object>[
    const AuthException('expired'),
    const PostgrestException(message: 'JWT expired', code: 'PGRST301'),
    const PostgrestException(message: 'STAFF_DEVICE_UNTRUSTED'),
    const PostgrestException(message: 'NOT_LOGGED_IN'),
  ]) {
    test('lỗi xác thực được ném lại: $error', () async {
      var missing = 0;
      await expectLater(
        optionalOrFallback<List<int>>(Future.error(error), const [], () => missing++),
        throwsA(same(error)),
      );
      expect(missing, 0);
    });
  }
}

void recipeCoverageTests() {
  group('applyRecipeCoverage', () {
    test('có dữ liệu -> gắn has_recipe theo size còn thiếu', () {
      final menu = <Map<String, dynamic>>[
        {'size_id': 'a'},
        {'size_id': 'b'},
      ];
      final known = applyRecipeCoverage(menu, {
        'missing_recipe_sizes': ['b'],
        'missing_recipe_count': 1,
      });
      expect(known, isTrue);
      expect(menu[0]['has_recipe'], isTrue);
      expect(menu[1]['has_recipe'], isFalse);
    });

    test('server cũ không trả khóa -> không giả định đủ công thức', () {
      final menu = <Map<String, dynamic>>[
        {'size_id': 'a'},
      ];
      final known = applyRecipeCoverage(menu, {'reports': []});
      expect(known, isFalse);
      expect(menu[0].containsKey('has_recipe'), isFalse);
    });
  });
}
