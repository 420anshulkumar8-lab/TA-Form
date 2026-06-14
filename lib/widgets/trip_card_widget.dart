// lib/widgets/trip_card_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// Compact card showing a single Trip's summary (purpose, total, row count).
// Used in any card-view listing of trips.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/trip_model.dart';

class TripCardWidget extends StatelessWidget {
  final Trip trip;
  final int tripNumber;
  final VoidCallback? onTap;

  const TripCardWidget({
    super.key,
    required this.trip,
    required this.tripNumber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final travelRows =
        trip.rows.where((r) => r.rowType == RowType.travel).toList();
    final firstRow = travelRows.isNotEmpty ? travelRows.first : null;
    final lastRow = travelRows.isNotEmpty ? travelRows.last : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: theme.colorScheme.outline.withOpacity(0.2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────────────
              Row(
                children: [
                  _NumberBadge(tripNumber, theme),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      trip.purposeFormal.isNotEmpty
                          ? trip.purposeFormal
                          : 'Trip $tripNumber',
                      style: theme.textTheme.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _AmountBadge(trip.tripTotal, theme),
                ],
              ),

              if (firstRow != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      firstRow.date,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (lastRow != null &&
                        lastRow.date != firstRow.date) ...[
                      Text(
                        ' — ${lastRow.date}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 13,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${firstRow.fromLocation} → ${lastRow?.toLocation ?? ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 6),
              Row(
                children: [
                  _SubStat(
                    icon: Icons.table_rows_outlined,
                    label: '${trip.rows.length} rows',
                    theme: theme,
                  ),
                  const SizedBox(width: 12),
                  _SubStat(
                    icon: Icons.directions_car_outlined,
                    label:
                        'Travel: Rs. ${trip.tripTravelTotal.toStringAsFixed(0)}',
                    theme: theme,
                  ),
                  if (trip.tripDaTotal > 0) ...[
                    const SizedBox(width: 12),
                    _SubStat(
                      icon: Icons.hotel_outlined,
                      label: 'DA: Rs. ${trip.tripDaTotal.toStringAsFixed(0)}',
                      theme: theme,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberBadge extends StatelessWidget {
  final int number;
  final ThemeData theme;
  const _NumberBadge(this.number, this.theme);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '$number',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _AmountBadge extends StatelessWidget {
  final double amount;
  final ThemeData theme;
  const _AmountBadge(this.amount, this.theme);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Rs. ${amount.toStringAsFixed(0)}',
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _SubStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;
  const _SubStat(
      {required this.icon, required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
