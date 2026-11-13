import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/design/primary_button.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/notify.dart';
import '../../inventory/application/async_data.dart';
import '../../inventory/application/kho_format.dart';
import '../../inventory/presentation/kho_widgets.dart';
import '../application/audit_csv.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

/// "Nhật ký và dữ liệu": ai đã đổi gì, lúc nào. Xuất CSV bằng cách sao chép vào bộ nhớ tạm.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  static const _spans = [1, 7, 30];
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  int _span = 1; // chỉ số trong _spans
  String? _actor;
  late AsyncData<AuditFeed> _data = _make()..load();

  AsyncData<AuditFeed> _make() => AsyncData(() {
        final now = DateTime.now();
        final to = DateTime(now.year, now.month, now.day);
        final from = to.subtract(Duration(days: _spans[_span] - 1));
        // +1 ngày ở cuối để chắc chắn gồm cả hôm nay theo múi giờ quán.
        return _repo.auditFeed(from, to.add(const Duration(days: 1)),
            actorId: _actor);
      });

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  void _reload() {
    final old = _data;
    setState(() => _data = _make()..load());
    old.dispose();
  }

  Future<void> _copy(AuditFeed f) async {
    await Clipboard.setData(ClipboardData(text: auditCsv(f.events)));
    if (mounted) {
      showNotice(context,
          'Đã sao chép ${f.events.length} dòng dạng CSV. Dán vào Excel hoặc Google Sheets.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final f = _data.data;
          return KhoPage(
            title: 'Nhật ký và dữ liệu',
            subtitle: 'Mọi thay đổi quản trị đều có người ghi',
            bottom: f == null || f.events.isEmpty
                ? null
                : PrimaryButton(
                    label: 'Sao chép CSV · ${f.events.length} dòng',
                    onPressed: () => _copy(f)),
            body: AsyncView<AuditFeed>(
              source: _data,
              builder: (context, f) => [
                KhoChipBar(
                  labels: const ['Hôm nay', '7 ngày', '30 ngày'],
                  selected: _span,
                  onSelected: (i) {
                    _span = i;
                    _reload();
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  key: ValueKey(_actor),
                  initialValue: _actor,
                  isExpanded: true,
                  hint: const Text('Mọi người'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: Text('Mọi người')),
                    for (final a in f.actors)
                      DropdownMenuItem<String?>(
                          value: a.id, child: Text(a.name)),
                  ],
                  onChanged: (v) {
                    _actor = v;
                    _reload();
                  },
                ),
                const SizedBox(height: 12),
                if (f.events.isEmpty)
                  const KhoNote('Chưa có thay đổi nào trong khoảng này.'),
                for (final e in f.events)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KhoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(auditLabel(e.action),
                              style: AppTextStyles.cardTitle),
                          Text(
                              '${e.actorName ?? 'Hệ thống'} · ${formatDateTimeFull(e.at)}',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                  ),
                if (f.events.length >= 200)
                  const KhoNote(
                      'Chỉ hiện 200 dòng mới nhất. Thu hẹp khoảng ngày hoặc chọn một người để xem đủ.'),
              ],
            ),
          );
        },
      );
}
