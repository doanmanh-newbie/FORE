import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/app_sheet.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../../inventory/presentation/kho_widgets.dart';
import '../domain/settings_models.dart';
import '../domain/settings_repository.dart';
import '../../../core/widgets/lazy_list_view.dart';

/// "Vai trò và phân quyền" (chủ quán): bật/tắt từng quyền cho Quản lý, Thu ngân, Nhân viên,
/// có thể áp dụng cho nhiều quán cùng lúc. Chỉ hiện quyền mà database đang áp dụng thật.
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  late final SettingsRepository _repo = context.read<SettingsRepository>();
  JobRole _role = JobRole.manager;
  RoleConfig? _config;
  Map<String, bool> _draft = {};
  List<Branch> _branches = const [];
  final Set<String> _scope = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cfg = await guarded(context, () => _repo.roleConfig(_role));
    if (!mounted) return; // rời màn hình: `context` không còn dùng được
    final branches =
        _branches.isEmpty ? await guarded(context, _repo.branches) : _branches;
    if (!mounted) return;
    setState(() {
      _config = cfg;
      _draft = {
        for (final p in permissionCatalog) p.key: cfg?.allowed(p.key) ?? false
      };
      _branches = branches ?? const [];
      if (_scope.isEmpty) {
        final cur = _branches.where((b) => b.isCurrent).map((b) => b.shopId);
        _scope.addAll(cur);
      }
      _loading = false;
    });
  }

  bool get _dirty =>
      _config != null &&
      permissionCatalog.any((p) => _draft[p.key] != _config!.allowed(p.key));

  Future<void> _toggle(PermissionDef p, bool value) async {
    if (value && p.sensitive) {
      final ok = await AppSheet.show<bool>(
        context,
        builder: (ctx) => AppSheet(
          title: 'Bật quyền nhạy cảm?',
          footer: PrimaryButton(
              label: 'Bật quyền này',
              onPressed: () => Navigator.pop(ctx, true)),
          child: Text(
              '"${p.label}": ${p.hint}. Mọi ${_role.label.toLowerCase()} trong phạm vi áp dụng sẽ có quyền này.',
              style: AppTextStyles.body),
        ),
      );
      if (ok != true) return;
    }
    setState(() => _draft[p.key] = value);
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final n = await guarded(
      context,
      () => _repo.saveRole(_role, _draft,
          shopIds: _scope.isEmpty ? null : _scope.toList()),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (n != null) {
      showNotice(context,
          'Đã lưu quyền ${_role.label} cho $n quán. Có hiệu lực ngay ở lần thao tác tiếp theo.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Vai trò và phân quyền',
        subtitle: 'Chỉ chủ quán sửa được',
        bottom: _loading || !_dirty
            ? null
            : PrimaryButton(
                label: 'Lưu quyền ${_role.label}',
                loading: _busy,
                onPressed: _scope.isEmpty ? null : _save),
        body: _loading
            ? const KhoSkeleton()
            : LazyListView(
                padding: const EdgeInsets.all(AppSizes.pagePadding),
                children: [
                  KhoChipBar(
                    labels: [for (final r in JobRole.values) r.label],
                    selected: JobRole.values.indexOf(_role),
                    onSelected: (i) {
                      if (_busy) return;
                      _role = JobRole.values[i];
                      _load();
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (_config?.members.isEmpty ?? true)
                        ? 'Chưa có ai giữ vai trò này.'
                        : 'Đang dùng: ${_config!.members.join(', ')}',
                    style: AppTextStyles.caption,
                  ),
                  const KhoSectionTitle('Luôn được phép'),
                  KhoCard(
                    child: Row(children: [
                      Icon(Icons.lock_outline_rounded,
                          color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                            'Bán hàng, in hóa đơn, mở và chốt ca của mình. Không tắt được.',
                            style: AppTextStyles.body),
                      ),
                    ]),
                  ),
                  const KhoSectionTitle('Quyền có thể bật'),
                  for (final p in permissionCatalog)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: KhoCard(
                        // Material riêng để hiệu ứng chạm của ListTile không bị nền thẻ che.
                        child: Material(
                          color: Colors.transparent,
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _draft[p.key] ?? false,
                            onChanged: (v) => _toggle(p, v),
                            title: Row(children: [
                              Flexible(child: Text(p.label)),
                              if (p.sensitive) ...[
                                const SizedBox(width: 8),
                                const StatusChip(
                                    label: 'Nhạy cảm',
                                    severity: StatusSeverity.attention,
                                    compact: true),
                              ],
                            ]),
                            subtitle: Text(p.hint),
                          ),
                        ),
                      ),
                    ),
                  if (_branches.length > 1) ...[
                    const KhoSectionTitle('Áp dụng cho quán'),
                    for (final b in _branches)
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _scope.contains(b.shopId),
                        onChanged: (v) => setState(() => v == true
                            ? _scope.add(b.shopId)
                            : _scope.remove(b.shopId)),
                        title: Text(b.name),
                        subtitle: Text(b.isCurrent ? 'Quán đang dùng' : b.code),
                      ),
                  ],
                  const SizedBox(height: 8),
                  const KhoNote(
                      'Các quyền khác (thực đơn, khách hàng, ưu đãi…) sẽ xuất hiện ở đây khi chức năng đó được áp dụng quyền theo vai trò.'),
                ],
              ),
      );
}
