import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../domain/owner_dashboard_models.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// Hộp thông báo chủ quán: lời mời và cảnh báo đối soát, có trạng thái đã đọc.
class OwnerNotificationsScreen extends StatefulWidget {
  const OwnerNotificationsScreen({
    super.key,
    required this.data,
    required this.onMarkRead,
  });

  final OwnerDashboardData data;
  final Future<void> Function(Iterable<OwnerNotification>) onMarkRead;

  @override
  State<OwnerNotificationsScreen> createState() =>
      _OwnerNotificationsScreenState();
}

class _OwnerNotificationsScreenState extends State<OwnerNotificationsScreen> {
  final Set<String> _readDuringSession = {};
  bool _marking = false;

  bool _isRead(OwnerNotification notice) =>
      notice.read || _readDuringSession.contains(notice.id);

  Future<void> _markRead(Iterable<OwnerNotification> notices) async {
    final unread = notices.where((notice) => !_isRead(notice)).toList();
    if (unread.isEmpty || _marking) return;
    setState(() => _marking = true);
    try {
      await widget.onMarkRead(unread);
      if (mounted) {
        setState(() => _readDuringSession.addAll(unread.map((n) => n.id)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Chưa lưu được trạng thái đã đọc. Thử lại.')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notices = widget.data.notifications;
    final unread = notices.where((notice) => !_isRead(notice)).toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: Text('Thông báo', style: AppTextStyles.headline),
        actions: [
          if (unread.isNotEmpty)
            TextButton(
              onPressed: _marking ? null : () => _markRead(unread),
              child: Text(_marking ? 'Đang lưu…' : 'Đánh dấu tất cả đã đọc'),
            ),
        ],
      ),
      body: LazyListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (notices.isEmpty)
            const _NoticeEmptyState()
          else
            for (final notice in notices)
              _NoticeCard(
                notice: notice,
                read: _isRead(notice),
                onTap: () => _markRead([notice]),
                onAction: () {
                  if (notice.kind == 'shift') {
                    final shiftId = notice.id.replaceFirst('shift:', '');
                    final reports = widget.data.reports.where(
                      (item) => '${item.shift['id']}' == shiftId,
                    );
                    if (reports.isNotEmpty) {
                      Navigator.pop(context, reports.first);
                    }
                  } else {
                    Navigator.pop(context, 'invites');
                  }
                },
              ),
        ],
      ),
    );
  }
}

class _NoticeEmptyState extends StatelessWidget {
  const _NoticeEmptyState();

  @override
  Widget build(BuildContext context) => const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(children: [
            Icon(Icons.notifications_none_rounded),
            SizedBox(height: 8),
            Text('Chưa có thông báo cần xử lý'),
            Text('Lời mời và ca có cảnh báo sẽ hiện ở đây.'),
          ]),
        ),
      );
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.notice,
    required this.read,
    required this.onTap,
    required this.onAction,
  });

  final OwnerNotification notice;
  final bool read;
  final VoidCallback onTap;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.surface,
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(
                    notice.kind == 'shift'
                        ? Icons.fact_check_outlined
                        : Icons.person_add_alt_1_outlined,
                    color: AppColors.brandAccent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(notice.title, style: AppTextStyles.title)),
                  Text(read ? 'Đã đọc' : 'Chưa đọc',
                      style: AppTextStyles.caption),
                ]),
                const SizedBox(height: 8),
                Text(notice.body, style: AppTextStyles.body),
                if (notice.occurredAt != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    '${notice.occurredAt!.day}/${notice.occurredAt!.month} · ${notice.occurredAt!.hour.toString().padLeft(2, '0')}:${notice.occurredAt!.minute.toString().padLeft(2, '0')}',
                    style: AppTextStyles.caption,
                  ),
                ],
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onAction,
                    child: Text(notice.kind == 'shift'
                        ? 'Xem đối soát'
                        : 'Xem lời mời'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
