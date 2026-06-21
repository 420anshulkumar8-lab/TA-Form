// lib/widgets/stats_strip_widget.dart
// ─────────────────────────────────────────────────────────────────────────────
// A single-line, no-tap summary strip for the Home screen: how many months
// this year have been filled, and the total amount across them. Purely
// informational — no navigation, no extra taps, keeps the app simple.
// ─────────────────────────────────────────────────────────────────────────────
import 'package:flutter/material.dart';
import '../models/ta_session.dart';
import '../services/hive_service.dart';

class StatsStripWidget extends StatelessWidget {
  final String employeeNo;

  const StatsStripWidget({super.key, required this.employeeNo});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final sessions = HiveService.getSessionsForEmployee(employeeNo)
        .where((s) =>
            s.year == now.year.toString() &&
            s.status == SessionStatus.submitted)
        .toList();

    final filledCount = sessions.length;
    final totalAmount =
        sessions.fold<double>(0, (sum, s) => sum + s.totalAmount);

    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.insights_outlined,
              size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This Year: $filledCount month${filledCount == 1 ? '' : 's'} filled, '
              'Rs. ${totalAmount.toStringAsFixed(0)} total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
