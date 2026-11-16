import '../errors/app_failure.dart';

final _codePattern = RegExp(r'^[A-Z][A-Z0-9_]{2,}$');

/// Đổi lỗi của PostgREST thành [AppFailure].
///
/// Hàm trong database báo lỗi bằng `raise exception 'MA_LOI'`, nên `message` chính là mã
/// (vd `NO_OPEN_SHIFT`). Lỗi khác (token hết hạn, quyền...) không có dạng đó.
AppFailure mapPostgrestError({required String message, String? code}) {
  final text = message.trim();
  if (_codePattern.hasMatch(text)) return DatabaseFailure(text);
  // PostgREST uses PGRST202 when an RPC is missing from the database schema
  // cache. Surface this as a setup issue instead of the generic error screen.
  if (code == 'PGRST202') return const DatabaseFailure('APP_API_MISSING');
  if (code == 'PGRST301' ||
      code == 'PGRST303' ||
      text.toLowerCase().contains('jwt')) {
    return const SessionExpiredFailure();
  }
  return UnknownFailure('$code: $text');
}
