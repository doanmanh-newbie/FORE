import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/network_errors.dart';
import '../domain/shift_models.dart';
import '../domain/shift_repository.dart';

/// Cài đặt [ShiftRepository] bằng các hàm database `current_shift` và `open_shift`.
class SupabaseShiftRepository implements ShiftRepository {
  SupabaseShiftRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<CurrentShift?> currentShift() => _guard(() async {
        final rows = await _client.rpc('current_shift') as List<dynamic>;
        if (rows.isEmpty) return null;
        return CurrentShift.fromMap(rows.first as Map<String, dynamic>);
      });

  @override
  Future<void> openShift({required int openingCash}) => _guard(() async {
        await _client.rpc(
          'open_shift',
          params: {'p_opening_cash': openingCash},
        );
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AppFailure {
      rethrow;
    } on PostgrestException catch (e) {
      // Lỗi nghiệp vụ của database là mã chữ nằm trong `message`.
      if (e.message.contains('SHIFT_ALREADY_OPEN')) {
        throw const ShiftAlreadyOpenFailure();
      }
      if (looksLikeNetworkError(e)) throw const NoNetworkFailure();
      debugPrint('Fore: lỗi database: ${e.code} ${e.message}');
      throw UnknownFailure(e);
    } catch (e) {
      if (looksLikeNetworkError(e)) throw const NoNetworkFailure();
      debugPrint('Fore: lỗi không rõ: $e');
      throw UnknownFailure(e);
    }
  }
}
