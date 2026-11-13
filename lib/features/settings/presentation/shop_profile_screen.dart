import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_routes.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../auth/application/session_controller.dart';
import '../../inventory/application/async_data.dart';
import '../../inventory/presentation/kho_widgets.dart';
import '../../shift/application/shift_controller.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// "Hồ sơ và thông tin quán": tên, liên hệ, giờ mở cửa, thông tin dùng cho hóa đơn.
class ShopProfileScreen extends StatefulWidget {
  const ShopProfileScreen({super.key});

  @override
  State<ShopProfileScreen> createState() => _ShopProfileScreenState();
}

class _ShopProfileScreenState extends State<ShopProfileScreen> {
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  final _name = TextEditingController();
  final _legal = TextEditingController();
  final _tax = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  bool _openDaily = true;
  TimeOfDay _open = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _close = const TimeOfDay(hour: 22, minute: 0);
  ShopProfile? _profile;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _legal, _tax, _email, _phone, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  static TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(
        hour: int.tryParse(p.first) ?? 6,
        minute: p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final p = await guarded(context, _repo.shopProfile);
    if (!mounted) return;
    setState(() {
      _profile = p;
      if (p != null) {
        _name.text = p.name;
        _legal.text = p.legalName ?? '';
        _tax.text = p.taxCode ?? '';
        _email.text = p.email ?? '';
        _phone.text = p.phone ?? '';
        _address.text = p.address ?? '';
        _openDaily = p.openDaily;
        _open = _parse(p.openTime);
        _close = _parse(p.closeTime);
      }
      _loading = false;
    });
  }

  Future<void> _pick(bool open) async {
    final t = await showTimePicker(
        context: context, initialTime: open ? _open : _close);
    if (t != null && mounted) setState(() => open ? _open = t : _close = t);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return showNotice(context, 'Hãy nhập tên quán.');
    }
    if (_address.text.trim().isEmpty) {
      return showNotice(context, 'Hãy nhập địa chỉ hiển thị của quán.');
    }
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    setState(() => _busy = true);
    final saved = await guarded(
      context,
      () => _repo.saveShopProfile(ShopProfileDraft(
        name: _name.text.trim(),
        address: _address.text.trim(),
        legalName: t(_legal),
        taxCode: t(_tax),
        email: t(_email),
        phone: t(_phone),
        openDaily: _openDaily,
        openTime: _fmt(_open),
        closeTime: _fmt(_close),
      )),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (saved != null) {
      setState(() => _profile = saved);
      showNotice(context, 'Đã lưu hồ sơ quán.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    final canEdit = p?.canEdit ?? false;
    return KhoPage(
      title: 'Hồ sơ và thông tin quán',
      subtitle: p == null ? null : 'Mã quán ${p.code}',
      bottom: _loading || !canEdit
          ? null
          : PrimaryButton(label: 'Lưu hồ sơ', loading: _busy, onPressed: _save),
      body: _loading
          ? const KhoSkeleton()
          : LazyListView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              children: [
                if (!canEdit)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: KhoNote('Bạn chỉ xem được. Nhờ chủ quán cấp quyền "Sửa hồ sơ quán".'),
                  ),
                if (p != null && p.missingInvoiceInfo)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: KhoNote(
                        'Còn thiếu tên pháp lý, mã số thuế hoặc địa chỉ. Bổ sung khi bạn cần thông tin này trên hóa đơn.',
                        icon: Icons.receipt_long_outlined),
                  ),
                AppTextField(
                    label: 'Tên quán *', controller: _name, enabled: canEdit),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'Địa chỉ hiển thị *',
                    controller: _address,
                    enabled: canEdit),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'Số điện thoại quán',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    enabled: canEdit),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'Email liên hệ',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    enabled: canEdit),
                const KhoSectionTitle('Thông tin pháp lý (dùng cho hóa đơn)'),
                AppTextField(
                    label: 'Tên pháp lý / hộ kinh doanh',
                    controller: _legal,
                    enabled: canEdit),
                const SizedBox(height: 12),
                AppTextField(
                    label: 'Mã số thuế',
                    controller: _tax,
                    hint: '10 số, hoặc 10 số-3 số chi nhánh',
                    keyboardType: TextInputType.number,
                    enabled: canEdit),
                const KhoSectionTitle('Giờ mở cửa'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _openDaily,
                  onChanged: canEdit ? (v) => setState(() => _openDaily = v) : null,
                  title: const Text('Mở cửa mỗi ngày'),
                ),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canEdit ? () => _pick(true) : null,
                      child: Text('Mở ${_fmt(_open)}'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: canEdit ? () => _pick(false) : null,
                      child: Text('Đóng ${_fmt(_close)}'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Múi giờ: ${p?.timezone ?? 'Asia/Ho_Chi_Minh'}',
                    style: AppTextStyles.caption),
              ],
            ),
    );
  }
}

/// "Quản lý chi nhánh": các quán tôi là chủ. Dữ liệu từng quán tách biệt, không gộp.
class BranchesScreen extends StatefulWidget {
  const BranchesScreen({super.key});

  @override
  State<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends State<BranchesScreen> {
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  late final AsyncData<List<Branch>> _data = AsyncData(_repo.branches)..load();
  String? _switching;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _switchTo(Branch b) async {
    if (b.isCurrent || _switching != null) return;
    final session = context.read<SessionController>();
    final shift = context.read<ShiftController>();
    final navigator = Navigator.of(context);
    setState(() => _switching = b.shopId);
    try {
      final failure = await session.chooseShop(b.shopId);
      if (failure != null) throw failure;
      shift.load();
      if (!mounted) return;
      navigator.pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
    } on AppFailure catch (f) {
      if (!mounted) return;
      setState(() => _switching = null);
      showFailure(context, f);
    }
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Quản lý chi nhánh',
        subtitle: 'Mỗi quán là một cuốn sổ riêng, không gộp dữ liệu',
        body: AsyncView<List<Branch>>(
          source: _data,
          builder: (context, list) => [
            for (final b in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KhoCard(
                  onTap: b.isCurrent ? null : () => _switchTo(b),
                  child: Row(children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(b.name, style: AppTextStyles.cardTitle),
                          Text(
                              [
                                b.code,
                                if (b.address != null) b.address!,
                              ].join(' · '),
                              style: AppTextStyles.caption),
                          Text(
                              '${b.activeMembers} người đang làm${b.pendingInvites > 0 ? ' · ${b.pendingInvites} lời mời' : ''}',
                              style: AppTextStyles.caption),
                        ],
                      ),
                    ),
                    if (_switching == b.shopId)
                      const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else if (b.isCurrent)
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.statusHealthy)
                    else
                      Icon(Icons.chevron_right_rounded,
                          color: AppColors.textSecondary),
                  ]),
                ),
              ),
            const KhoNote(
                'Chạm vào quán khác để chuyển sang quán đó, rồi sửa hồ sơ, nhân sự, khu vực và bàn của quán ấy.'),
          ],
        ),
      );
}
