// lib/widgets/ta_table_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Renders a read-only scrollable table of all TA rows from a TaFormData object.
// Used in draft preview (form view) and any read-only summary screen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/trip_model.dart';

class TaTableWidget extends StatelessWidget {
  final TaFormData taData;
  final bool showTotals;

  const TaTableWidget({
    super.key,
    required this.taData,
    this.showTotals = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allRows =
        taData.trips.expand((t) => t.rows).toList();
    final travelRows =
        allRows.where((r) => r.rowType == RowType.travel).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Text(
          'Travel Allowance — ${taData.month.isNotEmpty ? '${taData.month[0].toUpperCase()}${taData.month.substring(1)} ' : ''}${taData.year}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        // ── Data table ────────────────────────────────────────────────────
        DataTable(
          headingRowColor: WidgetStatePropertyAll(
            theme.colorScheme.primary.withOpacity(0.08),
          ),
          border: TableBorder.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          columnSpacing: 12,
          headingTextStyle: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.primary,
          ),
          dataTextStyle: theme.textTheme.bodySmall,
          columns: const [
            DataColumn(label: Text('Date')),
            DataColumn(label: Text('Veh #')),
            DataColumn(label: Text('Dep')),
            DataColumn(label: Text('Arr')),
            DataColumn(label: Text('From')),
            DataColumn(label: Text('To')),
            DataColumn(label: Text('Km'), numeric: true),
            DataColumn(label: Text('D/N')),
            DataColumn(label: Text('Purpose')),
            DataColumn(label: Text('Amt (Rs)'), numeric: true),
          ],
          rows: travelRows
              .map((r) => DataRow(cells: [
                    DataCell(Text(r.date)),
                    DataCell(Text(r.vehicleNumber,
                        overflow: TextOverflow.ellipsis)),
                    DataCell(Text(r.departureTime)),
                    DataCell(Text(r.arrivalTime)),
                    DataCell(Text(r.fromLocation,
                        overflow: TextOverflow.ellipsis)),
                    DataCell(Text(r.toLocation,
                        overflow: TextOverflow.ellipsis)),
                    DataCell(
                        Text(r.distanceKm.toStringAsFixed(0))),
                    DataCell(Text(r.dayNight)),
                    DataCell(SizedBox(
                      width: 100,
                      child: Text(r.purpose,
                          overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(
                        r.rateAmount.toStringAsFixed(2))),
                  ]))
              .toList(),
        ),

        // ── Totals ────────────────────────────────────────────────────────
        if (showTotals) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  theme.colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color:
                      theme.colorScheme.primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _TotalRow('Travel Total:',
                    'Rs. ${taData.grandTravelTotal.toStringAsFixed(2)}',
                    theme),
                _TotalRow('DA Total:',
                    'Rs. ${taData.grandDaTotal.toStringAsFixed(2)}',
                    theme),
                const Divider(height: 12),
                _TotalRow(
                  'Grand Total:',
                  'Rs. ${taData.grandTotal.toStringAsFixed(2)}',
                  theme,
                  bold: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final bool bold;

  const _TotalRow(this.label, this.value, this.theme,
      {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? theme.textTheme.titleSmall
            ?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label, style: style),
          const SizedBox(width: 12),
          Text(value, style: style),
        ],
      ),
    );
  }
}
