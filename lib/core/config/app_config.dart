/// Cấu hình đọc từ `--dart-define`. Không ghi khóa vào mã nguồn.
///
/// Chạy: flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// Chỉ dùng anon key. Tuyệt đối không đưa service_role key vào app.
class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
      );

  final String supabaseUrl;
  final String supabaseAnonKey;

  bool get isComplete => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Ẩn nút Google ở bản release (đặt `GOOGLE_LOGIN=false`) nếu project Supabase chưa bật Google.
  static const googleLoginEnabled = bool.fromEnvironment('GOOGLE_LOGIN', defaultValue: true);

  /// Bật nút Facebook (đặt `FACEBOOK_LOGIN=true` sau khi đã bật provider Facebook trên Supabase).
  static const facebookLoginEnabled = bool.fromEnvironment('FACEBOOK_LOGIN');

  /// Nơi trình duyệt trả về app sau khi đăng nhập OAuth (khớp intent-filter trong AndroidManifest
  /// và danh sách Redirect URLs trên Supabase).
  static const oauthRedirectUrl = 'vn.fore.app://login-callback';

  /// Độ dài mật khẩu tối thiểu. Phải khớp cài đặt Authentication trên Supabase.
  static const minPasswordLength = 8;
}
