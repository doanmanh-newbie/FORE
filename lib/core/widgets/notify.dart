import 'package:flutter/material.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../errors/app_failure.dart';
import '../errors/failure_messages.dart';

/// Loại thanh thông báo: quyết định icon và màu điểm nhấn.
enum NoticeKind { info, success, error }

/// Báo lỗi bằng thanh thông báo nổi ở dưới màn hình (lỗi nghiệp vụ, không chặn thao tác khác).
void showFailure(BuildContext context, AppFailure failure) =>
    showNotice(context, failure.userMessage, kind: NoticeKind.error);

/// Thanh thông báo nổi, gọn (theme định kiểu nền, bo góc, vị trí): icon theo [kind] + một câu.
void showNotice(
  BuildContext context,
  String message, {
  NoticeKind kind = NoticeKind.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final (icon, color) = switch (kind) {
    NoticeKind.success => (Icons.check_circle_rounded, const Color(0xFF5DD39B)),
    NoticeKind.error => (Icons.error_rounded, const Color(0xFFFF8E82)),
    NoticeKind.info => (Icons.info_rounded, const Color(0xFFBFD6F0)),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      duration: Duration(seconds: kind == NoticeKind.error ? 5 : 3),
      content: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ]),
      action: actionLabel == null || onAction == null
          ? null
          : SnackBarAction(label: actionLabel, onPressed: onAction),
    ));
}

/// Chạy một thao tác của controller; lỗi nghiệp vụ được báo bằng thanh thông báo thay vì làm sập.
/// Trả `null` nếu có lỗi hoặc thao tác bị bỏ qua (đang bận).
Future<T?> guarded<T>(
    BuildContext context, Future<T?> Function() action) async {
  try {
    return await action();
  } on AppFailure catch (f) {
    if (context.mounted) showFailure(context, f);
    return null;
  }
}

/// Khung thông báo nội tuyến (thay `MaterialBanner` thô): thẻ nhạt bo 14, icon, một câu,
/// nút chữ tùy chọn. Dùng cho trạng thái kéo dài (mất mạng, thiếu dữ liệu, thiếu quyền).
class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.icon = Icons.cloud_off_rounded,
    this.kind = NoticeKind.info,
    this.actionLabel,
    this.onAction,
    this.margin = const EdgeInsets.fromLTRB(16, 8, 16, 0),
  });

  final String message;
  final IconData icon;
  final NoticeKind kind;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (kind) {
      NoticeKind.error => (AppColors.statusCritical, AppColors.statusCriticalTint),
      NoticeKind.success => (AppColors.statusHealthy, AppColors.statusHealthyTint),
      NoticeKind.info => (AppColors.brand, AppColors.backgroundTint),
    };
    return Padding(
      padding: margin,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(foregroundColor: fg),
                child: Text(actionLabel!),
              )
            else
              const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }
}
