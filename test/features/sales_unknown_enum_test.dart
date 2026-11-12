import 'package:flutter_test/flutter_test.dart';
import 'package:fore/core/errors/app_failure.dart';
import 'package:fore/features/sales/data/rpc_sales_repository.dart';

import '../support/fakes.dart';
import 'database_contract_test.dart' show fixture;

/// Database chặn giá trị lạ bằng CHECK (bill_type, status). Nếu vẫn gặp giá trị
/// lạ, app phải báo lỗi rõ ràng (UnknownFailure), không đoán loại bill.
void main() {
  Map<String, dynamic> billWith(String key, String value) =>
      Map<String, dynamic>.from(fixture('bill_detail') as Map)..[key] = value;

  for (final key in ['bill_type', 'status']) {
    test('$key lạ -> UnknownFailure, không ném FormatException thô', () async {
      final repo = RpcSalesRepository(
          FakeRpcClient({'bill_detail': billWith(key, 'gia_tri_la')}));
      await expectLater(repo.bill('b1'), throwsA(isA<UnknownFailure>()));
    });
  }
}
