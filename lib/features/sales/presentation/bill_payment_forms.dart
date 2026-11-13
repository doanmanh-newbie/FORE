part of 'bill_screen.dart';

class _PayForm extends StatefulWidget {
  const _PayForm({required this.amount});

  final int amount;

  @override
  State<_PayForm> createState() => _PayFormState();
}

class _PayFormState extends State<_PayForm> {
  PaymentMethod _method = PaymentMethod.cash;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: Text(formatVnd(widget.amount),
                  style: AppTextStyles.numberXL)),
          const SizedBox(height: 4),
          Center(child: Text('Số tiền phải thu', style: AppTextStyles.caption)),
          const SizedBox(height: 20),
          Row(
            children: [
              for (final m in PaymentMethod.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: m == PaymentMethod.values.last ? 0 : 10),
                    child: _MethodTile(
                      label: m.label,
                      selected: m == _method,
                      onTap: () => setState(() => _method = m),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_method),
            child: Text('Thu ${formatVnd(widget.amount)}'),
          ),
          const SizedBox(height: 4),
          Text(
            'Thanh toán xong không sửa được. Muốn hủy phải có chủ quán xác nhận.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption,
          ),
        ],
      );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile(
      {required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        selected: selected,
        label: label,
        child: ExcludeSemantics(
          child: PressableScale(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: selected ? AppColors.ink : AppColors.border,
                    width: 1.5),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: AppFontSizes.s16,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.onInk : AppColors.ink,
                ),
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------- giảm giá
class _DiscountResult {
  const _DiscountResult(this.amount, this.reason);

  final int amount;
  final String reason;
}

class _DiscountForm extends StatefulWidget {
  const _DiscountForm({required this.current, required this.max});

  final int current;
  final int max;

  @override
  State<_DiscountForm> createState() => _DiscountFormState();
}

class _DiscountFormState extends State<_DiscountForm> {
  late final TextEditingController _amount = TextEditingController(
    text:
        widget.current > 0 ? formatVnd(widget.current).replaceAll('đ', '') : '',
  );
  final _reason = TextEditingController();
  late int? _value = widget.current > 0 ? widget.current : null;

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _tooMuch => (_value ?? 0) > widget.max;
  bool get _valid =>
      _value != null &&
      _value! > 0 &&
      !_tooMuch &&
      _reason.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneyField(
            controller: _amount,
            label: 'Số tiền giảm',
            autofocus: true,
            errorText: _tooMuch ? 'Không được lớn hơn tổng tiền' : null,
            onChanged: (v) => setState(() => _value = v),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reason,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Lý do (bắt buộc)',
              hintText: 'Ví dụ: khách quen',
              counterText: '',
            ),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: _valid
                ? () => Navigator.of(context)
                    .pop(_DiscountResult(_value!, _reason.text.trim()))
                : null,
            child: const Text('Áp dụng giảm giá'),
          ),
          if (widget.current > 0) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () =>
                  Navigator.of(context).pop(const _DiscountResult(0, '')),
              child: const Text('Bỏ giảm giá'),
            ),
          ],
        ],
      );
}
