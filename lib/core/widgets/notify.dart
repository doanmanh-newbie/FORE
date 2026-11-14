import 'package:flutter/material.dart';

import '../errors/app_failure.dart';
import '../errors/failure_messages.dart';

/// Báo lỗi bằng thanh thông báo nổi ở dưới màn hình (lỗi nghiệp vụ, không chặn thao tác khác).
void showFailure(BuildContext context, AppFailure failure) =>
    showNotice(context, failure.userMessage);

void showNotice(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
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
