import 'package:flutter/material.dart';
import 'package:fore/core/theme/theme_mode_toggle.dart';

import '../../../core/design/colors.dart';
import 'invite_list.dart';
import 'join_by_code_card.dart';

/// Hộp thư của thành viên: lời mời vào quán khác (người làm nhiều quán).
class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hộp thư'),
        actions: const [ThemeModeToggle(color: AppColors.white)],
      ),
      body: const InviteListView(
        header: Padding(
          padding: EdgeInsets.only(bottom: 16),
          child: JoinByCodeCard(),
        ),
        emptyText:
            'Chưa có thông báo nào.\nKhi một chủ quán mời bạn, lời mời hiện ở đây.',
      ),
    );
  }
}
