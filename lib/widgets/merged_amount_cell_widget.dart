// lib/widgets/merged_amount_cell_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Renders the "Amount" column for one unique date as a single merged cell
// spanning all rows (across ALL trips) that share that date. The user picks
// the amount from a dropdown (4 options based on their Level).
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../config/ta_rates.dart';

class MergedAmountCellWidget extends StatelessWidget {
  final double width;
  final double rowHeight;
  final int rowCount; // how many rows share this date
  final double amount; // currently selected (0 = not yet chosen)
  final int employeeLevel;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const MergedAmountCellWidget({
    super.key,
    required this.width,
    required this.rowHeight,
    required this.rowCount,
    required this.amount,
    required this.employeeLevel,
    required this.enabled,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context) async {
    final options = TaRates.optionsForLevel(employeeLevel);
    final picked = await showModalBottomSheet<double>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Amount (Rs.)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            for (final opt in options)
              ListTile(
                title: Text('Rs. ${TaRates.format(opt)}'),
                trailing: amount == opt
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () => Navigator.pop(ctx, opt),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalHeight = rowHeight * rowCount;
    final isEmpty = amount == 0;

    return SizedBox(
      width: width,
      height: totalHeight,
      child: InkWell(
        onTap: enabled ? () => _pick(context) : null,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.25)),
              bottom: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            isEmpty ? '—' : 'Rs.\n${TaRates.format(amount)}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isEmpty ? Colors.grey : null,
            ),
          ),
        ),
      ),
    );
  }
}
