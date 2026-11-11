import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/inventory_view.dart';

final _money = NumberFormat('#,##0.##', 'vi_VN');
final _units = NumberFormat.decimalPattern('vi_VN');

String formatProductPrice(num price) => '${_money.format(price)} đ';
String formatProductUnits(int units) => _units.format(units);

class InventoryBackButton extends StatelessWidget {
  const InventoryBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Quay lại',
    onPressed: () => Navigator.maybePop(context),
    icon: const Icon(Icons.arrow_back_rounded),
  );
}

class StockBadge extends StatelessWidget {
  const StockBadge({super.key, required this.hasStock});

  final bool hasStock;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: hasStock ? const Color(0xffe5f3eb) : const Color(0xffffefd8),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          hasStock ? 'Còn hàng' : 'Hết hàng',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: hasStock ? const Color(0xff1c5a3d) : const Color(0xff774614),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class InventorySummaryBar extends StatelessWidget {
  const InventorySummaryBar({
    super.key,
    required this.summary,
    required this.wide,
  });

  final InventorySummary summary;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = [
      ('Số mặt hàng', formatProductUnits(summary.productCount)),
      ('Tổng số lượng tồn', groupInventoryDigits(summary.unitCount.toString())),
      ('Tổng giá trị tồn', '${summary.totalValue} đ'),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff103d34),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: EdgeInsets.all(wide ? 24 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thống kê toàn bộ danh sách sản phẩm',
              style: theme.textTheme.titleSmall?.copyWith(
                color: const Color(0xffbce4d4),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (label, value) in metrics)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _SummaryLabel(label),
                            const SizedBox(height: 4),
                            _SummaryValue(value, wide: true),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              for (final (label, value) in metrics)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: _SummaryLabel(label)),
                      const SizedBox(width: 10),
                      Flexible(child: _SummaryValue(value, wide: false)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLabel extends StatelessWidget {
  const _SummaryLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: const Color(0xffe3f4ed)),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue(this.value, {required this.wide});

  final String value;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: wide ? Alignment.centerLeft : Alignment.centerRight,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          style: (wide ? text.headlineSmall : text.titleMedium)?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
