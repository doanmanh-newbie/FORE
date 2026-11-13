import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/app_sheet.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/secondary_button.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../../inventory/application/async_data.dart';
import '../../inventory/presentation/kho_widgets.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';

/// "Khu vực và bàn": thêm, đổi tên, tạm ẩn. Bàn đang có đơn mở thì không ẩn hay chuyển khu vực được.
class FloorScreen extends StatefulWidget {
  const FloorScreen({super.key});

  @override
  State<FloorScreen> createState() => _FloorScreenState();
}

class _FloorScreenState extends State<FloorScreen> {
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  late final AsyncData<List<FloorArea>> _data = AsyncData(_repo.floor)..load();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    final ok = await guarded(context, () async {
      await action();
      return true;
    });
    if (ok == true && mounted) {
      showNotice(context, done);
      _data.load(silent: true);
    }
  }

  Future<void> _editArea(FloorArea? a) async {
    final c = TextEditingController(text: a?.name ?? '');
    final name = await AppSheet.show<String>(
      context,
      builder: (ctx) => AppSheet(
        title: a == null ? 'Thêm khu vực' : 'Đổi tên khu vực',
        footer: PrimaryButton(
            label: 'Lưu', onPressed: () => Navigator.pop(ctx, c.text)),
        child: AppTextField(
            label: 'Tên khu vực', controller: c, hint: 'Ví dụ: Tầng trệt'),
      ),
    );
    c.dispose();
    if (name == null || name.trim().isEmpty || !mounted) return;
    await _run(() async {
      await _repo.saveArea(a?.id, name.trim());
    }, a == null ? 'Đã thêm khu vực.' : 'Đã đổi tên khu vực.');
  }

  Future<void> _editTable(FloorArea area, FloorTable? t,
      List<FloorArea> allAreas) async {
    final name = TextEditingController(text: t?.name ?? '');
    final seats = TextEditingController(text: '${t?.seats ?? 2}');
    var areaId = area.id;
    final go = await AppSheet.show<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AppSheet(
          title: t == null ? 'Thêm bàn' : 'Sửa bàn ${t.name}',
          footer: PrimaryButton(
              label: 'Lưu', onPressed: () => Navigator.pop(ctx, true)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppTextField(label: 'Tên bàn', controller: name, hint: 'B01'),
            const SizedBox(height: 12),
            AppTextField(
                label: 'Số chỗ',
                controller: seats,
                keyboardType: TextInputType.number),
            if (t != null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: areaId,
                isExpanded: true,
                items: [
                  for (final a in allAreas.where((a) => a.active))
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: t.inUse ? null : (v) => setS(() => areaId = v ?? areaId),
              ),
              if (t.inUse)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Bàn đang có đơn nên chưa chuyển khu vực được.',
                      style: AppTextStyles.caption),
                ),
            ],
          ]),
        ),
      ),
    );
    final nameText = name.text.trim();
    final seatsValue = int.tryParse(seats.text.trim());
    name.dispose();
    seats.dispose();
    if (go != true || !mounted) return;
    if (nameText.isEmpty) return showNotice(context, 'Hãy nhập tên bàn.');
    if (seatsValue == null || seatsValue < 1 || seatsValue > 50) {
      return showNotice(context, 'Số chỗ từ 1 đến 50.');
    }
    await _run(() async {
      await _repo.saveTable(
          id: t?.id, areaId: areaId, name: nameText, seats: seatsValue);
    }, t == null ? 'Đã thêm bàn.' : 'Đã lưu bàn.');
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Khu vực và bàn',
        subtitle: 'Thiết lập bố trí quán',
        bottom: PrimaryButton(
            label: 'Thêm khu vực', onPressed: () => _editArea(null)),
        body: AsyncView<List<FloorArea>>(
          source: _data,
          builder: (context, areas) => [
            if (areas.isEmpty)
              const KhoNote('Chưa có khu vực nào. Thêm khu vực đầu tiên rồi thêm bàn vào đó.'),
            for (final a in areas) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: KhoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name, style: AppTextStyles.cardTitle),
                              Text(
                                  a.active
                                      ? '${a.activeTables} bàn · ${a.seatTotal} chỗ'
                                      : 'Đang tạm ẩn',
                                  style: AppTextStyles.caption),
                            ],
                          ),
                        ),
                        IconButton(
                            tooltip: 'Đổi tên',
                            onPressed: () => _editArea(a),
                            icon: const Icon(Icons.edit_outlined)),
                        IconButton(
                          tooltip: a.active ? 'Tạm ẩn khu vực' : 'Hiện lại',
                          onPressed: () => _run(
                              () => _repo.setAreaActive(a.id, !a.active),
                              a.active ? 'Đã tạm ẩn khu vực.' : 'Đã hiện lại khu vực.'),
                          icon: Icon(a.active
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined),
                        ),
                      ]),
                      Divider(color: AppColors.cardBorder),
                      for (final t in a.tables)
                        InkWell(
                          onTap: () => _editTable(a, t, areas),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(children: [
                              Expanded(
                                child: Text(
                                  '${t.name} · ${t.seats} chỗ',
                                  style: t.active
                                      ? AppTextStyles.body
                                      : AppTextStyles.caption,
                                ),
                              ),
                              if (t.inUse)
                                const StatusChip(
                                    label: 'Đang có đơn',
                                    severity: StatusSeverity.attention,
                                    compact: true)
                              else if (!t.active)
                                const StatusChip(
                                    label: 'Tạm ẩn',
                                    severity: StatusSeverity.neutral,
                                    compact: true),
                              IconButton(
                                tooltip: t.active ? 'Tạm ẩn bàn' : 'Hiện lại bàn',
                                onPressed: () => _run(
                                    () => _repo.setTableActive(t.id, !t.active),
                                    t.active ? 'Đã tạm ẩn bàn.' : 'Đã hiện lại bàn.'),
                                icon: Icon(t.active
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined),
                              ),
                            ]),
                          ),
                        ),
                      if (a.active)
                        SecondaryButton(
                            label: 'Thêm bàn vào ${a.name}',
                            onPressed: () => _editTable(a, null, areas)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
