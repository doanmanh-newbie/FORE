import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chế độ sáng/tối của cả app, lưu trên thiết bị. Mặc định theo hệ thống.
final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

const _key = 'theme.mode.v1';

/// Đọc lựa chọn đã lưu (gọi một lần lúc khởi động).
Future<void> loadThemeMode() async {
  final saved = (await SharedPreferences.getInstance()).getString(_key);
  themeModeNotifier.value = ThemeMode.values
      .firstWhere((m) => m.name == saved, orElse: () => ThemeMode.system);
}

/// Nút đổi sáng/tối, gắn ở đầu trang mọi màn chức năng.
class ThemeModeToggle extends StatelessWidget {
  const ThemeModeToggle({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: dark ? 'Chuyển sang nền sáng' : 'Chuyển sang nền tối',
      color: color,
      constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      onPressed: () async {
        final next = dark ? ThemeMode.light : ThemeMode.dark;
        themeModeNotifier.value = next;
        await (await SharedPreferences.getInstance())
            .setString(_key, next.name);
      },
    );
  }
}
