import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/failure_messages.dart';

/// Mã lỗi mà app đổi thành lớp lỗi riêng (không đi qua `databaseMessages`).
const _handledByFailureClasses = {
  'PHONE_INVALID',
  'ALREADY_MEMBER',
  'ALREADY_INVITED',
  'INVITE_NOT_FOUND',
};

/// Mọi `raise exception 'MA_LOI'` trong các nhóm cài SQL phải có câu tiếng Việt, nếu không người dùng
/// chỉ thấy "Có lỗi xảy ra". Thêm mã lỗi mới ở database mà quên câu thông báo thì test này báo ngay.
void main() {
  test('mọi mã lỗi database đều có câu thông báo tiếng Việt', () {
    final codes = <String>{};
    final pattern = RegExp(r"raise exception '([A-Z][A-Z0-9_]+)'");
    for (final entity in Directory('database').listSync()) {
      if (entity is! File) continue;
      final name = entity.uri.pathSegments.last;
      if (!RegExp(r'^0([1-4]|[78])_.*\.sql$').hasMatch(name)) continue;
      for (final m in pattern.allMatches(entity.readAsStringSync())) {
        codes.add(m.group(1)!);
      }
    }
    expect(codes, isNotEmpty, reason: 'không đọc được database/*.sql');
    final missing = codes
        .where((c) =>
            !databaseMessages.containsKey(c) &&
            !_handledByFailureClasses.contains(c))
        .toList()
      ..sort();
    expect(missing, isEmpty,
        reason: 'Thiếu câu thông báo trong databaseMessages cho: $missing');
  });
}
