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

  static String suggestFromForNewLeg(List<TripRow> existingLegs) {
    if (existingLegs.isEmpty) return '';
    return existingLegs.last.toLocation;
  }

  static String suggestToForNewLeg(List<TripRow> existingLegs) {
    if (existingLegs.isEmpty) return '';
    return existingLegs.first.fromLocation;
  }

  static String suggestDateForNewLeg(List<TripRow> existingLegs) {
    if (existingLegs.isEmpty) return '';
    return existingLegs.first.date;
  }

  static TripRow buildSuggestedLeg(List<TripRow> existingLegs) {
    final sf = suggestFromForNewLeg(existingLegs);
    final st = suggestToForNewLeg(existingLegs);
    final sd = suggestDateForNewLeg(existingLegs);
    return TripRow(
      fromLocation: sf,
      fromIsSuggested: sf.isNotEmpty,
      toLocation: st,
      toIsSuggested: st.isNotEmpty,
      date: sd,
      dateIsSuggested: sd.isNotEmpty,
    );
  }

  static List<TripRow> recalculateChain(List<TripRow> legs) {
    if (legs.isEmpty) return legs;
    final updated = List<TripRow>.from(legs);
    final tripStartFrom = updated.first.fromLocation;

    for (int i = 1; i < updated.length; i++) {
      final prev = updated[i - 1];
      var current = updated[i];

      if (current.fromIsSuggested) {
        current = current.copyWith(fromLocation: prev.toLocation);
      }
      if (i == updated.length - 1 && current.toIsSuggested) {
        current = current.copyWith(toLocation: tripStartFrom);
      }
      updated[i] = current;
    }
    return updated;
  }

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
