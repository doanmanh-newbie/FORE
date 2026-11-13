import 'package:flutter/material.dart';

import 'colors.dart';

/// Đặt [AppColors.current] theo theme đang dùng (sáng/tối theo hệ thống).
/// Khi chế độ đổi lúc app đang chạy, dựng lại toàn bộ cây con để mọi widget đọc màu mới,
/// kể cả widget `const` không tự rebuild.
class AppPaletteSync extends StatefulWidget {
  const AppPaletteSync({required this.child, super.key});

  final Widget child;

  @override
  State<AppPaletteSync> createState() => _AppPaletteSyncState();
}

class _AppPaletteSyncState extends State<AppPaletteSync> {
  Brightness? _applied;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (brightness != _applied) {
      final changed = _applied != null;
      _applied = brightness;
      AppColors.current = AppPalette.of(brightness);
      if (changed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          void rebuild(Element e) {
            e.markNeedsBuild();
            e.visitChildren(rebuild);
          }

          (context as Element).visitChildren(rebuild);
        });
      }
    }
    return widget.child;
  }
}
