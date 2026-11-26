part of 'owner_home_screen.dart';

class _OwnerDashboardLoading extends StatelessWidget {
  const _OwnerDashboardLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: PageScaffold(
          padding: const EdgeInsets.only(bottom: AppSizes.pageBottomPadding),
          children: [
            // Chỗ của header (hàng tên quán + banner navy), để trang không nhảy khi dữ liệu về.
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(children: [
                  const Row(children: [
                    SkeletonBox(width: 44, height: 44, radius: 22),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonBox(height: 36)),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    height: 128,
                    decoration: BoxDecoration(
                      color: AppColors.moss,
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ]),
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
