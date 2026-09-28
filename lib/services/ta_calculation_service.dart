// lib/services/ta_calculation_service.dart

import '../models/trip_model.dart';
import '../models/contingent_model.dart';

class TaCalculationService {
  // ── Grand totals ──────────────────────────────────────────────────────────

  /// Grand TA total = sum of all unique-date amounts.
  static double grandTaTotal(Map<String, double> dateAmounts) {
    return dateAmounts.values.fold(0.0, (sum, v) => sum + v);
  }

  /// Grand Contingent total.
  static double grandContingentTotal(List<ContingentEntry> entries) {
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }

  // ── Auto-suggest helpers ──────────────────────────────────────────────────
  // All auto-suggestion (Date, From, To) is disabled: a newly added row
  // always starts fully empty, showing the plain placeholder text instead
  // of copying/pre-filling values from adjacent rows.

  static String suggestFromForNewLeg(List<TripRow> existingLegs) => '';

  static String suggestToForNewLeg(List<TripRow> existingLegs) => '';

  static String suggestDateForNewLeg(List<TripRow> existingLegs) => '';

  static TripRow buildSuggestedLeg(List<TripRow> existingLegs) {
    return const TripRow(); // fully empty — every field at its default
  }

  // No-op now that suggestions are disabled — rows no longer carry a
  // fromIsSuggested/toIsSuggested flag that needs re-syncing after edits.
  // Kept (returning legs unchanged) so existing call sites don't need to
  // change.
  static List<TripRow> recalculateChain(List<TripRow> legs) => legs;

  // ── Date-amount map helpers ───────────────────────────────────────────────

  /// Collects all unique dates across all trips (preserving first-seen order).
  static List<String> uniqueDatesInOrder(List<TripGroup> trips) {
    final seen = <String>[];
    for (final trip in trips) {
      for (final leg in trip.legs) {
        if (leg.date.isNotEmpty && !seen.contains(leg.date)) {
          seen.add(leg.date);
        }
      }
    }
    // Sort chronologically DD/MM/YYYY
    seen.sort((a, b) {
      final pa = _parseDate(a);
      final pb = _parseDate(b);
      if (pa == null || pb == null) return 0;
      return pa.compareTo(pb);
    });
    return seen;
  }

  static DateTime? _parseDate(String ddmmyyyy) {
    final parts = ddmmyyyy.split('/');
    if (parts.length != 3) return null;
    final d = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final y = int.tryParse(parts[2]);
    if (d == null || m == null || y == null) return null;
    return DateTime(y, m, d);
  }

  // ── Day / Night auto-calculation ──────────────────────────────────────────

  /// Minutes since midnight for an "HH:MM" string. A dash ("—") — the
  /// "No Time" choice — counts as midnight (00:00). Returns null when the
  /// time hasn't been entered yet.
  static int? _minutesOf(String t) {
    if (t.isEmpty) return null;
    if (t == '—' || t == '-') return 0;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// "Night" if any part of the journey between [dep] and [arr] falls in
  /// 22:00\u201306:00, otherwise "Day". Returns '' until both times exist.
  /// If arrival is at/before departure the journey is treated as crossing
  /// midnight (arrival on the next day).
  static String dayNightFor(String dep, String arr) {
    final d = _minutesOf(dep);
    final a = _minutesOf(arr);
    if (d == null || a == null) return '';
    final start = d;
    final end = a > d ? a : a + 24 * 60; // arrival next day if <= departure
    const nightStart = 22 * 60; // 22:00
    const nightEnd = 6 * 60; // 06:00
    // Night windows on a 3-day line: [-2h..6h], [22h..30h], [46h..54h]
    for (final base in [-24 * 60, 0, 24 * 60]) {
      final ws = base + nightStart; // window start (22:00 of that day)
      final we = base + 24 * 60 + nightEnd; // window end (06:00 next day)
      if (start < we && end > ws) return 'Night';
    }
    return 'Day';
  }

  // ── Date-sequence validation ──────────────────────────────────────────────

  /// Flattens every trip's legs, in on-screen top-to-bottom order, into a
  /// single ordered list of dates (skipping empty ones — a row the user
  /// hasn't filled in yet doesn't participate in the sequence check).
  static List<String> _flattenDatesInOrder(List<TripGroup> trips) {
    final dates = <String>[];
    for (final trip in trips) {
      for (final leg in trip.legs) {
        if (leg.date.isNotEmpty) dates.add(leg.date);
      }
    }
    return dates;
  }

  /// Checks whether replacing the date at the given flattened position with
  /// [newDate] would keep the WHOLE form's dates non-decreasing top to
  /// bottom (equal dates on consecutive rows are allowed; going backwards
  /// is not). [trips] should be the CURRENT (pre-edit) state; [tripIndex]/
  /// [legIndex] identify which row is being edited.
  ///
  /// Returns null if the change is valid, or a user-facing error message if
  /// it would break the sequence.
  static String? validateDateSequence({
    required List<TripGroup> trips,
    required int tripIndex,
    required int legIndex,
    required String newDate,
  }) {
    if (newDate.isEmpty) return null; // clearing a date is always allowed
    final newParsed = _parseDate(newDate);
    if (newParsed == null) return null; // malformed — let other validation handle it

    // Find this row's position in the flattened (skipping-empty) order by
    // walking the same top-to-bottom structure, tracking the previous and
    // next non-empty dates around this specific row.
    String? prevDate;
    String? nextDate;
    bool foundSelf = false;
    for (int t = 0; t < trips.length; t++) {
      final legs = trips[t].legs;
      for (int l = 0; l < legs.length; l++) {
        final isSelf = t == tripIndex && l == legIndex;
        if (isSelf) {
          foundSelf = true;
          continue;
        }
        final d = legs[l].date;
        if (d.isEmpty) continue;
        if (!foundSelf) {
          prevDate = d; // keeps getting overwritten until we pass self
        } else if (nextDate == null) {
          nextDate = d; // first non-empty date AFTER self
        }
      }
    }

    if (prevDate != null) {
      final prevParsed = _parseDate(prevDate);
      if (prevParsed != null && newParsed.isBefore(prevParsed)) {
        return 'Date must not be earlier than the previous row\'s date '
            '($prevDate).';
      }
    }
    if (nextDate != null) {
      final nextParsed = _parseDate(nextDate);
      if (nextParsed != null && newParsed.isAfter(nextParsed)) {
        return 'Date must not be later than the next row\'s date '
            '($nextDate).';
      }
    }
    return null;
  }

  /// Rebuilds the dateAmounts map: keeps existing user-selected values,
  /// removes dates that no longer appear in any leg, adds new dates with 0.
  static Map<String, double> syncDateAmounts(
    List<TripGroup> trips,
    Map<String, double> current,
  ) {
    final activeDates = uniqueDatesInOrder(trips).toSet();
    final result = <String, double>{};
    for (final date in activeDates) {
      result[date] = current[date] ?? 0.0;
    }
    return result;
  }
}
