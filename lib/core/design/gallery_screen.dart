import 'package:flutter/material.dart';

import '../widgets/fore_card.dart' show ForeCard, SectionHeader;
import '../widgets/status_chip.dart';
import 'action_tile.dart';
import 'app_header.dart';
import 'app_sheet.dart';
import '../widgets/ops_icon.dart';
import 'colors.dart';
import 'empty_state.dart';
import 'error_state.dart';
import 'hero_card.dart';
import 'skeleton_box.dart';
import 'spacing.dart';
import 'status_pill.dart';
import 'tertiary_button.dart';
import 'typography.dart';
import 'primary_button.dart';
import 'secondary_button.dart';

void _noop() {}

/// Gallery chỉ bật ở debug để kiểm tra component và cỡ chữ trên thiết bị.
class DesignGalleryScreen extends StatelessWidget {
  const DesignGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: ListView(
          padding: EdgeInsets.zero,
          children: [
            const AppHeader(
              shopName: 'Fore · Tên quán mẫu rất dài để thử dấu ba chấm',
              unreadCount: 2,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding,
                12,
                AppSizes.pagePadding,
                AppSizes.pageBottomPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Thư viện giao diện', style: AppTextStyles.display),
                  const SizedBox(height: 12),
                  const SectionHeader(title: 'Màu và kiểu chữ'),
                  const SizedBox(height: 8),
                  const _ColorSamples(),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Trạng thái'),
                  const SizedBox(height: 8),
                  const Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      StatusPill(
                          label: 'Trong ngưỡng',
                          severity: StatusSeverity.healthy),
                      StatusPill(
                          label: 'Cần chú ý',
                          severity: StatusSeverity.attention),
                      StatusPill(
                          label: 'Lệch lớn', severity: StatusSeverity.critical),
                      StatusPill(
                          label: 'Đang chờ', severity: StatusSeverity.neutral),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Chỉ số và hành động'),
                  const SizedBox(height: 8),
                  const HeroCard(
                    title: 'Ca 28/10 · Minh Anh · Ca sáng',
                    status: StatusPill(
                      label: 'Lệch lớn',
                      severity: StatusSeverity.critical,
                    ),
                    primaryLabel: 'Xem chi tiết đối soát',
                    secondaryLabel: 'Ghi chú',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Thiếu 120.000đ'),
                        SizedBox(height: 4),
                        Text(
                            'Kiểm tra dòng tiền và ghi chú trước khi đánh dấu xử lý.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Danh sách và cần chú ý'),
                  const SizedBox(height: 8),
                  const ActionTile(
                    icon: Icon(Icons.people_outline),
                    title: 'Mời nhân viên',
                    subtitle: 'Thêm người vào quán',
                    onTap: null,
                  ),
                  const SizedBox(height: 16),
                  const SectionHeader(title: 'Nút và trạng thái tải'),
                  const SizedBox(height: 8),
                  const PrimaryButton(label: 'Lưu thay đổi', onPressed: null),
                  const SizedBox(height: 8),
                  const SecondaryButton(label: 'Hủy', onPressed: null),
                  const SizedBox(height: 8),
                  const TertiaryButton(label: 'Xem tất cả', onPressed: _noop),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Expanded(child: SkeletonBox(height: 72)),
                      SizedBox(width: 8),
                      Expanded(child: SkeletonBox(height: 72)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const ForeCard(
                    child: EmptyState(
                      icon: Icons.inbox_outlined,
                      title: 'Chưa có dữ liệu',
                      message:
                          'Nội dung sẽ xuất hiện sau khi quán có ca đầu tiên.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ForeCard(
                    child: ErrorState(
                      message: 'Kiểm tra kết nối rồi thử lại.',
                      onRetry: _noop,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const ForeCard(
                    padding: EdgeInsets.zero,
                    child: AppSheet(
                      title: 'Ghi chú ca',
                      child: Text('Nội dung sheet và khoảng đệm an toàn.'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const BottomNavSample(),
                  const SizedBox(height: 12),
                  Text('Số tiền dùng chữ số thẳng hàng',
                      style: AppTextStyles.caption),
                  const SizedBox(height: 4),
                  Text('−120.000đ · 4.670 ml · 2,16 kg',
                      style: AppTextStyles.metric),
                ],
              ),
            ),
          ],
        ),
      );
}

class BottomNavSample extends StatelessWidget {
  const BottomNavSample({super.key});

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(
              label: 'Tổng quan', icon: ForeIcon('assets/icons/home.svg')),
          NavigationDestination(
              label: 'Đối soát', icon: ForeIcon('assets/icons/package.svg')),
          NavigationDestination(
              label: 'Thêm', icon: ForeIcon('assets/icons/plus.svg')),
        ],
      );
}

class _ColorSamples extends StatelessWidget {
  const _ColorSamples();

  @override
  Widget build(BuildContext context) {
    final samples = <(String, Color)>[
      ('Mực', AppColors.brand),
      ('Teal', AppColors.brandAccent),
      ('Nền', AppColors.background),
      ('Xanh · ổn', AppColors.statusHealthy),
      ('Vàng · chú ý', AppColors.statusAttention),
      ('Đỏ · lệch', AppColors.statusCritical),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (label, color) in samples)
          Container(
            width: 100,
            height: 58,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(AppSizes.radius),
              border: Border.all(color: AppColors.border),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: AppTextStyles.micro.copyWith(
                color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                    ? Colors.white
                    : AppPalette.light.brand,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }
}
