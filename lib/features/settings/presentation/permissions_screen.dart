import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/permissions/app_permissions.dart';
import '../../../core/permissions/permission_setup.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/status_chip.dart';

/// Thêm > Quyền truy cập: từng quyền, app dùng để làm gì, trạng thái hiện tại và nút bật.
/// Tự đọc lại trạng thái khi người dùng quay về từ Cài đặt của máy.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key});

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final _states = <AppPermission, PermissionAccess>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final gateway = permissionGatewayOf(context);
    final next = <AppPermission, PermissionAccess>{
      for (final p in AppPermission.values) p: await gateway.status(p),
    };
    if (!mounted) return;
    setState(() {
      _states
        ..clear()
        ..addAll(next);
      _loading = false;
    });
  }

  Future<void> _enable(AppPermission p) async {
    final result = await askPermission(context, p);
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    if (result == PermissionAccess.granted) {
      showNotice(context, 'Đã bật quyền ${p.title.toLowerCase()}.',
          kind: NoticeKind.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = _states.values.where((s) => s.isGranted).length;
    final available =
        _states.values.where((s) => s != PermissionAccess.unsupported).length;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: 'Quyền truy cập',
            subtitle: _loading
                ? 'Đang kiểm tra…'
                : 'Đã bật $granted/$available quyền. Fore chỉ hỏi khi cần cho một chức năng.',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  for (final p in AppPermission.values) ...[
                    _PermissionCard(
                      permission: p,
                      access: _states[p],
                      onEnable: () => _enable(p),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Muốn tắt một quyền đã bật? Vào Cài đặt của máy > Ứng dụng > Fore > Quyền.',
                    style: AppTextStyles.caption,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        await permissionGatewayOf(context).openSettings();
                      },
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: const Text('Mở cài đặt của máy'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.permission,
    required this.access,
    required this.onEnable,
  });

  final AppPermission permission;
  final PermissionAccess? access;
  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final a = access;
    final (label, severity) = switch (a) {
      PermissionAccess.granted => ('Đã bật', StatusSeverity.healthy),
      PermissionAccess.blocked => ('Đã chặn', StatusSeverity.critical),
      PermissionAccess.unsupported => ('Không áp dụng', StatusSeverity.neutral),
      PermissionAccess.denied => ('Chưa bật', StatusSeverity.attention),
      null => ('…', StatusSeverity.neutral),
    };
    return ForeCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ForeIconBadge(icon: permission.icon, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(permission.title, style: AppTextStyles.cardTitle),
              ),
              StatusChip(label: label, severity: severity, compact: true),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: Text(permission.purpose, style: AppTextStyles.caption),
          ),
          if (a == PermissionAccess.denied || a == PermissionAccess.blocked) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: SizedBox(
                height: 38,
                child: a == PermissionAccess.blocked
                    ? OutlinedButton.icon(
                        onPressed: onEnable,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          textStyle: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: const Text('Mở cài đặt'),
                      )
                    : FilledButton.icon(
                        onPressed: onEnable,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          textStyle: const TextStyle(
                            fontFamily: AppFonts.body,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        icon: const Icon(Icons.toggle_on_outlined, size: 18),
                        label: const Text('Bật'),
                      ),
              ),
            ),
          ],
          if (a == PermissionAccess.unsupported)
            Padding(
              padding: const EdgeInsets.only(left: 52, top: 6),
              child: Text(
                'Thiết bị hoặc trình duyệt này không cần cấp quyền riêng.',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textHint),
              ),
            ),
        ],
      ),
    );
  }
}
