import 'package:flutter_test/flutter_test.dart';
import 'package:fore/features/auth/data/supabase_auth_repository.dart';
import 'package:fore/features/auth/domain/auth_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

User _user({Map<String, dynamic>? app, Map<String, dynamic>? user}) => User(
      id: 'u1',
      appMetadata: app ?? const {},
      userMetadata: user,
      aud: 'authenticated',
      createdAt: '2026-01-01T00:00:00Z',
    );

void main() {
  test('đọc loại tài khoản từ app_metadata', () {
    expect(
      SupabaseAuthRepository.accountKindOf(
          _user(app: {'fore_account_kind': 'staff'})),
      AccountKind.staff,
    );
  });

  test('user_metadata tự sửa được nên không được tin', () {
    expect(
      SupabaseAuthRepository.accountKindOf(_user(
        app: {'fore_account_kind': 'staff'},
        user: {'account_kind': 'owner'},
      )),
      AccountKind.staff,
    );
    expect(
      SupabaseAuthRepository.accountKindOf(
          _user(user: {'account_kind': 'owner'})),
      AccountKind.unknown,
    );
  });
}
