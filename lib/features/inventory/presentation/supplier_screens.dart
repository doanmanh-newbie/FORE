import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/secondary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/async_data.dart';
import '../application/kho_format.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';
import 'purchase_screens.dart';

class SupplierListScreen extends StatefulWidget {
  const SupplierListScreen({super.key});

  @override
  State<SupplierListScreen> createState() => _SupplierListScreenState();
}

class _SupplierListScreenState extends State<SupplierListScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<List<SupplierSummary>> _data =
      AsyncData(_repo.suppliers)..load();
  final _search = TextEditingController();
  int _tab = 0;

  @override
  void dispose() {
    _data.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _data.load(silent: true);
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Nhà cung cấp',
        subtitle: 'Những người giao hàng · Một liên hệ, đúng quán',
        bottom: PrimaryButton(
            label: 'Thêm nhà cung cấp',
            onPressed: () => _open(const SupplierFormScreen())),
        body: ListenableBuilder(
          listenable: _search,
          builder: (context, _) => AsyncView<List<SupplierSummary>>(
            source: _data,
            builder: (context, all) {
              final q = _search.text.trim().toLowerCase();
              final active = all.where((s) => s.active).length;
              final list = all.where((s) {
                if (s.active != (_tab == 0)) return false;
                return q.isEmpty ||
                    s.name.toLowerCase().contains(q) ||
                    (s.phone ?? '').replaceAll(' ', '').contains(q.replaceAll(' ', ''));
              }).toList();
              return [
                KhoSearchField(
                    controller: _search, hint: 'Tìm tên hoặc số điện thoại…'),
                const SizedBox(height: 12),
                KhoChipBar(
                  labels: [
                    'Đang hợp tác · $active',
                    'Tạm ngừng · ${all.length - active}'
                  ],
                  selected: _tab,
                  onSelected: (i) => setState(() => _tab = i),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const KhoNote('Chưa có nhà cung cấp nào ở mục này.'),
                for (final s in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: KhoCard(
                      onTap: () =>
                          _open(SupplierDetailScreen(supplierId: s.id)),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: AppTextStyles.cardTitle),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (s.contactName != null) s.contactName!,
                                  if (s.phone != null) s.phone!,
                                ].join(' · '),
                                style: AppTextStyles.caption,
                              ),
                              if (s.items.isNotEmpty)
                                Text(s.items.join(' · '),
                                    style: AppTextStyles.caption),
                              Text(
                                s.lastOrderAt == null
                                    ? 'Chưa có lần nhập nào'
                                    : 'Lần nhập gần nhất: ${formatDateTimeFull(s.lastOrderAt!)}',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textSecondary),
                      ]),
                    ),
                  ),
              ];
            },
          ),
        ),
      );
}

class SupplierDetailScreen extends StatefulWidget {
  const SupplierDetailScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<SupplierDetail> _data =
      AsyncData(() => _repo.supplierDetail(widget.supplierId))..load();

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push<void>(MaterialPageRoute<void>(builder: (_) => page));
    if (mounted) _data.load(silent: true);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final s = _data.data;
          return KhoPage(
            title: s?.name ?? 'Nhà cung cấp',
            subtitle: s == null
                ? null
                : [
                    if (s.items.isNotEmpty)
                      s.items.take(2).map((e) => e.name).join(' & '),
                    if (s.leadDays >= 0) 'giao sau ${s.leadDays} ngày',
                  ].join(' · '),
            bottom: s == null
                ? null
                : PrimaryButton(
                    label: 'Nhập hàng từ nhà cung cấp',
                    onPressed: s.active
                        ? () => _open(
                            PoFormScreen(isOwner: true, presetSupplierId: s.id))
                        : null,
                  ),
            body: AsyncView<SupplierDetail>(
              source: _data,
              builder: (context, s) => _content(s),
            ),
          );
        },
      );

  List<Widget> _content(SupplierDetail s) => [
        KhoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(child: KhoEyebrow('Liên hệ giao hàng')),
                if (!s.active)
                  const StatusChip(
                      label: 'Tạm ngừng',
                      severity: StatusSeverity.neutral,
                      compact: true),
              ]),
              const SizedBox(height: 8),
              LabelValueRow('Người liên hệ', s.contactName ?? '—', strong: true),
              LabelValueRow('Điện thoại', s.phone ?? '—'),
              if (s.email != null) LabelValueRow('Email', s.email!),
              if (s.address != null) LabelValueRow('Địa chỉ', s.address!),
              LabelValueRow(
                  'Lịch giao',
                  [
                    'Giao sau ${s.leadDays} ngày',
                    if (s.deliveryWindow != null) s.deliveryWindow!,
                  ].join(' · ')),
              if (s.orderCutoff != null)
                LabelValueRow('Chốt đặt hàng', 'Trước ${s.orderCutoff}'),
              if (s.note != null) ...[
                const SizedBox(height: 6),
                Text(s.note!, style: AppTextStyles.caption),
              ],
              const SizedBox(height: 8),
              SecondaryButton(
                  label: 'Sửa thông tin liên hệ',
                  onPressed: () =>
                      _open(SupplierFormScreen(supplierId: s.id))),
            ],
          ),
        ),
        const KhoSectionTitle('Mặt hàng & giá gần nhất'),
        if (s.items.isEmpty)
          const KhoNote(
              'Chưa gán mặt hàng nào. Đặt nhà cung cấp mặc định khi sửa nguyên liệu.')
        else
          KhoCard(
            child: Column(children: [
              for (final i in s.items)
                LabelValueRow(
                  i.name,
                  i.lastPrice == null
                      ? 'Chưa có giá'
                      : '${formatKhoPrice(i.lastPrice, i.unit)}${i.lastAt == null ? '' : ' · ${formatShortDate(i.lastAt!)}'}',
                ),
            ]),
          ),
        const KhoSectionTitle('Lịch sử giao'),
        if (s.orders.isEmpty)
          const KhoNote('Chưa có phiếu nhập nào từ nhà cung cấp này.')
        else
          for (final o in s.orders)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KhoCard(
                onTap: () => _open(PoDetailScreen(orderId: o.id)),
                child: Row(children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${o.code} · ${o.receivedAt == null ? '' : formatShortDate(o.receivedAt!)}',
                            style: AppTextStyles.cardTitle),
                        Text(
                            '${o.lineCount} dòng${o.needsPricing ? ' · chờ bổ sung giá' : ''}',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  Text(
                      o.totalAmount == null
                          ? 'Chưa gồm giá'
                          : formatVnd(o.totalAmount!),
                      style: AppTextStyles.bodyStrong),
                ]),
              ),
            ),
        const SizedBox(height: 8),
        SecondaryButton(
          label: s.active ? 'Tạm ngừng hợp tác' : 'Hợp tác lại',
          onPressed: () async {
            final done = await guarded(context, () async {
              await _repo.setSupplierActive(s.id, !s.active);
              return true;
            });
            if (done == true) _data.load(silent: true);
          },
        ),
      ];
}

class SupplierFormScreen extends StatefulWidget {
  const SupplierFormScreen({super.key, this.supplierId});

  final String? supplierId;

  @override
  State<SupplierFormScreen> createState() => _SupplierFormScreenState();
}

class _SupplierFormScreenState extends State<SupplierFormScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  final _name = TextEditingController();
  final _contact = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _lead = TextEditingController(text: '1');
  final _window = TextEditingController();
  final _cutoff = TextEditingController();
  final _note = TextEditingController();
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _name, _contact, _phone, _email, _address, _lead, _window, _cutoff, _note
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.supplierId;
    if (id != null) {
      final s = await guarded(context, () => _repo.supplierDetail(id));
      if (!mounted) return;
      if (s != null) {
        _name.text = s.name;
        _contact.text = s.contactName ?? '';
        _phone.text = s.phone ?? '';
        _email.text = s.email ?? '';
        _address.text = s.address ?? '';
        _lead.text = '${s.leadDays}';
        _window.text = s.deliveryWindow ?? '';
        _cutoff.text = s.orderCutoff ?? '';
        _note.text = s.note ?? '';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      return showNotice(context, 'Hãy nhập tên nhà cung cấp.');
    }
    final lead = int.tryParse(_lead.text.trim());
    if (lead == null || lead < 0 || lead > 30) {
      return showNotice(context, 'Số ngày giao hàng từ 0 đến 30.');
    }
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    setState(() => _busy = true);
    final id = await guarded(
      context,
      () => _repo.saveSupplier(
        widget.supplierId,
        SupplierDraft(
          name: _name.text.trim(),
          contactName: t(_contact),
          phone: t(_phone),
          email: t(_email),
          address: t(_address),
          leadDays: lead,
          deliveryWindow: t(_window),
          orderCutoff: t(_cutoff),
          note: t(_note),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (id != null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: widget.supplierId == null
            ? 'Thêm nhà cung cấp'
            : 'Sửa thông tin liên hệ',
        bottom: _loading
            ? null
            : PrimaryButton(label: 'Lưu', loading: _busy, onPressed: _save),
        body: _loading
            ? const KhoSkeleton()
            : ListView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                children: [
                  AppTextField(label: 'Tên nhà cung cấp *', controller: _name),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Người liên hệ', controller: _contact),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'Số điện thoại',
                      controller: _phone,
                      keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'Email',
                      controller: _email,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Địa chỉ', controller: _address),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'Giao sau (ngày)',
                      controller: _lead,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'Khung giờ giao',
                      controller: _window,
                      hint: '07:00–10:00'),
                  const SizedBox(height: 12),
                  AppTextField(
                      label: 'Chốt đặt hàng trước',
                      controller: _cutoff,
                      hint: '16:00'),
                  const SizedBox(height: 12),
                  AppTextField(label: 'Ghi chú', controller: _note),
                ],
              ),
      );
}
