import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/typography.dart';
import 'menu_format.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// Màn "Lọc & sắp xếp": chỉnh trên bản nháp, bấm "Áp dụng" mới đổi danh sách.
class MenuFilterPage extends StatefulWidget {
  const MenuFilterPage({super.key});

  @override
  State<MenuFilterPage> createState() => _MenuFilterPageState();
}

class _MenuFilterPageState extends State<MenuFilterPage> {
  late MenuFilters _draft;

  @override
  void initState() {
    super.initState();
    _draft = context.read<MenuStore>().filters;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<MenuStore>();
    final data = store.overview;
    final count = data == null ? 0 : filterMenuItems(data, _draft).length;

    Widget group(String title, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        );

    OptionChip chip(String label, bool selected, VoidCallback onTap) =>
        OptionChip(label: label, selected: selected, onTap: onTap);

    final categories = store.categoryNames;
    final cat = _draft.category;

    return MenuPage(
      title: 'Lọc & sắp xếp',
      eyebrow: 'SỔ TAY THỰC ĐƠN',
      subtitle: 'Chỉ danh sách tại ${menuShopName(context)}.',
      primary: MenuPrimaryButton(
        label: 'Áp dụng · $count món',
        onPressed: () {
          store.setFilters(_draft.copyWith(query: store.filters.query));
          Navigator.of(context).pop();
        },
      ),
      secondary: MenuSecondaryButton(
        label: 'Đặt lại bộ lọc',
        onPressed: () => setState(() => _draft = MenuFilters(query: _draft.query)),
      ),
      children: [
        group('Nhóm món', [
          chip('Tất cả', cat == null,
              () => setState(() => _draft = _draft.copyWith(category: null))),
          for (final name in categories)
            chip(
                name,
                cat != null && foldVietnamese(cat) == foldVietnamese(name),
                () => setState(() => _draft = _draft.copyWith(category: name))),
        ]),
        group('Trạng thái bán', [
          for (final (label, value) in const [
            ('Tất cả', MenuStatusFilter.all),
            ('Đang bán', MenuStatusFilter.selling),
            ('Ngừng bán', MenuStatusFilter.paused),
            ('Bản nháp', MenuStatusFilter.draft),
          ])
            chip(label, _draft.status == value,
                () => setState(() => _draft = _draft.copyWith(status: value))),
        ]),
        group('Công thức', [
          for (final (label, value) in const [
            ('Tất cả', MenuRecipeFilter.all),
            ('Đã đủ', MenuRecipeFilter.complete),
            ('Còn thiếu', MenuRecipeFilter.missing),
          ])
            chip(label, _draft.recipe == value,
                () => setState(() => _draft = _draft.copyWith(recipe: value))),
        ]),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: _draft.lowMarginOnly,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(lowMarginOnly: v ?? false)),
          title: Text(
              'Chỉ size có lãi gộp dưới ${data?.lowMarginPct ?? 30}%'),
        ),
        const SizedBox(height: 8),
        group('Sắp xếp', [
          for (final (label, value) in [
            ('Tên A → Z', MenuSort.nameAsc),
            ('Tên Z → A', MenuSort.nameDesc),
            ('Giá tăng dần', MenuSort.priceAsc),
            ('Giá giảm dần', MenuSort.priceDesc),
            (
              'Bán chạy tuần này${data == null ? '' : ' · ${weekLabel(data.weekFrom, data.weekTo)}'}',
              MenuSort.bestSeller
            ),
          ])
            chip(label, _draft.sort == value,
                () => setState(() => _draft = _draft.copyWith(sort: value))),
        ]),
        Text(
          'Giá được so theo size nhỏ nhất của mỗi món. Món thiếu công thức không được coi là lãi cao.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
