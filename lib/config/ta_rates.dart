// lib/config/ta_rates.dart
// Edit this file when government rates change.

class TaRateInfo {
  final double taPerKm;
  final double daPerDay;
  const TaRateInfo({required this.taPerKm, required this.daPerDay});
}

class TaRates {
  // Exact per-level rates (from Claude_Original — more precise)
  static const Map<String, TaRateInfo> _levelRates = {
    'Level-1':  TaRateInfo(taPerKm: 0.5, daPerDay: 100),
    'Level-2':  TaRateInfo(taPerKm: 0.5, daPerDay: 100),
    'Level-3':  TaRateInfo(taPerKm: 1.0, daPerDay: 200),
    'Level-4':  TaRateInfo(taPerKm: 1.0, daPerDay: 200),
    'Level-5':  TaRateInfo(taPerKm: 1.0, daPerDay: 200),
    'Level-6':  TaRateInfo(taPerKm: 2.5, daPerDay: 250),
    'Level-7':  TaRateInfo(taPerKm: 2.5, daPerDay: 250),
    'Level-8':  TaRateInfo(taPerKm: 2.5, daPerDay: 250),
    'Level-9':  TaRateInfo(taPerKm: 3.0, daPerDay: 350),
    'Level-10': TaRateInfo(taPerKm: 3.0, daPerDay: 350),
    'Level-11': TaRateInfo(taPerKm: 3.0, daPerDay: 350),
    'Level-12': TaRateInfo(taPerKm: 4.0, daPerDay: 500),
    'Level-13': TaRateInfo(taPerKm: 4.0, daPerDay: 500),
    'Level-14': TaRateInfo(taPerKm: 4.0, daPerDay: 500),
  };

  static TaRateInfo ratesForGradeLevel(String gradeLevel) {
    // Try exact match first
    if (_levelRates.containsKey(gradeLevel)) {
      return _levelRates[gradeLevel]!;
    }
    // Fallback: parse level number
    final clean = gradeLevel.replaceAll(RegExp(r'[^0-9]'), '').trim();
    final level = int.tryParse(clean) ?? 6;
    if (level <= 2) return _levelRates['Level-1']!;
    if (level <= 5) return _levelRates['Level-3']!;
    if (level <= 8) return _levelRates['Level-6']!;
    if (level <= 11) return _levelRates['Level-9']!;
    return _levelRates['Level-12']!;
  }

  static double getTARate(String gradeLevel) =>
      ratesForGradeLevel(gradeLevel).taPerKm;

  static double getDARate(String gradeLevel) =>
      ratesForGradeLevel(gradeLevel).daPerDay;

  // Mode-based mileage rates
  static const Map<String, double> _mileageRates = {
    'Own Vehicle (Car)': 0.65,
    'Own Vehicle (Motorcycle)': 0.35,
    'Auto Rickshaw': 0.20,
    'Bus': 0.10,
    'Train': 0.00,
    'Taxi': 0.30,
    'Other': 0.20,
  };

  static double getMileageRate(String mode) {
    for (final entry in _mileageRates.entries) {
      if (mode.toLowerCase().contains(
          entry.key.toLowerCase().split(' ')[0])) {
        return entry.value;
      }
    }
    return _mileageRates[mode] ?? 0.20;
  }
}

// Alias for backward compatibility
typedef TaRatesConfig = TaRates;
