// lib/config/ta_rates.dart
// ─────────────────────────────────────────────────────────────────────────────
// TA amount is auto-calculated from the duration between departure and
// arrival time, and the employee's Level (1-9). Edit this file when
// government rates change.
// ─────────────────────────────────────────────────────────────────────────────

class TaRates {
  // Level 1-5 slabs
  static const double level1to5Upto6h = 187.5;
  static const double level1to5Upto12h = 437.5;
  static const double level1to5Above12h = 625.0;

  // Level 6-9 slabs
  static const double level6to9Upto6h = 300.0;
  static const double level6to9Upto12h = 700.0;
  static const double level6to9Above12h = 1000.0;

  /// Returns the TA amount for a single travel row given the employee's
  /// [level] (1-9) and the journey [duration].
  ///
  ///   duration <= 6h   → "upto6h" slab
  ///   6h < duration <= 12h → "upto12h" slab
  ///   duration > 12h   → "above12h" slab
  static double amountForDuration(int level, Duration duration) {
    final hours = duration.inMinutes / 60.0;
    final isHigherLevel = level >= 6;

    if (hours <= 6) {
      return isHigherLevel ? level6to9Upto6h : level1to5Upto6h;
    } else if (hours <= 12) {
      return isHigherLevel ? level6to9Upto12h : level1to5Upto12h;
    } else {
      return isHigherLevel ? level6to9Above12h : level1to5Above12h;
    }
  }
}
