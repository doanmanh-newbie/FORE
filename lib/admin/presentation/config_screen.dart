import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/application/load_phase.dart';
import '../../core/design/colors.dart';
import '../../core/design/empty_state.dart';
import '../../core/design/error_state.dart';
import '../../core/design/spacing.dart';
import '../../core/design/status_pill.dart';
import '../../core/design/typography.dart';
import '../../core/errors/app_failure.dart';
import '../../core/widgets/fore_card.dart';
import '../../core/widgets/notify.dart';
import '../../core/widgets/status_chip.dart';
import '../admin_errors.dart';
import '../domain/admin_models.dart';
import '../domain/admin_repositories.dart';
import 'admin_widgets.dart';

/// Màn hình Cấu hình từ xa (`app_config` / `admin_set_config`).
/// Cung cấp cả preset nhanh (`maintenance`, `maintenance_message`, `min_version`)
/// lẫn trình chỉnh sửa key-value JSON bất kỳ.
class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({
    super.key,
    required this.repository,
  });

  final AdminConfigRepository repository;

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  static final _keyPattern = RegExp(r'^[a-z0-9_.]{1,64}$');

  LoadPhase _phase = LoadPhase.loading;
  List<AdminConfigEntry> _entries = const [];
  String? _errorMessage;
  bool _savingPreset = false;

  final _maintenanceMessageController = TextEditingController();
  final _minVersionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maintenanceMessageController.dispose();
    _minVersionController.dispose();
    super.dispose();
  }

  AdminConfigEntry? _findEntry(String key) {
    for (final entry in _entries) {
      if (entry.key == key) return entry;
    }
    return null;
  }

  void _syncPresetControllers() {
    final msg = _findEntry('maintenance_message')?.value;
    _maintenanceMessageController.text = msg is String ? msg : '';
    final minVer = _findEntry('min_version')?.value;
    _minVersionController.text = minVer is String ? minVer : '';
  }

  Future<void> _load() async {
    setState(() {
      _phase = LoadPhase.loading;
      _errorMessage = null;
    });
    try {
      final rows = await widget.repository.listConfigs();
      if (!mounted) return;
      setState(() {
        _entries = rows;
        _phase = LoadPhase.ready;
        _syncPresetControllers();
      });
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _errorMessage = adminFailureMessage(failure);
        _phase = LoadPhase.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Không thể tải cấu hình từ xa.';
        _phase = LoadPhase.error;
      });
    }
  }

  Future<void> _saveKeyValue({
    required String key,
    required dynamic value,
    String? successMessage,
  }) async {
    setState(() => _savingPreset = true);
    try {
      final saved = await widget.repository.setConfig(key: key, value: value);
      if (!mounted) return;
      setState(() {
        _entries = [
          ..._entries.where((e) => e.key != saved.key),
          saved,
        ]..sort((a, b) => a.key.compareTo(b.key));
        _syncPresetControllers();
      });
      showNotice(context, successMessage ?? 'Đã lưu khóa "${saved.key}".');
    } on AppFailure catch (failure) {
      if (!mounted) return;
      showNotice(context, adminFailureMessage(failure));
    } catch (_) {
      if (!mounted) return;
      showNotice(context, 'Không thể lưu cấu hình lúc này.');
    } finally {
      if (mounted) {
        setState(() => _savingPreset = false);
      }
    }
  }

  Future<void> _openEditorDialog({AdminConfigEntry? existing}) async {
    final saved = await showDialog<AdminConfigEntry>(
      context: context,
      builder: (_) => _ConfigEditorDialog(
        existing: existing,
        keyPattern: _keyPattern,
        onSaveConfig: (key, value) => widget.repository.setConfig(
          key: key,
          value: value,
        ),
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      _entries = [
        ..._entries.where((e) => e.key != saved.key),
        saved,
      ]..sort((a, b) => a.key.compareTo(b.key));
      _syncPresetControllers();
    });
    showNotice(context, 'Đã lưu cấu hình "${saved.key}".');
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSizes.pagePadding),
      children: [
        AdminPageHeader(
          title: 'Cấu hình từ xa',
          subtitle: 'Điều khiển cấu hình app_config qua admin_set_config(p_key, p_value).',
          trailing: Wrap(
            spacing: AppGaps.sm,
            children: [
              OutlinedButton.icon(
                onPressed: _phase == LoadPhase.loading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Làm mới'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
              FilledButton.icon(
                key: const Key('config_add_button'),
                onPressed: _phase == LoadPhase.ready
                    ? () => _openEditorDialog()
                    : null,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Thêm khóa'),
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        switch (_phase) {
          LoadPhase.loading => const AdminLoadingList(),
          LoadPhase.error => ForeCard(
              elevated: false,
              child: ErrorState(
                message: _errorMessage ?? 'Đã có lỗi xảy ra.',
                onRetry: _load,
              ),
            ),
          LoadPhase.ready => _buildContent(),
        },
      ],
    );
  }

  Widget _buildContent() {
    final maintenanceOn = _findEntry('maintenance')?.value == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ForeCard(
          padding: const EdgeInsets.all(AppSizes.cardPadding),
          elevated: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppGaps.sm,
                children: [
                  Text('Thiết lập nhanh', style: AppTextStyles.sectionHeading),
                  StatusPill(
                    label: maintenanceOn ? 'Đang bảo trì' : 'Hoạt động bình thường',
                    severity: maintenanceOn
                        ? StatusSeverity.attention
                        : StatusSeverity.healthy,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: AppGaps.md),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  key: const Key('preset_maintenance_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Chế độ bảo trì (maintenance)'),
                  subtitle: const Text(
                    'Bật để ứng dụng hiển thị màn hình bảo trì khi khởi động.',
                  ),
                  value: maintenanceOn,
                  onChanged: _savingPreset
                      ? null
                      : (next) => _saveKeyValue(
                            key: 'maintenance',
                            value: next,
                            successMessage: next
                                ? 'Đã bật chế độ bảo trì.'
                                : 'Đã tắt chế độ bảo trì.',
                          ),
                ),
              ),
              const Divider(height: AppGaps.xl),
              Text('Thông báo bảo trì (maintenance_message)',
                  style: AppTextStyles.fieldLabel),
              const SizedBox(height: AppGaps.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('preset_maintenance_message_field'),
                      controller: _maintenanceMessageController,
                      decoration: const InputDecoration(
                        hintText: 'Hệ thống đang bảo trì, vui lòng quay lại sau...',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppGaps.sm),
                  FilledButton(
                    key: const Key('preset_maintenance_message_save'),
                    onPressed: _savingPreset
                        ? null
                        : () => _saveKeyValue(
                              key: 'maintenance_message',
                              value: _maintenanceMessageController.text.trim(),
                            ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(88, AppSizes.fieldHeight),
                    ),
                    child: const Text('Lưu'),
                  ),
                ],
              ),
              const SizedBox(height: AppGaps.md),
              Text('Phiên bản tối thiểu (min_version)',
                  style: AppTextStyles.fieldLabel),
              const SizedBox(height: AppGaps.xs),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('preset_min_version_field'),
                      controller: _minVersionController,
                      decoration: const InputDecoration(
                        hintText: 'vd: 1.0.0',
                      ),
                    ),
                  ),
                  const SizedBox(width: AppGaps.sm),
                  FilledButton(
                    key: const Key('preset_min_version_save'),
                    onPressed: _savingPreset
                        ? null
                        : () => _saveKeyValue(
                              key: 'min_version',
                              value: _minVersionController.text.trim(),
                            ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(88, AppSizes.fieldHeight),
                    ),
                    child: const Text('Lưu'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppGaps.lg),
        Text('Toàn bộ khóa trong app_config', style: AppTextStyles.sectionHeading),
        const SizedBox(height: AppGaps.sm),
        if (_entries.isEmpty)
          ForeCard(
            elevated: false,
            child: EmptyState(
              icon: Icons.tune_rounded,
              title: 'Chưa có khóa cấu hình nào',
              message: 'Bấm "Thêm khóa" hoặc bật thiết lập nhanh ở trên để tạo cấu hình đầu tiên.',
              actionLabel: 'Thêm khóa',
              onAction: () => _openEditorDialog(),
            ),
          )
        else
          for (var i = 0; i < _entries.length; i++) ...[
            _ConfigEntryCard(
              entry: _entries[i],
              onEdit: () => _openEditorDialog(existing: _entries[i]),
            ),
            if (i < _entries.length - 1)
              const SizedBox(height: AppSizes.cardGap),
          ],
      ],
    );
  }
}

class _ConfigEntryCard extends StatelessWidget {
  const _ConfigEntryCard({
    required this.entry,
    required this.onEdit,
  });

  final AdminConfigEntry entry;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ForeCard(
      padding: const EdgeInsets.all(AppSizes.cardPadding),
      elevated: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppGaps.sm,
                  runSpacing: AppGaps.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AdminCodeBadge(text: entry.key),
                    if (entry.updatedAt != null)
                      Text(
                        'Cập nhật: ${formatAdminDateTime(entry.updatedAt)}',
                        style: AppTextStyles.caption,
                      ),
                  ],
                ),
                const SizedBox(height: AppGaps.sm),
                SelectableText(
                  formatCompactJson(entry.value),
                  style: AppTextStyles.bodyStrong.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppGaps.sm),
          OutlinedButton.icon(
            key: Key('config_edit_${entry.key}'),
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Sửa'),
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
          ),
        ],
      ),
    );
  }
}

class _ConfigEditorDialog extends StatefulWidget {
  const _ConfigEditorDialog({
    required this.existing,
    required this.keyPattern,
    required this.onSaveConfig,
  });

  final AdminConfigEntry? existing;
  final RegExp keyPattern;
  final Future<AdminConfigEntry> Function(String key, dynamic value)
      onSaveConfig;

  @override
  State<_ConfigEditorDialog> createState() => _ConfigEditorDialogState();
}

class _ConfigEditorDialogState extends State<_ConfigEditorDialog> {
  late final TextEditingController _keyController;
  late final TextEditingController _valueController;
  String? _dialogError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _keyController = TextEditingController(text: widget.existing?.key ?? '');
    _valueController = TextEditingController(
      text: widget.existing == null
          ? '""'
          : formatPrettyJson(widget.existing!.value),
    );
  }

  @override
  void dispose() {
    _keyController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final rawKey = _keyController.text.trim().toLowerCase();
    if (!widget.keyPattern.hasMatch(rawKey)) {
      setState(() {
        _dialogError =
            'Tên khóa chỉ gồm chữ thường a-z, số 0-9, dấu gạch dưới "_" hoặc dấu chấm "." (1–64 ký tự).';
      });
      return;
    }

    dynamic parsedValue;
    try {
      parsedValue = jsonDecode(_valueController.text.trim());
    } catch (_) {
      setState(() {
        _dialogError =
            'Giá trị không phải JSON hợp lệ. Ví dụ: true, "1.2.0", 30, {"enabled": true}.';
      });
      return;
    }
    if (parsedValue == null) {
      setState(() {
        _dialogError = 'Giá trị JSON không được là null.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _dialogError = null;
    });
    try {
      final saved = await widget.onSaveConfig(rawKey, parsedValue);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dialogError = adminFailureMessage(failure);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _dialogError = 'Không thể lưu cấu hình.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.existing == null
            ? 'Thêm khóa cấu hình'
            : 'Sửa "${widget.existing!.key}"',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_dialogError != null) ...[
                Text(
                  _dialogError!,
                  key: const Key('config_dialog_error'),
                  style: AppTextStyles.bodyStrong.copyWith(
                    color: AppColors.statusCritical,
                  ),
                ),
                const SizedBox(height: AppGaps.md),
              ],
              Text('Tên khóa (key)', style: AppTextStyles.fieldLabel),
              const SizedBox(height: AppGaps.xs),
              TextField(
                key: const Key('config_key_field'),
                controller: _keyController,
                enabled: widget.existing == null && !_saving,
                decoration: const InputDecoration(
                  hintText: 'vd: maintenance, min_version, feature.banner',
                ),
              ),
              const SizedBox(height: AppGaps.md),
              Text('Giá trị JSON (value)', style: AppTextStyles.fieldLabel),
              const SizedBox(height: AppGaps.xs),
              TextField(
                key: const Key('config_value_field'),
                controller: _valueController,
                enabled: !_saving,
                maxLines: 6,
                style: AppTextStyles.body.copyWith(
                  fontFamily: 'monospace',
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'vd: false hoặc "1.0.0" hoặc {"title": "..."}',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Hủy'),
        ),
        FilledButton(
          key: const Key('config_dialog_save'),
          onPressed: _saving ? null : _onSave,
          style: FilledButton.styleFrom(minimumSize: const Size(104, 44)),
          child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
        ),
      ],
    );
  }
}
