// lib/services/ta_calculation_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Computes the auto-calculated amount for a travel row based on departure
// and arrival time, and aggregates trip/grand totals (TA + Contingent).
// ─────────────────────────────────────────────────────────────────────────────

import '../config/ta_rates.dart';
import '../models/trip_model.dart';
import '../models/contingent_model.dart';

class TaCalculationService {
  /// Parses "HH:MM" into minutes-since-midnight. Returns null if invalid.
  static int? _parseMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  /// Duration between departure and arrival, handling overnight journeys
  /// (arrival time numerically smaller than departure means it rolled past
  /// midnight, so we add 24h).
  static Duration? durationBetween(String departure, String arrival) {
    final dep = _parseMinutes(departure);
    final arr = _parseMinutes(arrival);
    if (dep == null || arr == null) return null;

    int diff = arr - dep;
    if (diff < 0) diff += 24 * 60;
    return Duration(minutes: diff);
  }

  /// Auto-calculated amount for one travel row. Returns 0 if departure or
  /// arrival time is missing (amount is only computed once both are set).
  static double amountForRow({
    required int level,
    required String departureTime,
    required String arrivalTime,
  }) {
    if (departureTime.isEmpty || arrivalTime.isEmpty) return 0;
    final duration = durationBetween(departureTime, arrivalTime);
    if (duration == null) return 0;
    return TaRates.amountForDuration(level, duration);
  }

  /// Sums all travel-row amounts in a trip.
  static double tripTravelTotal(List<TripRow> rows) {
    return rows
        .where((r) => r.rowType == RowType.travel)
        .fold(0.0, (sum, r) => sum + r.rateAmount);
  }

  /// Sums all stay-row DA amounts in a trip.
  static double tripDaTotal(List<TripRow> rows) {
    return rows
        .where((r) => r.rowType == RowType.stay)
        .fold(0.0, (sum, r) => sum + r.daAmount);
  }

  /// Grand Contingent total across all entries.
  static double grandContingentTotal(List<ContingentEntry> entries) {
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }
}
