import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/format.dart';
import 'menu_models.dart';
import 'menu_store.dart';
import 'menu_widgets.dart';

/// Sao chép món trong cùng quán (làm nhanh món gần giống).
class CopyItemPage extends StatefulWidget {
  const CopyItemPage({super.key, required this.detail});

  final ItemDetail detail;

  @override
  State<CopyItemPage> createState() => _CopyItemPageState();
}

class _CopyItemPageState extends State<CopyItemPage> {
  late final TextEditingController _name =
      TextEditingController(text: '${widget.detail.name} (bản sao)');
  bool _saving = false;
  Object? _error;
  CopyResult? _result;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _copy() async {
    final store = context.read<MenuStore>();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await store.copyItem(widget.detail.id, _name.text.trim());
      if (mounted) setState(() => _result = r);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    if (result != null) {
      return MenuPage(
        title: 'Đã tạo bản sao',
        subtitle: _name.text.trim(),
        showBack: false,
        primary: MenuPrimaryButton(
          label: 'Xong',
          onPressed: () => Navigator.of(context).pop(true),
        ),
        children: [
          MenuBanner(
            kind: BannerKind.success,
            title: 'Món mới đang ở trạng thái nháp',
            body:
                'Đã chép ${result.copiedLines} dòng công thức. Kiểm tra giá và công thức rồi bấm mở bán.',
          ),
        ],
      );
    }
    final name = _name.text.trim();
    return MenuPage(
      title: 'Sao chép món',
      subtitle: widget.detail.name,
      primary: MenuPrimaryButton(
        label: 'Tạo bản sao',
        loading: _saving,
        onPressed: name.isEmpty ? null : _copy,
      ),
      children: [
        if (_error != null)
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa sao chép được',
            body: menuErrorMessage(_error!),
          ),
        TextField(
          controller: _name,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(labelText: 'Tên món mới'),
        ),
        const SizedBox(height: 12),
        const MenuBanner(
          kind: BannerKind.info,
          title: 'Chép những gì?',
          body:
              'Các size, giá và công thức hiện tại. Bản sao là món nháp, chưa bán cho đến khi bạn mở bán. Lịch sử bán không được chép.',
        ),
      ],
    );
  }
}

/// Sao chép món sang quán khác của cùng chủ, có đối chiếu nguyên liệu.
class CopyToShopPage extends StatefulWidget {
  const CopyToShopPage({super.key, required this.detail});

  final ItemDetail detail;

  @override
  State<CopyToShopPage> createState() => _CopyToShopPageState();
}

class _CopyToShopPageState extends State<CopyToShopPage> {
  List<CopyTarget>? _targets;
  Object? _loadError;
  CopyTarget? _target;
  late final TextEditingController _name =
      TextEditingController(text: widget.detail.name);
  Timer? _debounce;
  CopyPreview? _preview;
  Object? _previewError;
  bool _previewing = false;
  Map<String, String> _mapping = {};
  bool _copyToppings = false;
  bool _copyOptions = false;
  bool _saving = false;
  Object? _error;
  CopyResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final t = await context.read<MenuStore>().loadCopyTargets();
      if (!mounted) return;
      setState(() => _targets = t);
      if (t.length == 1) _choose(t.first);
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  void _choose(CopyTarget t) {
    setState(() {
      _target = t;
      _preview = null;
      _mapping = {};
    });
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    final target = _target;
    if (target == null) return;
    final store = context.read<MenuStore>();
    setState(() {
      _previewing = true;
      _previewError = null;
    });
    try {
      final p = await store.copyPreview(widget.detail.id, target.shopId, _name.text.trim());
      if (!mounted || _target != target) return;
      setState(() {
        _preview = p;
        // Giữ ánh xạ tay đã chọn; nguyên liệu khớp tự động được hiện sẵn.
        _mapping = {
          for (final l in p.lines)
            if (l.matchId != null) l.ingredientId: _mapping[l.ingredientId] ?? l.matchId!
            else if (_mapping[l.ingredientId] != null) l.ingredientId: _mapping[l.ingredientId]!,
        };
      });
    } catch (error) {
      if (mounted) setState(() => _previewError = error);
    } finally {
      if (mounted) setState(() => _previewing = false);
    }
  }

  void _onNameChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), _loadPreview);
    setState(() {});
  }

  int get _matched {
    final p = _preview;
    if (p == null) return 0;
    return p.lines.where((l) => _mapping[l.ingredientId] != null).length;
  }

  Future<void> _reconcile() async {
    final p = _preview;
    final t = _target;
    if (p == null || t == null) return;
    final result = await openMenuPage<Map<String, String>>(
      context,
      CopyMappingPage(preview: p, destShop: t.name, initial: _mapping, itemName: widget.detail.name),
    );
    if (result != null && mounted) setState(() => _mapping = result);
  }

  Future<void> _copy() async {
    final store = context.read<MenuStore>();
    final target = _target!;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final r = await store.copyToShop(
        widget.detail.id,
        target.shopId,
        _name.text.trim(),
        mapping: _mapping,
        copyToppings: _copyToppings,
        copyOptions: _copyOptions,
      );
      if (mounted) setState(() => _result = r);
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
        if (error is DatabaseFailure && error.code == 'MENU_NAME_DUPLICATE') _loadPreview();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final targets = _targets;
    final target = _target;
    final preview = _preview;
    final detail = widget.detail;
    final from = menuShopName(context);
    if (result != null && target != null) return _done(context, result, target, preview);

    final nameEmpty = _name.text.trim().isEmpty;
    final taken = preview?.nameTaken == true;
    final unmatched = preview == null ? 0 : preview.lines.length - _matched;

    return MenuPage(
      title: taken ? 'Trùng tên món' : 'Sao chép sang quán khác',
      subtitle: taken
          ? 'Đổi tên bản sao để tiếp tục tạo bản nháp.'
          : '${detail.name} · Bản sao độc lập',
      primary: MenuPrimaryButton(
        label: taken ? 'Tạo bản nháp với tên mới' : 'Tạo bản nháp',
        loading: _saving,
        onPressed: target == null || preview == null || taken || nameEmpty || _previewing ? null : _copy,
      ),
      secondary: unmatched > 0 && preview != null && !taken
          ? MenuSecondaryButton(label: 'Đối chiếu nguyên liệu', onPressed: _reconcile)
          : MenuSecondaryButton(
              label: 'Hủy sao chép',
              onPressed: _saving ? null : () => Navigator.of(context).pop(false),
            ),
      children: [
        if (_loadError != null) ...[
          MenuBanner(
            kind: BannerKind.error,
            title: 'Chưa tải được danh sách quán',
            body: menuErrorMessage(_loadError!),
          ),
          MenuPrimaryButton(label: 'Thử lại', onPressed: _load),
        ] else if (targets == null)
          const MenuSkeleton(rows: 2)
        else if (targets.isEmpty)
          const MenuBanner(
            kind: BannerKind.info,
            title: 'Chưa có quán khác',
            body: 'Bạn chỉ có một quán nên chưa có nơi để sao chép.',
          )
        else ...[
          if (targets.length > 1) ...[
            const Text('Chọn quán nhận', style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            for (final t in targets)
              MenuCard(
                onTap: () => _choose(t),
                borderColor: target?.shopId == t.shopId ? AppColors.brand : AppColors.cardBorder,
                child: Row(
                  children: [
                    Icon(
                      target?.shopId == t.shopId
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(t.name, style: AppTextStyles.cardTitle)),
                  ],
                ),
              ),
          ],
          if (target != null) ...[
            Text('NGUỒN → QUÁN NHẬN', style: AppTextStyles.micro),
            Text('$from → ${target.name}', style: AppTextStyles.bodyStrong),
            const SizedBox(height: 10),
            if (_error != null)
              MenuBanner(
                kind: BannerKind.error,
                title: 'Chưa sao chép được',
                body: menuErrorMessage(_error!),
              ),
            if (_previewError != null)
              MenuBanner(
                kind: BannerKind.error,
                title: 'Chưa kiểm tra được quán nhận',
                body: menuErrorMessage(_previewError!),
                action: TextButton(onPressed: _loadPreview, child: const Text('Thử lại')),
              ),
            if (taken)
              MenuBanner(
                kind: BannerKind.warning,
                title: '${target.name} đã có món này',
                body:
                    '${_name.text.trim()} đã tồn tại. Món hiện có, công thức đã bán và lịch sử của món đó được giữ nguyên. Không ghi đè hoặc gộp món cùng tên.',
              ),
            TextField(
              controller: _name,
              onChanged: _onNameChanged,
              decoration: InputDecoration(
                labelText: 'Tên bản sao *',
                errorText: nameEmpty ? 'Nhập tên bản sao' : null,
              ),
            ),
            const SizedBox(height: 12),
            if (_previewing && preview == null)
              const MenuSkeleton(rows: 2)
            else if (preview != null) ...[
              MenuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin đang giữ', style: AppTextStyles.cardTitle),
                    const SizedBox(height: 4),
                    Text(
                      [for (final s in preview.sizes) '${s.name} ${formatVnd(s.price)}'].join(' · '),
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview.lines.isEmpty
                          ? 'Món chưa có công thức nên không có gì để đối chiếu.'
                          : 'Công thức hiện hành. Đối chiếu: $_matched / ${preview.lines.length} nguyên liệu'
                              '${unmatched > 0 ? ' · Thiếu ${[for (final l in preview.lines) if (_mapping[l.ingredientId] == null) l.name].join(' + ')}' : ''}',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      preview.category == null
                          ? 'Danh mục: Khác'
                          : preview.categoryExists
                              ? 'Danh mục tại quán nhận: ${preview.category}'
                              : 'Danh mục "${preview.category}" sẽ được tạo ở quán nhận.',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
              if (unmatched > 0)
                const MenuBanner(
                  kind: BannerKind.warning,
                  title: 'Cần đối chiếu nguyên liệu',
                  body:
                      'Size nào còn nguyên liệu chưa khớp sẽ chưa có công thức (vốn và lãi chưa xác định). Bạn vẫn tạo được bản nháp rồi soạn công thức sau.',
                ),
              MenuCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sao chép thêm · Không bắt buộc', style: AppTextStyles.cardTitle),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Topping bán kèm (${preview.toppingCount})'),
                      subtitle: const Text('Ghép theo tên với topping của quán nhận.'),
                      value: _copyToppings,
                      onChanged: preview.toppingCount == 0
                          ? null
                          : (v) => setState(() => _copyToppings = v ?? false),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Nhóm tùy chọn pha chế (${preview.optionGroupCount})'),
                      value: _copyOptions,
                      onChanged: preview.optionGroupCount == 0
                          ? null
                          : (v) => setState(() => _copyOptions = v ?? false),
                    ),
                    const Text(
                      'Mặc định không sao chép. Bản sao là bản nháp độc lập, chủ quán kiểm tra rồi mới bật bán.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ],
    );
  }

  Widget _done(BuildContext context, CopyResult r, CopyTarget target, CopyPreview? preview) {
    final skipped = r.skippedIngredients;
    final needsFix = skipped.isNotEmpty;
    return MenuPage(
      title: 'Đã tạo bản nháp',
      subtitle: 'Lưu thành công · Chưa sẵn sàng bán',
      showBack: false,
      primary: MenuPrimaryButton(
        label: 'Xong',
        onPressed: () => Navigator.of(context).pop(true),
      ),
      children: [
        Text('NGUỒN → QUÁN NHẬN', style: AppTextStyles.micro),
        Text('${menuShopName(context)} → ${target.name}', style: AppTextStyles.bodyStrong),
        const SizedBox(height: 10),
        MenuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_name.text.trim(), style: AppTextStyles.cardTitle),
              const Text('Bản nháp độc lập · Chưa bán', style: AppTextStyles.caption),
              if (preview != null) ...[
                const SizedBox(height: 6),
                Text(
                  [for (final s in preview.sizes) '${s.name} ${formatVnd(s.price)}'].join(' · '),
                  style: AppTextStyles.body,
                ),
              ],
            ],
          ),
        ),
        MenuBanner(
          kind: needsFix ? BannerKind.warning : BannerKind.success,
          title: needsFix ? 'Cần đối chiếu nguyên liệu' : 'Chưa bật bán · Cần kiểm tra',
          body: needsFix
              ? 'Thiếu ${skipped.join(' + ')}. Size có nguyên liệu này chưa có công thức; giá vốn và lãi chưa xác định, không lấy giá nguyên liệu từ ${menuShopName(context)}.'
              : 'Đã chép ${r.copiedLines} dòng công thức. Giá vốn tính theo giá nguyên liệu của ${target.name}.',
        ),
        MenuCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nội dung bản nháp', style: AppTextStyles.cardTitle),
              const SizedBox(height: 4),
              Text(
                r.copiedLines > 0
                    ? '✓ Size, giá bán và ${r.copiedLines} dòng công thức hiện hành'
                    : '✓ Size và giá bán · — chưa có công thức',
                style: AppTextStyles.body,
              ),
              Text(
                r.copiedToppings > 0
                    ? '✓ ${r.copiedToppings} topping bán kèm'
                    : '— Không sao chép topping',
                style: AppTextStyles.body,
              ),
              if (r.skippedToppings.isNotEmpty)
                Text('— Chưa có ở quán nhận: ${r.skippedToppings.join(', ')}', style: AppTextStyles.body),
              Text(
                r.copiedOptionGroups > 0
                    ? '✓ ${r.copiedOptionGroups} nhóm tùy chọn pha chế'
                    : '— Không sao chép nhóm tùy chọn',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
        const Text(
          'Không mang theo lịch hẹn, bill cũ hoặc lịch sử. Món gốc không thay đổi. Chủ quán phải kiểm tra đầy đủ rồi chủ động bật bán; chuyển sang quán nhận từ nút chọn quán để kiểm tra.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}

/// Đối chiếu từng nguyên liệu của công thức nguồn với nguyên liệu của quán nhận (cùng đơn vị).
class CopyMappingPage extends StatefulWidget {
  const CopyMappingPage({
    super.key,
    required this.preview,
    required this.destShop,
    required this.initial,
    required this.itemName,
  });

  final CopyPreview preview;
  final String destShop;
  final Map<String, String> initial;
  final String itemName;

  @override
  State<CopyMappingPage> createState() => _CopyMappingPageState();
}

class _CopyMappingPageState extends State<CopyMappingPage> {
  late final Map<String, String> _map = Map.of(widget.initial);

  @override
  Widget build(BuildContext context) {
    final p = widget.preview;
    final done = p.lines.where((l) => _map[l.ingredientId] != null).length;
    final complete = done == p.lines.length;
    return MenuPage(
      title: 'Đối chiếu nguyên liệu',
      subtitle: '$done / ${p.lines.length} nguyên liệu đã khớp${complete ? '' : ' · Chưa đủ để có công thức'}',
      primary: MenuPrimaryButton(
        label: complete ? 'Lưu đối chiếu' : 'Lưu đối chiếu chưa hoàn tất',
        onPressed: () => Navigator.of(context).pop(_map),
      ),
      secondary: MenuSecondaryButton(
        label: 'Hủy',
        onPressed: () => Navigator.of(context).pop(),
      ),
      children: [
        Text('${menuShopName(context)} → ${widget.destShop} · ${widget.itemName}',
            style: AppTextStyles.caption),
        const SizedBox(height: 8),
        for (final l in p.lines) _lineCard(l),
        const Text(
          'Chỉ chọn được nguyên liệu cùng đơn vị (g, ml, cái). Bản sao dùng nguyên liệu của quán nhận, không dùng lại ID quán nguồn; sửa công thức ở một quán không cập nhật quán còn lại.',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  Widget _lineCard(CopyLine l) {
    final options = [
      for (final d in widget.preview.destIngredients)
        if (d.unit == l.unit) d,
    ];
    final value = _map[l.ingredientId];
    return MenuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${l.name} · ${l.qty} ${menuUnitLabel(l.unit)}', style: AppTextStyles.cardTitle),
          Text('Dùng ở size ${l.sizes.join(', ')}', style: AppTextStyles.caption),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            initialValue: options.any((d) => d.id == value) ? value : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Nguyên liệu ở quán nhận'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Chưa chọn')),
              for (final d in options)
                DropdownMenuItem<String?>(value: d.id, child: Text('${d.name} · ${menuUnitLabel(d.unit)}')),
            ],
            onChanged: (v) => setState(() {
              if (v == null) {
                _map.remove(l.ingredientId);
              } else {
                _map[l.ingredientId] = v;
              }
            }),
          ),
          const SizedBox(height: 4),
          Text(
            value != null
                ? '✓ Đã đối chiếu · Đơn vị khớp'
                : options.isEmpty
                    ? 'Quán nhận chưa có nguyên liệu đơn vị ${menuUnitLabel(l.unit)}. Thêm nguyên liệu ở quán nhận rồi đối chiếu lại.'
                    : 'Chọn nguyên liệu tương ứng tại quán nhận',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
