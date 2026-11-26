import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/firebase/firebase_services.dart';
import '../../../core/permissions/app_permissions.dart';
import '../../../core/permissions/permission_setup.dart';
import '../../../core/push/push_registration_controller.dart';
import '../../../core/widgets/fore_card.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/status_chip.dart';

/// Thêm > Kết nối Firebase: trạng thái từng dịch vụ Firebase app dùng (Core, Cloud Messaging,
/// Analytics, Crashlytics), bật/tắt thu thập và nút gửi thử. Dữ liệu nghiệp vụ ở Supabase.
class FirebaseScreen extends StatelessWidget {
  const FirebaseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firebase =
        context.watch<FirebaseServices?>() ?? NoopFirebaseServices();
    final push = context.watch<PushRegistrationController?>();
    final link = firebase.link;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: 'Kết nối Firebase',
            subtitle: switch (link) {
              FirebaseLink.connected =>
                'Dự án ${firebase.projectId ?? '—'} · đã kết nối',
              FirebaseLink.connecting => 'Đang kết nối…',
              FirebaseLink.unsupported =>
                'Firebase chạy trên app Android/iOS.',
              FirebaseLink.failed => 'Chưa kết nối được.',
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _Summary(link: link, error: firebase.error),
                const SizedBox(height: 20),
                const ForeSectionTitle(title: 'Dịch vụ'),
                _ServiceCard(
                  icon: Icons.local_fire_department_rounded,
                  title: 'Firebase Core',
                  description: 'Nền tảng chung cho các dịch vụ bên dưới.',
                  status: _linkChip(link),
                  detail: firebase.projectId == null
                      ? null
                      : 'Mã dự án: ${firebase.projectId}',
                ),
                _MessagingCard(push: push, link: link),
                _ServiceCard(
                  icon: Icons.insights_rounded,
                  title: 'Analytics',
                  description:
                      'Số liệu sử dụng ẩn danh (màn hình đã xem, thao tác chính) để cải thiện app.',
                  status: _onOff(firebase.analyticsEnabled, link),
                  toggle: link == FirebaseLink.connected
                      ? (
                          value: firebase.analyticsEnabled,
                          onChanged: firebase.setAnalyticsEnabled,
                        )
                      : null,
                  actionLabel: firebase.analyticsEnabled ? 'Gửi sự kiện thử' : null,
                  onAction: () async {
                    await firebase.logEvent('fore_test_event',
                        {'source': 'firebase_screen'});
                    if (context.mounted) {
                      showNotice(context,
                          'Đã gửi sự kiện "fore_test_event". Xem trong Firebase > Analytics > DebugView.',
                          kind: NoticeKind.success);
                    }
                  },
                ),
                _ServiceCard(
                  icon: Icons.bug_report_rounded,
                  title: 'Crashlytics',
                  description: kDebugMode
                      ? 'Báo lỗi tự động. Bản debug không gửi để khỏi lẫn lỗi lúc phát triển.'
                      : 'Báo lỗi tự động khi app gặp sự cố, giúp sửa nhanh hơn.',
                  status: _onOff(firebase.crashlyticsEnabled, link),
                  toggle: link == FirebaseLink.connected
                      ? (
                          value: firebase.crashlyticsEnabled,
                          onChanged: firebase.setCrashlyticsEnabled,
                        )
                      : null,
                  actionLabel:
                      firebase.crashlyticsEnabled ? 'Gửi báo lỗi thử' : null,
                  onAction: () async {
                    await firebase.recordError(
                      StateError('Kiểm tra Crashlytics từ Fore'),
                      StackTrace.current,
                      reason: 'Người dùng bấm "Gửi báo lỗi thử"',
                    );
                    if (context.mounted) {
                      showNotice(context,
                          'Đã gửi báo lỗi thử (không làm dừng app).',
                          kind: NoticeKind.success);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const ForeSectionTitle(title: 'Dữ liệu của quán'),
                ForeCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ForeIconBadge(icon: Icons.storage_rounded, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Đăng nhập, dữ liệu bán hàng, kho và ảnh món lưu trên Supabase. '
                          'Firebase chỉ dùng cho thông báo đẩy, số liệu sử dụng và báo lỗi.',
                          style: AppTextStyles.caption.copyWith(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static StatusChip _linkChip(FirebaseLink link) => switch (link) {
        FirebaseLink.connected => const StatusChip(
            label: 'Đã kết nối', severity: StatusSeverity.healthy, compact: true),
        FirebaseLink.connecting => const StatusChip(
            label: 'Đang kết nối', severity: StatusSeverity.neutral, compact: true),
        FirebaseLink.unsupported => const StatusChip(
            label: 'Không áp dụng', severity: StatusSeverity.neutral, compact: true),
        FirebaseLink.failed => const StatusChip(
            label: 'Lỗi', severity: StatusSeverity.critical, compact: true),
      };

  static StatusChip _onOff(bool on, FirebaseLink link) =>
      link != FirebaseLink.connected
          ? _linkChip(link)
          : on
              ? const StatusChip(
                  label: 'Đang bật', severity: StatusSeverity.healthy, compact: true)
              : const StatusChip(
                  label: 'Đã tắt', severity: StatusSeverity.neutral, compact: true);
}

/// Thẻ tóm tắt đầu trang (navy): biểu tượng, một câu trạng thái chung.
class _Summary extends StatelessWidget {
  const _Summary({required this.link, this.error});
  final FirebaseLink link;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = switch (link) {
      FirebaseLink.connected => (
          Icons.cloud_done_rounded,
          'Firebase đang hoạt động',
          'Thông báo đẩy, số liệu sử dụng và báo lỗi sẵn sàng trên máy này.',
        ),
      FirebaseLink.connecting => (
          Icons.cloud_sync_rounded,
          'Đang kết nối Firebase',
          'Chờ vài giây…',
        ),
      FirebaseLink.unsupported => (
          Icons.phone_android_rounded,
          'Dùng app Android để có Firebase',
          'Bản web và máy tính chạy đầy đủ chức năng quán, chỉ không có thông báo đẩy và báo lỗi tự động.',
        ),
      FirebaseLink.failed => (
          Icons.cloud_off_rounded,
          'Chưa kết nối được Firebase',
          'App vẫn chạy bình thường. Kiểm tra file google-services.json khi build.',
        ),
    };
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.moss, AppColors.leafFixed],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.white,
                    )),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.onDarkMuted,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cloud Messaging: trạng thái theo [PushRegistrationController], nút bật khi chưa có quyền.
class _MessagingCard extends StatelessWidget {
  const _MessagingCard({required this.push, required this.link});
  final PushRegistrationController? push;
  final FirebaseLink link;

  @override
  Widget build(BuildContext context) {
    final state = push?.state ?? PushState.idle;
    final token = push?.token;
    final (label, severity, detail) = switch (state) {
      PushState.registered => (
          'Đang nhận',
          StatusSeverity.healthy,
          token == null ? null : 'Mã máy: ${token.substring(0, token.length.clamp(0, 12))}…',
        ),
      PushState.awaitingPermission => (
          'Chưa bật',
          StatusSeverity.attention,
          'Bật để nhận báo ca lệch, lời mời và nhắc đối soát.',
        ),
      PushState.denied => (
          'Bị từ chối',
          StatusSeverity.critical,
          'Quyền thông báo đang tắt trên máy.',
        ),
      PushState.failed => (
          'Lỗi',
          StatusSeverity.critical,
          'Chưa lưu được mã máy lên server. Thử lại khi có mạng.',
        ),
      PushState.unavailable => (
          'Không áp dụng',
          StatusSeverity.neutral,
          'Máy này chưa có Firebase.',
        ),
      PushState.idle => (
          'Chỉ chủ quán',
          StatusSeverity.neutral,
          'Thông báo đẩy gửi cho chủ quán đang đăng nhập.',
        ),
    };
    final canEnable = push != null &&
        (state == PushState.awaitingPermission ||
            state == PushState.denied ||
            state == PushState.failed);
    return _ServiceCard(
      icon: Icons.notifications_active_rounded,
      title: 'Cloud Messaging',
      description: 'Thông báo đẩy đến máy này khi app đang đóng.',
      status: StatusChip(label: label, severity: severity, compact: true),
      detail: detail,
      actionLabel: canEnable
          ? (state == PushState.failed ? 'Thử lại' : 'Bật thông báo')
          : null,
      onAction: () async {
        final result = await askPermission(context, AppPermission.notification);
        if (!context.mounted) return;
        if (result == PermissionAccess.granted) {
          await push?.enable();
          if (context.mounted) {
            showNotice(context, 'Đã bật thông báo đẩy.', kind: NoticeKind.success);
          }
        }
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.detail,
    this.toggle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget status;
  final String? detail;
  final ({bool value, ValueChanged<bool> onChanged})? toggle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: ForeCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                ForeIconBadge(icon: icon, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: AppTextStyles.cardTitle)),
                status,
              ]),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Text(description, style: AppTextStyles.caption),
              ),
              if (detail != null)
                Padding(
                  padding: const EdgeInsets.only(left: 52, top: 4),
                  child: Text(detail!,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textPrimary)),
                ),
              if (toggle != null || actionLabel != null) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 52),
                  child: Row(children: [
                    if (actionLabel != null)
                      SizedBox(
                        height: 38,
                        child: OutlinedButton(
                          onPressed: onAction,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            textStyle: const TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: Text(actionLabel!),
                        ),
                      ),
                    const Spacer(),
                    if (toggle != null)
                      Semantics(
                        label: 'Bật $title',
                        child: Switch(
                          value: toggle!.value,
                          onChanged: toggle!.onChanged,
                        ),
                      ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      );
}
