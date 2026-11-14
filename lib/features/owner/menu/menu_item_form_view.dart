import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/format.dart';
import '../../../core/widgets/status_chip.dart';
import 'menu_category_views.dart';
import 'menu_format.dart';
import 'menu_models.dart';
import 'menu_recipe_views.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

class _SizeRow {
  _SizeRow({this.id, String name = '', int? price, this.locked = false})
      : name = TextEditingController(text: name),
        price = TextEditingController(
            text: price == null ? '' : formatThousands(price));

  /// Có id nghĩa là size đã có trong database (chỉ ẩn được, giá đổi ở màn Đổi giá).
  final String? id;
  final bool locked;
  final TextEditingController name;
  final TextEditingController price;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

/// Món mới (lưu bản nháp) hoặc sửa thông tin món đã có: tên, nhóm, size.
class MenuItemFormPage extends StatefulWidget {
  const MenuItemFormPage({super.key, this.existing});

  final ItemDetail? existing;

  @override
  State<MenuItemFormPage> createState() => _MenuItemFormPageState();
}

class _MenuItemFormPageState extends State<MenuItemFormPage> {
  late final TextEditingController _name;
  String? _category;
  final List<_SizeRow> _rows = [];
  final Set<String> _removed = {};
  bool _submitted = false;
  bool _saving = false;
  String? _savedItemId;
  List<({String name, int price})> _savedSizes = const [];

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _category = existing?.category;
    if (existing != null) {
      for (final s in existing.activeSizes) {
        _rows.add(_SizeRow(id: s.id, name: s.name, price: s.price, locked: true));
      }
    } else {
      _rows.add(_SizeRow(name: 'S'));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  List<_SizeRow> get _liveRows =>
      _rows.where((r) => r.id == null || !_removed.contains(r.id)).toList();

  /// Lỗi theo ô: khóa "name", "size<i>.name", "size<i>.price".
  Map<String, String> _errors(MenuStore store) {
    final errors = <String, String>{};
    final name = _name.text.trim();
    if (name.isEmpty) {
      errors['name'] = 'Nhập tên món để nhận biết trong thực đơn.';
    } else {
      final key = foldVietnamese(name);
      final clash = store.overview?.items.any((i) =>
              i.id != widget.existing?.id && foldVietnamese(i.name) == key) ??
          false;
      if (clash) errors['name'] = 'Quán đã có món tên này. Hãy đặt tên khác.';
    }
    final rows = _liveRows;
    final seen = <String>{};
    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final n = r.name.text.trim();
      if (n.isEmpty) {
        errors['size$i.name'] = 'Nhập tên size.';
      } else if (!seen.add(foldVietnamese(n))) {
        errors['size$i.name'] = 'Đổi thành tên khác $n.';
      }
      if (r.id == null) {
        final p = parseVnd(r.price.text);
        if (p == null || p <= 0) {
          errors['size$i.price'] = 'Giá phải lớn hơn 0đ, ví dụ 42.000đ.';
        }
      }
    }
    if (rows.isEmpty) errors['sizes'] = 'Món cần ít nhất một size.';
    return errors;
  }

  Future<void> _save() async {
    final store = context.read<MenuStore>();
    setState(() => _submitted = true);
    if (_errors(store).isNotEmpty) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final rows = _liveRows;
    if (_editing) {
      final existing = widget.existing!;
      final ok = await menuGuard(context, () async {
        await store.updateItem(
          itemId: existing.id,
          name: name,
          category: _category,
          description: existing.description,
        );
        for (final id in _removed) {
          await store.removeSize(id);
        }
        for (final r in rows.where((r) => r.id == null)) {
          await store.addSize(existing.id, r.name.text.trim(), parseVnd(r.price.text)!);
        }
        return true;
      });
      if (!mounted) return;
      setState(() => _saving = false);
      if (ok == true) Navigator.of(context).pop();
      return;
    }
    final sizes = [
      for (final r in rows) (name: r.name.text.trim(), price: parseVnd(r.price.text)!),
    ];
    final id = await menuGuard(
      context,
      () => store.createItem(
        name: name,
        category: _category,
        sizes: sizes,
        publish: false,
      ),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (id != null) {
        _savedItemId = id;
        _savedSizes = sizes;
      }
    });
  }

  Future<void> _finishRecipe() async {
    final store = context.read<MenuStore>();
    final id = _savedItemId;
    if (id == null) return;
    final detail = await menuGuard(context, () => store.loadDetail(id));
    if (!mounted || detail == null) return;
    final nav = Navigator.of(context);
    nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<MenuStore>.value(
          value: store,
          child: RecipeEditorPage(
            detail: detail,
            initialSizeId: detail.activeSizes.first.id,
          ),
        ),
      ),
    );
  }

  Future<void> _removeRow(_SizeRow row) async {
    if (row.id == null) {
      setState(() {
        _rows.remove(row);
        row.dispose();
      });
      return;
    }
    final ok = await confirmSheet(
      context,
      title: 'Ngừng bán size ${row.name.text}?',
      message:
          'Size sẽ ẩn khỏi lần chọn bán mới. Bill cũ và lịch sử bán vẫn còn nguyên. Bạn có thể thêm lại size cùng tên sau.',
      confirmLabel: 'Ngừng bán size',
    );
    if (ok && mounted) setState(() => _removed.add(row.id!));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MenuStore>();
    if (_savedItemId != null) return _saved(context);

    final errors = _submitted ? _errors(store) : const <String, String>{};
    final categories = store.categoryNames.where((c) => c != 'Khác').toList();
    final rows = _liveRows;
    final hasErrors = errors.isNotEmpty;

    return MenuPage(
      title: _editing ? 'Sửa thông tin món' : (hasErrors ? 'Kiểm tra một chút' : 'Một món mới'),
      subtitle: _editing
          ? 'Tên, nhóm và size của ${widget.existing!.name}.'
          : (hasErrors
              ? 'Thông tin hợp lệ đã được giữ nguyên.'
              : 'Bắt đầu với tên và giá. Công thức có thể thêm sau.'),
      primary: MenuPrimaryButton(
        label: hasErrors
            ? 'Sửa ${errors.length} lỗi trước khi lưu'
            : (_editing ? 'Lưu thay đổi' : 'Lưu bản nháp · Chưa bán'),
        loading: _saving,
        onPressed: hasErrors ? null : _save,
      ),
      secondary: MenuSecondaryButton(
        label: 'Hủy',
        onPressed: _saving ? null : () => Navigator.of(context).pop(),
      ),
      children: [
        if (hasErrors)
          MenuBanner(
            kind: BannerKind.error,
            title: 'Có ${errors.length} chỗ cần sửa',
            body: errors.values.take(3).join(' '),
          ),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: 'Tên món *',
            errorText: errors['name'],
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: categories.cast<String?>().firstWhere(
              (c) => foldVietnamese(c!) == foldVietnamese(_category ?? ''),
              orElse: () => null),
          decoration: const InputDecoration(labelText: 'Nhóm món'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Khác (không nhóm)')),
            for (final c in categories) DropdownMenuItem<String?>(value: c, child: Text(c)),
          ],
          onChanged: (v) => setState(() => _category = v),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => openMenuPage<void>(context, const CategoryListPage()),
            child: const Text('Quản lý danh mục'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Text('Size & giá bán', style: AppTextStyles.cardTitle)),
            Text('VNĐ / ly', style: AppTextStyles.caption),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: TextField(
                    controller: rows[i].name,
                    enabled: rows[i].id == null,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Tên size',
                      errorText: errors['size$i.name'],
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: rows[i].price,
                    enabled: rows[i].id == null,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [VndInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Giá bán (VNĐ)',
                      suffixText: 'đ',
                      errorText: errors['size$i.price'],
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Bỏ size',
                  onPressed: rows.length <= 1 ? null : () => _removeRow(rows[i]),
                  icon: const Icon(Icons.close_rounded),
                  constraints: const BoxConstraints.tightFor(width: 48, height: 56),
                ),
              ],
            ),
          ),
        if (errors['sizes'] != null)
          Text(errors['sizes']!,
              style: TextStyle(color: AppColors.statusCritical, fontSize: 12)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _rows.add(_SizeRow())),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm size'),
          ),
        ),
        Text(
          _editing
              ? 'Giá của size đã có đổi ở mục "Đổi giá theo size" để giữ lịch sử. Size đã bán chỉ ngừng bán, không xóa.'
              : 'Tên không trùng · Giữ ít nhất 1 size. Chưa bán: có thể bỏ size. Đã bán: chỉ ngừng bán size đó.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 12),
        if (!_editing)
          const MenuBanner(
            kind: BannerKind.warning,
            title: 'Công thức có thể thêm sau',
            body:
                'Vẫn lưu được bản nháp. Giá vốn/lãi chưa xác định; báo cáo đối soát có thể thiếu chính xác cho đến khi có công thức.',
          ),
      ],
    );
  }

  Widget _saved(BuildContext context) => MenuPage(
        title: 'Đã cất món mới',
        subtitle: '${_name.text.trim()} · lưu bản nháp',
        showBack: false,
        primary: MenuPrimaryButton(
          label: 'Hoàn thiện công thức',
          onPressed: _finishRecipe,
        ),
        secondary: MenuSecondaryButton(
          label: 'Về thực đơn',
          onPressed: () => Navigator.of(context).pop(),
        ),
        children: [
          const MenuBanner(
            kind: BannerKind.success,
            title: 'Bản nháp đã lưu trên hệ thống',
            body: 'Chưa bán ở bất kỳ nơi nào. Mở bán khi công thức và giá đã sẵn sàng.',
          ),
          MenuCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const StatusChip(
                    label: 'Bản nháp · chưa bán',
                    severity: StatusSeverity.neutral,
                    compact: true),
                const SizedBox(height: 8),
                for (final s in _savedSizes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${s.name} · ${formatVnd(s.price)}',
                              style: AppTextStyles.bodyStrong),
                        ),
                        Text('! Chưa có công thức · Vốn/lãi chưa xác định',
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const MenuBanner(
            kind: BannerKind.warning,
            title: 'Còn thiếu công thức ở mọi size',
            body: 'Thêm công thức để biết giá vốn và lãi gộp.',
          ),
        ],
      );
}
