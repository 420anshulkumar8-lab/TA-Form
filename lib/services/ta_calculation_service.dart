// lib/services/ta_calculation_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Computes the auto-calculated amount for a travel leg based on departure
// and arrival time, aggregates trip/grand totals, and provides the
// From/To/Date auto-suggest logic used when a leg is added to a Trip.
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

  /// Auto-calculated amount for one leg. Returns 0 if departure or arrival
  /// time is missing (amount is only computed once both are set).
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

  /// Sums all leg amounts within one trip.
  static double tripTotal(List<TripRow> legs) {
    return legs.fold(0.0, (sum, r) => sum + r.rateAmount);
  }

  /// Grand TA total across all trips.
  static double grandTaTotal(List<TripGroup> trips) {
    return trips.fold(0.0, (sum, t) => sum + t.tripTotal);
  }

  /// Grand Contingent total across all entries.
  static double grandContingentTotal(List<ContingentEntry> entries) {
    return entries.fold(0.0, (sum, e) => sum + e.amount);
  }

  // ── Auto-suggest helpers ──────────────────────────────────────────────
  //
  // When a new leg is appended to a trip, we suggest:
  //   • From = the previous leg's "To" (the journey continues from there)
  //   • To   = the trip's very first leg's "From" (assume a round trip back
  //            to the starting point — the headquarters)
  //   • Date = the trip's first leg's date (assume same-day travel)
  //
  // These are only *suggestions* — flagged with `xIsSuggested = true` so the
  // UI can render them in the lighter "unconfirmed" style. The moment the
  // user taps and confirms/edits a cell, the caller clears that flag.

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

  /// Builds a new leg for a trip, pre-filled with suggested From/To/Date
  /// based on the trip's existing legs.
  static TripRow buildSuggestedLeg(List<TripRow> existingLegs) {
    final suggestedFrom = suggestFromForNewLeg(existingLegs);
    final suggestedTo = suggestToForNewLeg(existingLegs);
    final suggestedDate = suggestDateForNewLeg(existingLegs);

    return TripRow(
      fromLocation: suggestedFrom,
      fromIsSuggested: suggestedFrom.isNotEmpty,
      toLocation: suggestedTo,
      toIsSuggested: suggestedTo.isNotEmpty,
      date: suggestedDate,
      dateIsSuggested: suggestedDate.isNotEmpty,
    );
  }

  /// Re-derives the suggested To/From chain for every leg in a trip after
  /// an edit — called whenever a leg's From/To changes, so downstream
  /// (not-yet-confirmed) legs stay consistent with the new chain. Only legs
  /// still flagged as suggested are touched; anything the user has already
  /// confirmed is left alone.
  static List<TripRow> recalculateChain(List<TripRow> legs) {
    if (legs.isEmpty) return legs;
    final updated = List<TripRow>.from(legs);
    final tripStartFrom = updated.first.fromLocation;

    for (int i = 1; i < updated.length; i++) {
      final prev = updated[i - 1];
      final current = updated[i];

      var next = current;
      if (current.fromIsSuggested) {
        next = next.copyWith(fromLocation: prev.toLocation);
      }
      // Last leg's "To" suggestion always chains back to the trip start.
      if (i == updated.length - 1 && current.toIsSuggested) {
        next = next.copyWith(toLocation: tripStartFrom);
      }
      updated[i] = next;
    }
    return updated;
  }
}
