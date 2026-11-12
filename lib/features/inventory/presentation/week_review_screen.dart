import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';
import 'waste_screens.dart';

/// "Một tuần yên tâm": 7 ngày gần nhất nhìn lại cho chủ, bằng con số thật từ đối soát ca và phiếu.
class WeekReviewScreen extends StatefulWidget {
  const WeekReviewScreen({super.key});

  @override
  State<WeekReviewScreen> createState() => _WeekReviewScreenState();
}

class _WeekReviewScreenState extends State<WeekReviewScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<WeekReview> _data = AsyncData(() {
    final now = DateTime.now();
    final to = DateTime(now.year, now.month, now.day);
    return _repo.weekReview(to.subtract(const Duration(days: 6)), to);
  })
    ..load();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Nhìn lại tuần',
        subtitle: 'Kho trong 7 ngày gần nhất',
        body: AsyncView<WeekReview>(
          source: _data,
          builder: (context, w) {
            final calm = w.countedDays > 0 && w.stableDays == w.countedDays;
            return [
              KhoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      w.countedDays == 0
                          ? 'Chưa có ca nào đóng trong tuần'
                          : calm
                              ? 'Một tuần yên tâm'
                              : 'Tuần này có ngày kho lệch',
                      style: AppTextStyles.pageTitle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      w.countedDays == 0
                          ? 'Đóng ca có đếm kho để có số liệu đối soát.'
                          : 'Kho ổn ${w.stableDays}/${w.countedDays} ngày (${formatRange(w.from, w.to)})',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              KhoCard(
                child: Column(children: [
                  LabelValueRow('Giá trị tồn hiện tại', formatVnd(w.stockValue),
                      strong: true),
                  LabelValueRow('Hao hụt đã ghi trong tuần', formatVnd(w.wasteValue)),
                  LabelValueRow('Kiểm kê đã duyệt', '${w.stocktakesApproved}'),
                  LabelValueRow('Phiếu nhập đã ghi', '${w.ordersConfirmed}'),
                ]),
              ),
              if (w.pendingStocktakes > 0) ...[
                const SizedBox(height: 12),
                KhoNote(
                    '${w.pendingStocktakes} phiếu kiểm kê đang chờ bạn duyệt.',
                    icon: Icons.fact_check_outlined),
              ],
              const SizedBox(height: 16),
              KhoCard(
                onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                        builder: (_) => const WasteOverviewScreen())),
                child: Row(children: [
                  const Expanded(
                      child: Text('Xem chi tiết hao hụt',
                          style: AppTextStyles.cardTitle)),
                  const Icon(Icons.chevron_right_rounded),
                ]),
              ),
              const SizedBox(height: AppSizes.pageBottomPadding),
            ];
          },
        ),
      );
}
