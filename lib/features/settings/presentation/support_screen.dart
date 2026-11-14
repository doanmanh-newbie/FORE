import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/primary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../inventory/application/kho_format.dart';
import '../../inventory/presentation/kho_widgets.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// "Hỗ trợ và cập nhật": gửi yêu cầu kèm (hoặc không kèm) thông tin chẩn đoán, xem các yêu cầu đã gửi.
/// Yêu cầu được lưu lại với mã SP-xxxx; ứng dụng không hứa thời gian phản hồi.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  static const _appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  final _message = TextEditingController();
  SupportTopic _topic = SupportTopic.setup;
  bool _callback = false;
  bool _diagnostics = false;
  bool _busy = false;
  List<SupportTicket> _tickets = const [];

  /// Đúng những gì sẽ được gửi kèm nếu bạn đồng ý: không có tên, số điện thoại hay dữ liệu bán hàng.
  Map<String, dynamic> get _diag => {
        'app_version': _appVersion,
        'platform': defaultTargetPlatform.name,
      };

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    final t = await guarded(context, _repo.supportTickets);
    if (mounted && t != null) setState(() => _tickets = t);
  }

  Future<void> _send() async {
    if (_message.text.trim().length < 5) {
      return showNotice(context, 'Hãy mô tả vấn đề (ít nhất 5 ký tự).');
    }
    setState(() => _busy = true);
    final r = await guarded(
      context,
      () => _repo.createSupport(
        topic: _topic,
        message: _message.text,
        callback: _callback,
        shareDiagnostics: _diagnostics,
        diagnostics: _diag,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      _message.clear();
      showNotice(context,
          'Đã ghi nhận yêu cầu ${r.code}${r.diagnosticsSent ? ' kèm thông tin chẩn đoán' : ''}.');
      _loadTickets();
    }
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Hỗ trợ và cập nhật',
        subtitle: 'Phiên bản ứng dụng: $_appVersion',
        bottom: PrimaryButton(
            label: 'Gửi yêu cầu', loading: _busy, onPressed: _send),
        body: LazyListView(
          padding: const EdgeInsets.all(AppSizes.pagePadding),
          children: [
            Text('Chủ đề', style: AppTextStyles.label),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final t in SupportTopic.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _topic == t,
                  onSelected: (_) => setState(() => _topic = t),
                ),
            ]),
            const SizedBox(height: 14),
            AppTextField(
              label: 'Bạn cần giúp gì? *',
              controller: _message,
              hint: 'Mô tả ngắn: đang làm gì, thấy gì',
              maxLines: 4,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _callback,
              onChanged: (v) => setState(() => _callback = v),
              title: const Text('Nhờ gọi lại'),
              subtitle: const Text('Ghi chú là bạn muốn được liên hệ qua điện thoại'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _diagnostics,
              onChanged: (v) => setState(() => _diagnostics = v),
              title: const Text('Gửi kèm thông tin chẩn đoán'),
              subtitle: const Text('Mặc định tắt. Bạn xem được chính xác nội dung bên dưới'),
            ),
            if (_diagnostics)
              KhoCard(
                child: Text(
                  _diag.entries.map((e) => '${e.key}: ${e.value}').join('\n'),
                  style: AppTextStyles.caption,
                ),
              ),
            const KhoSectionTitle('Yêu cầu đã gửi'),
            if (_tickets.isEmpty)
              const KhoNote('Bạn chưa gửi yêu cầu nào.'),
            for (final t in _tickets)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KhoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${t.code} · ${t.topic.label}',
                          style: AppTextStyles.cardTitle),
                      Text(t.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption),
                      if (t.createdAt != null)
                        Text(formatDateTimeFull(t.createdAt!),
                            style: AppTextStyles.caption),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
}
