// lib/config/ta_calc_helpers.dart
// Small shared helpers used across the TA form screens.

const List<String> _monthNames = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];

/// Converts a lowercase month name (e.g. "june") to its 1-based month
/// number (1-12). Falls back to the current month if not recognized.
int monthNameToNumber(String monthName) {
  final index = _monthNames.indexOf(monthName.toLowerCase());
  if (index == -1) return DateTime.now().month;
  return index + 1;
}

const List<String> _monthShortNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Converts a month name (any case, e.g. "june"/"June") to its 3-letter
/// short form (e.g. "Jun"). Falls back to a capitalized version of the
/// input if not recognized.
String monthNameToShort(String monthName) {
  final index = _monthNames.indexOf(monthName.toLowerCase());
  if (index == -1) {
    return monthName.isEmpty
        ? monthName
        : monthName[0].toUpperCase() + monthName.substring(1);
  }
  return _monthShortNames[index];
}
