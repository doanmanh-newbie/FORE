import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/status_chip.dart';
import 'reconcile_format.dart';

/// Dải thông báo nhỏ (vàng, xanh, đỏ, xám) dùng trong các màn đối soát.
class ReconcileBanner extends StatelessWidget {
  const ReconcileBanner({
    super.key,
    required this.icon,
    required this.text,
    this.severity = StatusSeverity.attention,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String text;
  final StatusSeverity severity;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final foreground = severityForeground(severity);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: severityBackground(severity),
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.captionStrong.copyWith(color: foreground),
              ),
            ),
            if (actionLabel != null && onAction != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  foregroundColor: foreground,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Nhãn nhỏ như "Quan trọng".
class ReconcileTag extends StatelessWidget {
  const ReconcileTag({
    super.key,
    required this.label,
    this.severity = StatusSeverity.critical,
  });

  final String label;
  final StatusSeverity severity;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: severityBackground(severity),
          borderRadius: BorderRadius.circular(AppSizes.radiusChip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          child: Text(
            label,
            style: AppTextStyles.micro
                .copyWith(color: severityForeground(severity)),
          ),
        ),
      );
}

/// Số liệu có chữ số đều nét, dùng cho tiền và số lượng.
TextStyle reconcileNumberStyle({
  double size = 15,
  Color color = AppColors.brand,
  FontWeight weight = FontWeight.w700,
}) =>
    AppTextStyles.metric.copyWith(
      fontSize: size,
      color: color,
      fontWeight: weight,
    );

enum LedgerKind { normal, subtotal, total }

/// Một dòng của "phiếu" đối soát (kiểu hóa đơn: tồn đầu + nhập − tồn cuối ...).
class LedgerLine {
  const LedgerLine(
    this.label,
    this.value, {
    this.kind = LedgerKind.normal,
    this.color,
    this.note,
    this.warning,
  });

  final String label;
  final String value;
  final LedgerKind kind;
  final Color? color;
  final String? note;

  /// Dải cảnh báo nhỏ ngay dưới dòng (ví dụ tiền đầu ca lệch).
  final String? warning;
}

class LedgerCard extends StatelessWidget {
  const LedgerCard({super.key, required this.lines});

  final List<LedgerLine> lines;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0 && line.kind != LedgerKind.normal) {
        children.add(const Divider(height: 18, color: AppColors.border));
      }
      children.add(_LedgerRow(line: line));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

class _LedgerRow extends StatelessWidget {
  const _LedgerRow({required this.line});

  final LedgerLine line;

  @override
  Widget build(BuildContext context) {
    final strong = line.kind != LedgerKind.normal;
    final color = line.color ?? AppColors.brand;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  line.label,
                  style: strong
                      ? AppTextStyles.bodyStrong
                      : AppTextStyles.body,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                line.value,
                style: reconcileNumberStyle(
                  size: line.kind == LedgerKind.total ? 18 : 15,
                  color: line.kind == LedgerKind.total
                      ? color
                      : (line.color ?? AppColors.brand),
                ),
              ),
            ],
          ),
          if (line.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(line.note!, style: AppTextStyles.caption),
            ),
          if (line.warning != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ReconcileBanner(
                icon: Icons.info_outline,
                text: line.warning!,
              ),
            ),
        ],
      ),
    );
  }
}

/// Nội dung sheet "Ghi chú & xử lý". Trả về `true` (đã xử lý) hoặc `false` (chưa xử lý)
/// khi lưu thành công; đóng sheet mà không lưu thì trả về `null`.
class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initialNote,
    required this.initialHandled,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final String initialNote;
  final bool initialHandled;
  final Future<bool> Function(bool handled, String note) onSave;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  late final TextEditingController _note =
      TextEditingController(text: widget.initialNote);
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(bool handled) async {
    setState(() {
      _busy = true;
      _failed = false;
    });
    final saved = await widget.onSave(handled, _note.text.trim());
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(handled);
    } else {
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTextStyles.headline),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: AppTextStyles.caption),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLength: 1000,
              minLines: 3,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Ghi chú của chủ quán',
                hintText: 'Ví dụ: Đã hỏi nhân viên, đếm lại bình sữa.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Đã xử lý chỉ là trạng thái công việc; không đổi số liệu hay kết quả chênh lệch.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
            if (_failed) ...[
              const SizedBox(height: 10),
              const Text(
                'Chưa lưu được. Hãy kiểm tra kết nối và thử lại.',
                style: TextStyle(
                  color: AppColors.statusCritical,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : () => _save(widget.initialHandled),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Lưu ghi chú'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _save(!widget.initialHandled),
              icon: Icon(widget.initialHandled
                  ? Icons.undo_rounded
                  : Icons.done_all_rounded),
              label: Text(widget.initialHandled
                  ? 'Đánh dấu chưa xử lý'
                  : 'Đánh dấu đã xử lý'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showReviewSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String initialNote,
  required bool initialHandled,
  required Future<bool> Function(bool handled, String note) onSave,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusCard)),
      ),
      builder: (context) => ReviewSheet(
        title: title,
        subtitle: subtitle,
        initialNote: initialNote,
        initialHandled: initialHandled,
        onSave: onSave,
      ),
    );

enum CorrectionKind { waste, purchase }

/// Lưu số lượng đã sửa; trả về `true` khi database đã nhận.
typedef CorrectionSaver = Future<bool> Function(int newQty, String reason);

/// Sheet sửa số lượng của một phiếu nhập hoặc một lần ghi hao hụt.
/// Dòng gốc vẫn còn: database ghi thêm một dòng điều chỉnh kèm lý do.
class CorrectionSheet extends StatefulWidget {
  const CorrectionSheet({
    super.key,
    required this.title,
    required this.subtitle,
    required this.unit,
    required this.currentQty,
    required this.onSave,
  });

  final String title;
  final String subtitle;
  final String unit;
  final int currentQty;
  final CorrectionSaver onSave;

  @override
  State<CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends State<CorrectionSheet> {
  late final TextEditingController _qty =
      TextEditingController(text: '${widget.currentQty}');
  final TextEditingController _reason = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qty.text.trim());
    if (qty == null || qty < 0) {
      setState(() => _error = 'Số lượng phải là số từ 0 trở lên.');
      return;
    }
    if (qty == widget.currentQty) {
      setState(() => _error = 'Số lượng chưa thay đổi.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _error = 'Hãy nhập lý do sửa.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final saved = await widget.onSave(qty, _reason.text.trim());
    if (!mounted) return;
    if (saved) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = 'Chưa lưu được. Hãy kiểm tra kết nối và thử lại.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + inset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: AppTextStyles.headline),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: AppTextStyles.caption),
            const SizedBox(height: 14),
            TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Số lượng đúng (${reconcileUnit(widget.unit)})',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Lý do sửa',
                hintText: 'Ví dụ: Nhập nhầm số, đếm lại thấy ít hơn.',
              ),
            ),
            const SizedBox(height: 4),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Dòng gốc vẫn được giữ. Hệ thống ghi thêm một dòng điều chỉnh kèm lý do và tính lại báo cáo.',
                    style: AppTextStyles.caption,
                  ),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.statusCritical,
                  fontSize: AppFontSizes.s13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu số lượng mới'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showCorrectionSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String unit,
  required int currentQty,
  required CorrectionSaver onSave,
}) =>
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppSizes.radiusCard)),
      ),
      builder: (context) => CorrectionSheet(
        title: title,
        subtitle: subtitle,
        unit: unit,
        currentQty: currentQty,
        onSave: onSave,
      ),
    );
