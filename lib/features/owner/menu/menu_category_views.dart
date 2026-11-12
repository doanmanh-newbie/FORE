import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/typography.dart';
import 'menu_format.dart';
import 'menu_models.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// Quản lý danh mục: thêm, đổi tên, đổi thứ tự.
class CategoryListPage extends StatelessWidget {
  const CategoryListPage({super.key});

  Future<void> _move(BuildContext context, List<MenuCategory> list, int from, int to) async {
    if (to < 0 || to >= list.length) return;
    final ids = [for (final c in list) c.id];
    final id = ids.removeAt(from);
    ids.insert(to, id);
    final store = context.read<MenuStore>();
    await menuGuard<bool>(context, () async {
      await store.reorderCategories(ids);
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MenuStore>();
    final list = store.overview?.categories ?? const <MenuCategory>[];
    return MenuPage(
      title: 'Danh mục thực đơn',
      subtitle: '${list.length} danh mục · ${menuShopName(context)}',
      primary: MenuPrimaryButton(
        label: '+ Thêm danh mục',
        onPressed: () => openMenuPage<void>(context, const CategoryEditPage()),
      ),
      children: [
        if (list.isEmpty)
          const MenuBanner(
            kind: BannerKind.info,
            title: 'Chưa có danh mục',
            body: 'Danh mục giúp nhân viên tìm món nhanh hơn khi bán.',
          ),
        for (var i = 0; i < list.length; i++)
          MenuCard(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(list[i].name, style: AppTextStyles.cardTitle),
                      Text('${list[i].itemCount} món', style: AppTextStyles.caption),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Lên',
                  onPressed: i == 0 ? null : () => _move(context, list, i, i - 1),
                  icon: const Icon(Icons.arrow_upward_rounded),
                ),
                IconButton(
                  tooltip: 'Xuống',
                  onPressed: i == list.length - 1
                      ? null
                      : () => _move(context, list, i, i + 1),
                  icon: const Icon(Icons.arrow_downward_rounded),
                ),
                IconButton(
                  tooltip: 'Đổi tên',
                  onPressed: () =>
                      openMenuPage<void>(context, CategoryEditPage(existing: list[i])),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
          ),
        const Text(
          'Thứ tự ở đây cũng là thứ tự nhóm món trên màn bán hàng. Danh mục không bị xóa để giữ lịch sử.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

/// Thêm hoặc đổi tên một danh mục.
class CategoryEditPage extends StatefulWidget {
  const CategoryEditPage({super.key, this.existing});

  final MenuCategory? existing;

  @override
  State<CategoryEditPage> createState() => _CategoryEditPageState();
}

class _CategoryEditPageState extends State<CategoryEditPage> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? _validate() {
    final name = _name.text.trim();
    if (name.isEmpty) return 'Nhập tên danh mục';
    final key = foldVietnamese(name);
    final all = context.read<MenuStore>().overview?.categories ?? const <MenuCategory>[];
    for (final c in all) {
      if (c.id != widget.existing?.id && foldVietnamese(c.name) == key) {
        return 'Đã có danh mục tên "${c.name}"';
      }
    }
    return null;
  }

  Future<void> _save() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final store = context.read<MenuStore>();
    final name = _name.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.existing == null) {
        await store.addCategory(name);
      } else {
        await store.renameCategory(widget.existing!.id, name);
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = menuErrorMessage(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return MenuPage(
      title: editing ? 'Đổi tên danh mục' : 'Thêm danh mục',
      subtitle: editing ? widget.existing!.name : null,
      primary: MenuPrimaryButton(
        label: editing ? 'Lưu tên mới' : 'Thêm danh mục',
        loading: _saving,
        onPressed: _save,
      ),
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          decoration: InputDecoration(
            labelText: 'Tên danh mục',
            errorText: _error,
          ),
        ),
        if (editing)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text(
              'Các món trong danh mục sẽ chuyển theo tên mới.',
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }
}
