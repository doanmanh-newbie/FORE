part of 'owner_home_screen.dart';

class _OwnerDashboardLoading extends StatelessWidget {
  const _OwnerDashboardLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: const PageScaffold(
          children: [
            Row(
              children: [
                SkeletonBox(width: 150, height: 38),
                Spacer(),
                SkeletonBox(
                  width: 44,
                  height: 44,
                  radius: AppSizes.radiusChip,
                ),
              ],
            ),
            SizedBox(height: 28),
            SkeletonBox(width: 140, height: 34),
            SizedBox(height: 12),
            SkeletonBox(height: 142),
            SizedBox(height: 12),
            SkeletonBox(height: 126),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SkeletonBox(height: 94)),
                SizedBox(width: 12),
                Expanded(child: SkeletonBox(height: 94)),
              ],
            ),
            SizedBox(height: 18),
            SkeletonBox(height: 116),
          ],
        ),
      );
}
