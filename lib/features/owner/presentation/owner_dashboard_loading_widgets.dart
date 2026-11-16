part of 'owner_home_screen.dart';

class _OwnerDashboardLoading extends StatelessWidget {
  const _OwnerDashboardLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: PageScaffold(
          padding: const EdgeInsets.only(bottom: AppSizes.pageBottomPadding),
          children: [
            // Chỗ của header rêu, để trang không nhảy khi dữ liệu về.
            Container(
              height: 190,
              decoration: const BoxDecoration(
                color: AppColors.moss,
                borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(AppRadius.panel)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppSizes.screenGutter, 20, AppSizes.screenGutter, 0),
              child: Column(children: [
                SkeletonBox(height: 84),
                SizedBox(height: 12),
                SkeletonBox(height: 190),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: SkeletonBox(height: 104)),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 104)),
                  ],
                ),
                SizedBox(height: 18),
                SkeletonBox(height: 116),
              ]),
            ),
          ],
        ),
      );
}
