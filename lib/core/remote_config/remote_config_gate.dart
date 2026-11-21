import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'remote_app_config.dart';
import 'remote_config_controller.dart';

/// Đặt bọc toàn bộ app (trong `MaterialApp.builder`): bảo trì hoặc phiên bản quá cũ
/// thì che app bằng màn thông báo, còn lại hiện app như bình thường.
class RemoteConfigGate extends StatelessWidget {
  const RemoteConfigGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<RemoteConfigController?>();
    if (c == null) return child;
    return switch (c.verdict) {
      RemoteConfigVerdict.ok => child,
      RemoteConfigVerdict.maintenance => _BlockingNotice(
          key: const ValueKey('remote-config-maintenance'),
          icon: Icons.construction_rounded,
          title: 'Fore đang bảo trì',
          message: c.config.maintenanceMessage ??
              'Hệ thống đang được nâng cấp. Bạn vui lòng quay lại sau ít phút.',
          primaryLabel: c.loading ? 'Đang kiểm tra' : 'Kiểm tra lại',
          onPrimary: c.loading ? null : c.load,
        ),
      RemoteConfigVerdict.updateRequired => _BlockingNotice(
          key: const ValueKey('remote-config-update-required'),
          icon: Icons.system_update_rounded,
          title: 'Cần cập nhật ứng dụng',
          message: _updateMessage(c),
          primaryLabel: c.loading ? 'Đang kiểm tra' : 'Kiểm tra lại',
          onPrimary: c.loading ? null : c.load,
        ),
      RemoteConfigVerdict.updateSuggested => _BlockingNotice(
          key: const ValueKey('remote-config-update-suggested'),
          icon: Icons.system_update_rounded,
          title: 'Đã có phiên bản mới',
          message: _updateMessage(c),
          primaryLabel: 'Để sau',
          onPrimary: c.dismissUpdate,
        ),
    };
  }

  static String _updateMessage(RemoteConfigController c) =>
      'Phiên bản bạn đang dùng (${c.appVersion}) đã cũ. '
      'Hãy cập nhật Fore lên bản ${c.config.minVersion} trở lên để tiếp tục.';
}

class _BlockingNotice extends StatelessWidget {
  const _BlockingNotice({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback? onPrimary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 48, color: AppColors.statusAttention),
                  const SizedBox(height: 16),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.screenTitle),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center, style: AppTextStyles.body),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onPrimary,
                      child: Text(primaryLabel),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
