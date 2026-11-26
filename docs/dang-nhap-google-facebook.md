# Đăng nhập Google / Facebook và khóa ký Android

Code đã sẵn sàng; tài liệu này là phần cấu hình trên các console, làm một lần cho cả nhóm.
Package Android: `vn.fore.app`. Deep link quay về app: `vn.fore.app://login-callback`.

## 1. Firebase: tải lại google-services.json
Firebase Console → Project settings → Add app → Android → package `vn.fore.app`.
Tải `google-services.json` chép đè vào `android/app/` (không commit).
File cũ (`com.example.fore`) vẫn để đó thì build bỏ qua Firebase (không có push/Crashlytics) chứ không lỗi.

## 2. Khóa ký release dùng chung
Một người tạo, gửi riêng file `.jks` cho nhóm (không đưa lên git):

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\fore-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias fore
```

Tạo `android/key.properties` (đã gitignore):

```properties
storeFile=C:/Users/<tên>/fore-release.jks
storePassword=<mật khẩu>
keyAlias=fore
keyPassword=<mật khẩu>
```

Lấy SHA-1 (dùng ở bước 1 và 3):

```powershell
keytool -list -v -keystore $env:USERPROFILE\fore-release.jks -alias fore
```

Thêm SHA-1 vào Firebase (app Android → Add fingerprint). Muốn `flutter run` bản debug đăng nhập
Google được thì thêm cả SHA-1 debug (`cd android; ./gradlew signingReport`).

## 3. Google
Google Cloud Console (cùng project Firebase) → APIs & Services:
1. OAuth consent screen: tên app, email hỗ trợ; để Testing và thêm email các thành viên làm test user.
2. Credentials → OAuth client ID:
   - loại **Web application** → giữ Client ID + Secret;
   - loại **Android** → package `vn.fore.app` + SHA-1 release (thêm một client nữa cho SHA-1 debug nếu cần).
3. Supabase → Authentication → Providers → Google: bật, dán Client ID + Secret của client **Web**;
   ô "Client IDs" thêm Client ID Android.
4. Supabase → Authentication → URL Configuration → Redirect URLs: thêm `vn.fore.app://login-callback` (app Android quay về sau khi đăng nhập trên trình duyệt).

## 4. Facebook (không bắt buộc)
1. developers.facebook.com → tạo app → thêm Facebook Login.
2. Valid OAuth Redirect URIs: `https://<project>.supabase.co/auth/v1/callback`.
3. Supabase → Providers → Facebook: dán App ID + App Secret.
4. Supabase → Authentication → URL Configuration → Redirect URLs: thêm `vn.fore.app://login-callback`.
5. `env.json` thêm: `"FACEBOOK_LOGIN": "true"`.
6. App Facebook ở chế độ phát triển: chỉ tài khoản trong Roles → Testers đăng nhập được.

## 5. Database
Chạy lại hàm `_stamp_account_kind` trong `database/04_membership_sessions.sql` (SQL Editor của Supabase)
để tài khoản tạo bằng Google/Facebook được đánh dấu là chủ quán. Không chạy thì tài khoản mới bị
coi là "chưa rõ loại" và không vào được luồng tạo quán.

## 6. Build bản mang ra quán

```powershell
flutter build apk --release --dart-define-from-file=env.json
```

APK: `build/app/outputs/flutter-apk/app-release.apk`.

Ghi chú: bản debug luôn hiện cả hai nút để xem giao diện; bấm khi chưa cấu hình sẽ báo
"Chưa đăng nhập được bằng tài khoản này". Nhân viên vẫn đăng nhập bằng tài khoản chủ quán tạo.
