part of 'bill_screen.dart';

class _LinesTab extends StatelessWidget {
  const _LinesTab({
    super.key,
    required this.controller,
    required this.servingLabel,
    required this.onVoid,
    required this.onDiscount,
    required this.onGoMenu,
  });

  final BillController controller;
  final String servingLabel;
  final void Function(BillLine) onVoid;
  final VoidCallback onDiscount;
  final VoidCallback onGoMenu;

  @override
  Widget build(BuildContext context) {
    final bill = controller.bill!;
    if (bill.lines.isEmpty) {
      return EmptyState(
        icon: ForeIcons.bag,
        title: 'Bill chưa có món',
        message: 'Chọn món ở tab Gọi món rồi bấm Thêm vào bill.',
        actionLabel: bill.isOpen ? 'Gọi món' : null,
        onAction: onGoMenu,
      );
    }
    return LazyListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        ForeCard(
          radius: 20,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (var i = 0; i < bill.lines.length; i++) ...[
                if (i > 0) const Divider(),
                _LineRow(
                  line: bill.lines[i],
                  canVoid: bill.isOpen && !controller.busy,
                  onVoid: () => onVoid(bill.lines[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        ForeCard(
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _TotalRow('Tạm tính', formatVnd(bill.subtotal)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                      child: Text('Giảm giá', style: AppTextStyles.body)),
                  if (bill.isOpen)
                    TextButton(
                      onPressed: controller.busy ? null : onDiscount,
                      child: Text(bill.discount > 0 ? 'Sửa' : 'Thêm'),
                    ),
                  Text(
                    bill.discount > 0 ? '-${formatVnd(bill.discount)}' : '0đ',
                    style: AppTextStyles.bodyStrong,
                  ),
                ],
              ),
              if (bill.discount > 0 && (bill.discountReason ?? '').isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Lý do: ${bill.discountReason}',
                      style: AppTextStyles.caption),
                ),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Phải thu (${formatServings(bill.portions, servingLabel)})',
                      style: AppTextStyles.title,
                    ),
                  ),
                  Text(formatVnd(bill.payable), style: AppTextStyles.number),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(label, style: AppTextStyles.body)),
          Text(value, style: AppTextStyles.bodyStrong),
        ],
      );
}

class _LineRow extends StatelessWidget {
  const _LineRow(
      {required this.line, required this.canVoid, required this.onVoid});

  final BillLine line;
  final bool canVoid;
  final VoidCallback onVoid;

  @override
  Widget build(BuildContext context) {
    final voided = line.voided;
    final strike = voided ? TextDecoration.lineThrough : TextDecoration.none;
    final color = voided ? AppColors.textMuted : AppColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '${line.qty}×',
              style: TextStyle(
                  fontSize: AppFontSizes.s15,
                  fontWeight: FontWeight.w700,
                  color: color,
                  decoration: strike),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.itemName,
                  style: TextStyle(
                      fontSize: AppFontSizes.s15,
                      fontWeight: FontWeight.w600,
                      color: color,
                      decoration: strike),
                ),
                Text(
                  '${line.sizeName} · ${formatVnd(line.unitPrice)}${voided ? ' · Đã bỏ' : ''}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatVnd(line.total),
                style: TextStyle(
                    fontSize: AppFontSizes.s15,
                    fontWeight: FontWeight.w700,
                    color: color,
                    decoration: strike),
              ),
              if (canVoid && !voided)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onVoid,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'Bỏ',
                      style: TextStyle(
                          fontSize: AppFontSizes.s13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.statusOff),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- thanh toán
