import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/application/load_phase.dart';
import '../../../core/design/app_sheet.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/error_state.dart';
import '../../../core/design/primary_button.dart';
import '../../../core/design/secondary_button.dart';
import '../../../core/design/spacing.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/failure_messages.dart';
import '../../../core/format.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/notify.dart';
import '../../../core/widgets/status_chip.dart';
import '../application/async_data.dart';
import '../application/count_controller.dart';
import '../application/kho_format.dart';
import '../domain/kho_models.dart';
import '../domain/kho_repository.dart';
import 'kho_widgets.dart';
import '../../../core/widgets/lazy_list_view.dart';

// ======================================================================
// Đếm kho mù (nhân viên "Kiểm kê trong ca"; chủ cũng dùng được)
// ======================================================================
class CountScreen extends StatefulWidget {
  const CountScreen({super.key, this.stocktakeId});

  /// Mở lại một phiếu có sẵn; bỏ trống để bắt đầu/tiếp tục phiếu nháp của bạn.
  final String? stocktakeId;

  @override
  State<CountScreen> createState() => _CountScreenState();
}

class _CountScreenState extends State<CountScreen> {
  late final CountController _c = CountController(context.read<KhoRepository>());
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.stocktakeId == null ? _c.start() : _c.openExisting(widget.stocktakeId!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_c.hasUnsaved && !_c.locked) {
      // Lưu nốt những gì đã gõ để nháp không mất khi thoát màn hình.
      unawaited(_c.saveDraft().catchError((Object _) => false));
    }
    _c.dispose();
    super.dispose();
  }

  void _changed(String id, int? qty) {
    _c.setQty(id, qty);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 1500), () async {
      try {
        await _c.saveDraft();
      } on Object {
        // Lưu tự động không báo lỗi; nút "Lưu nháp" sẽ báo nếu người dùng bấm.
      }
    });
  }

  Future<void> _saveDraft() async {
    final ok = await guarded(context, _c.saveDraft);
    if (ok == true && mounted) {
      showNotice(context, 'Đã lưu nháp. Số đã đếm vẫn còn nguyên.');
    }
  }

  Future<void> _submit() async {
    final ok = await guarded(context, _c.submit);
    if (ok == true && mounted) {
      showNotice(context, 'Đã gửi ${_c.sheet?.code ?? ''} cho chủ quán duyệt.');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final s = _c.sheet;
          if (_c.phase == LoadPhase.error) {
            return KhoPage(
              title: 'Kiểm kê trong ca',
              body: ErrorState(
                  message: _c.failure?.userMessage ?? 'Không mở được phiếu.',
                  onRetry: _c.start),
            );
          }
          if (s == null) {
            return const KhoPage(title: 'Kiểm kê trong ca', body: KhoSkeleton());
          }
          final recount = s.status == StocktakeStatus.recount;
          final groups =
              groupBy<CountLine>(_c.activeLines, (l) => l.group);
          return KhoPage(
            title: recount ? 'Đếm lại theo yêu cầu' : 'Kiểm kê trong ca',
            subtitle:
                '${s.code} · Đã đếm ${_c.countedCount}/${_c.totalCount}',
            bottom: _c.locked
                ? null
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    PrimaryButton(
                      label: _c.complete
                          ? 'Gửi chủ duyệt'
                          : 'Gửi chủ duyệt · còn ${_c.totalCount - _c.countedCount} dòng',
                      loading: _c.busy,
                      onPressed: _c.complete ? _submit : null,
                    ),
                    const SizedBox(height: 8),
                    SecondaryButton(
                        label: 'Lưu nháp', onPressed: _c.busy ? null : _saveDraft),
                  ]),
            body: LazyListView(
              padding: const EdgeInsets.all(AppSizes.pagePadding),
              children: [
                LinearProgressIndicator(
                  value: _c.totalCount == 0 ? 0 : _c.countedCount / _c.totalCount,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 12),
                if (recount && s.reviewNote != null)
                  KhoNote('Chủ quán nhắn: ${s.reviewNote}',
                      icon: Icons.mark_chat_unread_outlined)
                else
                  const KhoNote(
                      'Đếm mù: bạn không thấy số hệ thống. Chưa đếm khác với 0, hãy nhập 0 nếu hết hàng.',
                      icon: Icons.visibility_off_outlined),
                if (_c.locked) ...[
                  const SizedBox(height: 12),
                  const KhoNote(
                      'Phiếu này đã gửi hoặc đã duyệt nên không sửa được nữa.',
                      icon: Icons.lock_outline_rounded),
                ],
                for (final e in groups.entries) ...[
                  KhoSectionTitle(e.key),
                  for (final l in e.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CountRow(
                        key: ValueKey(l.ingredientId),
                        line: l,
                        initial: _c.qtyOf(l.ingredientId),
                        enabled: l.editable && !_c.locked,
                        onChanged: (q) => _changed(l.ingredientId, q),
                      ),
                    ),
                ],
              ],
            ),
          );
        },
      );
}

class _CountRow extends StatefulWidget {
  const _CountRow({
    super.key,
    required this.line,
    required this.initial,
    required this.enabled,
    required this.onChanged,
  });

  final CountLine line;
  final int? initial;
  final bool enabled;
  final ValueChanged<int?> onChanged;

  @override
  State<_CountRow> createState() => _CountRowState();
}

class _CountRowState extends State<_CountRow> {
  late final _t = TextEditingController(
      text: widget.initial == null
          ? ''
          : khoQtyInput(widget.initial!, widget.line.unit));
  String? _error;

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      setState(() => _error = null);
      return widget.onChanged(null);
    }
    final q = parseKhoQty(text, widget.line.unit);
    setState(() => _error = q == null ? 'Nhập số, ví dụ 12 hoặc 2,5' : null);
    widget.onChanged(q);
  }

  @override
  Widget build(BuildContext context) => KhoCard(
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.line.name, style: AppTextStyles.cardTitle),
                Text(
                    widget.initial == null ? 'Chưa đếm' : 'Đã đếm',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(
              controller: _t,
              enabled: widget.enabled,
              textAlign: TextAlign.end,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: '0',
                suffixText: displayUnit(widget.line.unit),
                errorText: _error,
              ),
            ),
          ),
        ]),
      );
}

// ======================================================================
// Danh sách kiểm kê (chủ)
// ======================================================================
class StocktakeListScreen extends StatefulWidget {
  const StocktakeListScreen({super.key});

  @override
  State<StocktakeListScreen> createState() => _StocktakeListScreenState();
}

class _StocktakeListScreenState extends State<StocktakeListScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<List<StocktakeSummary>> _data =
      AsyncData(() => _repo.stocktakes())..load();
  int _tab = 0;

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

  String _statusLabel(StocktakeSummary k) => switch (k.status) {
        StocktakeStatus.draft => 'Đang đếm',
        StocktakeStatus.submitted => 'Chờ duyệt',
        StocktakeStatus.recount => 'Chờ đếm lại',
        StocktakeStatus.approved => 'Đã duyệt',
      };

  @override
  Widget build(BuildContext context) => KhoPage(
        title: 'Kiểm kê',
        subtitle: 'Đếm, đối chiếu và duyệt điều chỉnh',
        bottom: PrimaryButton(
            label: 'Tự đếm kho',
            onPressed: () => _open(const CountScreen())),
        body: AsyncView<List<StocktakeSummary>>(
          source: _data,
          builder: (context, all) {
            final list = all
                .where((k) => _tab == 0
                    ? k.status != StocktakeStatus.approved
                    : k.status == StocktakeStatus.approved)
                .toList();
            return [
              KhoChipBar(
                  labels: const ['Cần xử lý', 'Đã duyệt'],
                  selected: _tab,
                  onSelected: (i) => setState(() => _tab = i)),
              const SizedBox(height: 12),
              if (list.isEmpty) const KhoNote('Chưa có phiếu kiểm kê nào ở mục này.'),
              for (final k in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: KhoCard(
                    onTap: k.status == StocktakeStatus.draft
                        ? null
                        : () => _open(StocktakeReviewScreen(stocktakeId: k.id)),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${k.code} · ${k.staffName}',
                                style: AppTextStyles.cardTitle),
                            Text(
                              [
                                if (k.submittedAt != null)
                                  formatDateTimeShort(k.submittedAt!),
                                '${k.lineCount} dòng',
                                if (k.status != StocktakeStatus.draft)
                                  k.varianceLines == 0
                                      ? 'Không lệch'
                                      : '${k.varianceLines} dòng lệch',
                              ].join(' · '),
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      StatusChip(
                        label: _statusLabel(k),
                        severity: k.status == StocktakeStatus.submitted
                            ? StatusSeverity.attention
                            : StatusSeverity.neutral,
                        compact: true,
                      ),
                    ]),
                  ),
                ),
            ];
          },
        ),
      );
}

// ======================================================================
// Chênh lệch sau đếm (chủ)
// ======================================================================
class StocktakeReviewScreen extends StatefulWidget {
  const StocktakeReviewScreen({super.key, required this.stocktakeId});

  final String stocktakeId;

  @override
  State<StocktakeReviewScreen> createState() => _StocktakeReviewScreenState();
}

class _StocktakeReviewScreenState extends State<StocktakeReviewScreen> {
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final AsyncData<StocktakeDetail> _data =
      AsyncData(() => _repo.stocktakeDetail(widget.stocktakeId))..load();
  bool _busy = false;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _decide(StocktakeDetail d) async {
    final done = await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => AdjustDecisionScreen(detail: d)));
    if (done == true && mounted) _data.load(silent: true);
  }

  Future<void> _approveClean(StocktakeDetail d) async {
    setState(() => _busy = true);
    final r = await guarded(
      context,
      () => _repo.approveStocktake(d.id,
          adjustByIngredient: const {}, reason: 'Đếm khớp hệ thống'),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      showNotice(context, 'Đã duyệt ${r.code}. Không cần điều chỉnh.');
      _data.load(silent: true);
    }
  }

  Future<void> _askRecount(StocktakeDetail d) async {
    final picked = <String>{};
    final note = TextEditingController();
    final go = await AppSheet.show<bool>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AppSheet(
          title: 'Yêu cầu đếm lại',
          footer: PrimaryButton(
            label: 'Gửi yêu cầu · ${picked.length} dòng',
            onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, true),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final l in d.varianceLines)
              CheckboxListTile(
                value: picked.contains(l.ingredientId),
                onChanged: (v) => setS(() => v == true
                    ? picked.add(l.ingredientId)
                    : picked.remove(l.ingredientId)),
                title: Text(l.name),
                subtitle: Text(
                    'Lệch ${formatKhoQty(l.variance ?? 0, l.unit, signed: true)}'),
              ),
            AppTextField(label: 'Lời nhắn cho nhân viên', controller: note),
          ]),
        ),
      ),
    );
    final text = note.text;
    note.dispose();
    if (go != true || !mounted) return;
    final ok = await guarded(context, () async {
      await _repo.requestRecount(d.id, picked.toList(), text);
      return true;
    });
    if (ok == true && mounted) {
      showNotice(context, 'Đã nhờ ${d.staffName} đếm lại ${picked.length} dòng.');
      _data.load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _data,
        builder: (context, _) {
          final d = _data.data;
          final pending = d?.status == StocktakeStatus.submitted;
          return KhoPage(
            title: 'Chênh lệch sau đếm',
            subtitle: d == null
                ? null
                : '${d.code} · ${d.staffName}${d.submittedAt == null ? '' : ' · ${formatDateTimeShort(d.submittedAt!)}'}',
            bottom: d == null || !pending
                ? null
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    if (d.varianceLines.isEmpty)
                      PrimaryButton(
                          label: 'Duyệt · đếm khớp hệ thống',
                          loading: _busy,
                          onPressed: () => _approveClean(d))
                    else ...[
                      PrimaryButton(
                          label: 'Xem quyết định điều chỉnh',
                          onPressed: () => _decide(d)),
                      const SizedBox(height: 8),
                      SecondaryButton(
                          label: 'Yêu cầu đếm lại',
                          onPressed: () => _askRecount(d)),
                    ],
                  ]),
            body: AsyncView<StocktakeDetail>(
              source: _data,
              builder: (context, d) => _content(d),
            ),
          );
        },
      );

  List<Widget> _content(StocktakeDetail d) {
    final variance = d.varianceLines;
    final matched = d.lines.length - variance.length;
    return [
      if (d.status == StocktakeStatus.approved)
        KhoNote(
            'Đã duyệt${d.reviewerName == null ? '' : ' bởi ${d.reviewerName}'}${d.reviewedAt == null ? '' : ' lúc ${formatDateTimeShort(d.reviewedAt!)}'}'
            '${d.reviewReason == null ? '' : ' · Lý do: ${d.reviewReason}'}',
            icon: Icons.verified_outlined),
      if (d.status == StocktakeStatus.recount)
        const KhoNote('Đang chờ nhân viên đếm lại các dòng bạn yêu cầu.',
            icon: Icons.hourglass_top_rounded),
      const SizedBox(height: 8),
      KhoCard(
        child: Column(children: [
          LabelValueRow('Thiếu', formatSignedVnd(d.shortValue)),
          LabelValueRow('Thừa', formatSignedVnd(d.overValue)),
          Divider(color: AppColors.cardBorder),
          LabelValueRow('Chênh lệch ròng', formatSignedVnd(d.netValue),
              strong: true),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${variance.length} dòng lệch · $matched dòng khớp',
              style: AppTextStyles.caption,
            ),
          ),
        ]),
      ),
      if (variance.isNotEmpty) const KhoSectionTitle('Dòng lệch'),
      for (final l in variance)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: KhoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(l.name, style: AppTextStyles.cardTitle)),
                  Text(
                    formatKhoQty(l.variance ?? 0, l.unit, signed: true),
                    style: AppTextStyles.bodyStrong.copyWith(
                        color: (l.variance ?? 0) < 0
                            ? AppColors.statusCritical
                            : AppColors.statusAttention),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  'Đếm ${formatKhoQty(l.countedQty ?? 0, l.unit)} · Hệ thống ${formatKhoQty(l.systemQty ?? 0, l.unit)}'
                  '${l.varianceValue == null || l.unitCost == null ? '' : ' · ${formatSignedVnd(l.varianceValue!)}'}',
                  style: AppTextStyles.caption,
                ),
                if (l.recountPrevQty != null)
                  Text(
                    l.recountPrevQty == l.countedQty
                        ? 'Đã đếm lại · kết quả không đổi'
                        : 'Đã đếm lại · lần đầu ${formatKhoQty(l.recountPrevQty!, l.unit)}',
                    style: AppTextStyles.caption,
                  ),
              ],
            ),
          ),
        ),
      if (matched > 0) ...[
        const SizedBox(height: 4),
        Text('$matched nguyên liệu đếm khớp với hệ thống.',
            style: AppTextStyles.caption),
      ],
    ];
  }
}

// ======================================================================
// Quyết định điều chỉnh (chủ)
// ======================================================================
class AdjustDecisionScreen extends StatefulWidget {
  const AdjustDecisionScreen({super.key, required this.detail});

  final StocktakeDetail detail;

  @override
  State<AdjustDecisionScreen> createState() => _AdjustDecisionScreenState();
}

class _AdjustDecisionScreenState extends State<AdjustDecisionScreen> {
  static const _reasons = [
    'Hao hụt chưa ghi',
    'Nhập hàng chưa ghi',
    'Đếm lại đã xác nhận',
    'Khác',
  ];
  late final KhoRepository _repo = context.read<KhoRepository>();
  late final Map<String, bool> _adjust = {
    for (final l in widget.detail.varianceLines) l.ingredientId: true,
  };
  final _note = TextEditingController();
  String? _reason;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _afterValue => widget.detail.stockValueNow +
      widget.detail.varianceLines
          .where((l) => _adjust[l.ingredientId] == true)
          .fold<int>(0, (a, l) => a + (l.varianceValue ?? 0));

  int get _adjustCount => _adjust.values.where((v) => v).length;

  Future<void> _confirm() async {
    final reason = _reason;
    if (reason == null) {
      return showNotice(context, 'Chọn lý do điều chỉnh để ghi vào sổ.');
    }
    if (reason == 'Khác' && _note.text.trim().length < 3) {
      return showNotice(context, 'Ghi ngắn gọn lý do ở ô ghi chú.');
    }
    final fullReason =
        reason == 'Khác' ? _note.text.trim() : reason;
    setState(() => _busy = true);
    final r = await guarded(
      context,
      () => _repo.approveStocktake(widget.detail.id,
          adjustByIngredient: _adjust,
          reason: fullReason,
          note: reason == 'Khác' ? null : _note.text),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) {
      showNotice(
          context,
          r.adjustedLines == 0
              ? 'Đã duyệt ${r.code}. Giữ nguyên tồn hệ thống.'
              : 'Đã duyệt ${r.code}. Điều chỉnh ${r.adjustedLines} dòng vào sổ kho.');
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    return KhoPage(
      title: 'Quyết định điều chỉnh',
      subtitle: '${d.code} · Bạn tự quyết định từng dòng',
      bottom: PrimaryButton(
        label: _adjustCount == 0
            ? 'Duyệt và giữ nguyên tồn'
            : 'Duyệt và điều chỉnh $_adjustCount dòng',
        loading: _busy,
        onPressed: _confirm,
      ),
      body: LazyListView(
        padding: const EdgeInsets.all(AppSizes.pagePadding),
        children: [
          const KhoNote(
              'Điều chỉnh được ghi thành một dòng trong sổ kho, kèm lý do và tên bạn. Không tạo thêm hao hụt.',
              icon: Icons.menu_book_outlined),
          const SizedBox(height: 12),
          for (final l in d.varianceLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KhoCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.name, style: AppTextStyles.cardTitle),
                    Text(
                        'Hệ thống ${formatKhoQty(l.systemQty ?? 0, l.unit)} → đếm ${formatKhoQty(l.countedQty ?? 0, l.unit)}'
                        '${l.varianceValue == null ? '' : ' · ${formatSignedVnd(l.varianceValue!)}'}',
                        style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: true, label: Text('Điều chỉnh')),
                        ButtonSegment(value: false, label: Text('Giữ nguyên')),
                      ],
                      selected: {_adjust[l.ingredientId] ?? true},
                      onSelectionChanged: (s) =>
                          setState(() => _adjust[l.ingredientId] = s.first),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 4),
          KhoCard(
            child: Column(children: [
              LabelValueRow('Giá trị tồn hiện tại', formatVnd(d.stockValueNow)),
              LabelValueRow('Giá trị tồn sau điều chỉnh', formatVnd(_afterValue),
                  strong: true),
            ]),
          ),
          const KhoSectionTitle('Lý do (bắt buộc)'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _reasons)
              ChoiceChip(
                label: Text(r),
                selected: _reason == r,
                onSelected: (_) => setState(() => _reason = r),
              ),
          ]),
          const SizedBox(height: 12),
          AppTextField(
              label: _reason == 'Khác' ? 'Lý do *' : 'Ghi chú thêm',
              controller: _note),
        ],
      ),
    );
  }
}
