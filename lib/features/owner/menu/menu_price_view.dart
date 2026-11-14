import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import 'menu_format.dart';
import 'menu_models.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// Đổi giá bán theo từng size, áp dụng ngay hoặc hẹn giờ.
class PriceChangePage extends StatefulWidget {
  const PriceChangePage({super.key, required this.detail});

  final ItemDetail detail;

  @override
  State<PriceChangePage> createState() => _PriceChangePageState();
}

class _PriceChangePageState extends State<PriceChangePage> {
  late final List<SizeDetail> _sizes;
  late final Map<String, TextEditingController> _controllers;
  bool _immediate = true;
  late DateTime _when;
  bool _saving = false;
  Object? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _sizes = widget.detail.activeSizes;
    _controllers = {
      for (final s in _sizes) s.id: TextEditingController(text: '${s.price}'),
    };
    _when = nextBusinessDayStart();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  int? _newPrice(SizeDetail s) {
    final v = int.tryParse(_controllers[s.id]!.text.trim());
    return v;
  }

  String? _errorFor(SizeDetail s) {
    final v = _newPrice(s);
    if (v == null || v <= 0) return 'Nhập giá lớn hơn 0';
    if (v % 500 != 0) return 'Nên làm tròn đến 500đ';
    return null;
  }

  List<({String sizeId, int price})> get _changes => [
        for (final s in _sizes)
          if (_errorFor(s) == null && _newPrice(s) != s.price)
            (sizeId: s.id, price: _newPrice(s)!),
      ];

  bool get _valid =>
      _sizes.every((s) => _newPrice(s) != null && _newPrice(s)! > 0);

  Future<void> _save() async {
    final changes = _changes;
    if (changes.isEmpty) return;
    final store = context.read<MenuStore>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await store.changePrices(changes, effectiveFrom: _immediate ? null : _when);
      if (mounted) setState(() => _done = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return MenuPage(
        title: _immediate ? 'Đã đổi giá' : 'Đã hẹn đổi giá',
        subtitle: widget.detail.name,
        showBack: false,
        primary: MenuPrimaryButton(
          label: 'Về chi tiết món',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        children: [
          MenuBanner(
            kind: BannerKind.success,
            title: _immediate
                ? 'Giá mới áp dụng từ bây giờ'
                : 'Giá mới áp dụng lúc ${dateTimeLong(_when)}',
            body: 'Bill đã thanh toán giữ nguyên giá cũ.',
          ),
        ],
      );
    }
    final changes = _changes;
    return MenuPage(
      title: 'Đổi giá bán',
      subtitle: '${widget.detail.name} · Mỗi size một giá',
      primary: MenuPrimaryButton(
        label: changes.isEmpty
            ? 'Chưa có giá nào thay đổi'
            : _immediate
                ? 'Đổi giá ${changes.length} size ngay'
                : 'Hẹn đổi giá ${changes.length} size',
        loading: _saving,
        onPressed: changes.isEmpty || !_valid ? null : _save,
      ),
      children: [
        if (_error != null)
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa đổi được giá',
            body: menuErrorMessage(_error!),
          ),
        for (final s in _sizes)
          MenuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Size ${s.name}', style: AppTextStyles.cardTitle),
                    ),
                    Text('Hiện tại ${formatVnd(s.price)}', style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _controllers[s.id],
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(7),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Giá mới',
                    suffixText: 'đ',
                    errorText: _errorFor(s),
                  ),
                ),
                if (s.cost != null && _newPrice(s) != null && _newPrice(s)! > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Lãi gộp mới ${formatVnd(_newPrice(s)! - s.cost!)} · ${formatPct((_newPrice(s)! - s.cost!) * 100 / _newPrice(s)!)}'
                    ' (hiện ${s.marginPct == null ? '—' : formatPct(s.marginPct!)})',
                    style: AppTextStyles.caption,
                  ),
                ] else if (s.cost == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Chưa có công thức nên chưa tính được lãi gộp.',
                        style: AppTextStyles.caption),
                  ),
                if (s.pendingPrice != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Đang có lịch: ${formatVnd(s.pendingPrice!.newPrice)} lúc ${dateTimeLabel(s.pendingPrice!.effectiveFrom)}. Đổi giá mới sẽ thay lịch này.',
                      style: AppTextStyles.caption,
                    ),
                  ),
              ],
            ),
          ),
        ApplyModePicker(
          immediate: _immediate,
          onChanged: _saving ? (_) {} : (v) => setState(() => _immediate = v),
        ),
        if (!_immediate)
          DateTimeFields(value: _when, onChanged: (v) => setState(() => _when = v)),
      ],
    );
  }
}
