// lib/config/ta_rates.dart
// ─────────────────────────────────────────────────────────────────────────────
// Amount options shown in the per-date dropdown. The user selects one value
// for each unique travel date; that same amount applies to every row on that
// date (merged cell). No auto-calculation — employee knows which slab applies.
// ─────────────────────────────────────────────────────────────────────────────

class TaRates {
  /// Options for Level 1–5 employees (ascending order for dropdown display).
  static const List<double> level1to5Options = [
    625.00,
    437.50,
    187.50,
    125.00,
  ];

  /// Options for Level 6–9 employees.
  static const List<double> level6to9Options = [
    1000.00,
    700.00,
    300.00,
    200.00,
  ];

  /// Returns the correct option list for the given employee level (1-9).
  static List<double> optionsForLevel(int level) {
    return level >= 6 ? level6to9Options : level1to5Options;
  }

  /// Formats a double amount for display: shows ".00" only when needed.
  static String format(double amount) {
    if (amount == amount.truncateToDouble()) {
      return amount.toStringAsFixed(0);
    }
    // Show up to 2 decimal places, strip trailing zero
    final s = amount.toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }
}
