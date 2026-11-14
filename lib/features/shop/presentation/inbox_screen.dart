import 'package:flutter/material.dart';
import 'package:fore/core/theme/theme_mode_toggle.dart';

import '../../../core/theme/app_text_styles.dart';
import 'invite_list.dart';

/// Hộp thư của thành viên: lời mời vào quán khác (người làm nhiều quán).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Hộp thư', style: AppTextStyles.heading),
        actions: const [ThemeModeToggle()],
      ),
      body: const InviteListView(
        emptyText:
            'Chưa có thông báo nào.\nKhi một chủ quán mời bạn, lời mời hiện ở đây.',
      ),
    );
  }
}
