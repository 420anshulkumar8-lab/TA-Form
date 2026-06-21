// lib/models/contingent_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Plain Dart models for Contingent Bill data. Stored as JSON in Hive.
// Built manually by the user with the same (+) / delete-row controls as the
// TA table.
// ─────────────────────────────────────────────────────────────────────────────

class ContingentEntry {
  final String date; // DD/MM/YYYY — must fall within the session's month
  final String fromLocation;
  final String toLocation;
  final double distanceKm; // optional
  final double amount;

  const ContingentEntry({
    this.date = '',
    this.fromLocation = '',
    this.toLocation = '',
    this.distanceKm = 0,
    this.amount = 0,
  });

  ContingentEntry copyWith({
    String? date,
    String? fromLocation,
    String? toLocation,
    double? distanceKm,
    double? amount,
  }) {
    return ContingentEntry(
      date: date ?? this.date,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      distanceKm: distanceKm ?? this.distanceKm,
      amount: amount ?? this.amount,
    );
  }

  factory ContingentEntry.fromJson(Map<String, dynamic> json) =>
      ContingentEntry(
        date: json['date'] ?? '',
        fromLocation: json['from_location'] ?? '',
        toLocation: json['to_location'] ?? '',
        distanceKm: (json['distance_km'] ?? 0).toDouble(),
        amount: (json['amount'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'from_location': fromLocation,
        'to_location': toLocation,
        'distance_km': distanceKm,
        'amount': amount,
      };
}

class ContingentFormData {
  final String formRef;
  final String employeeId;
  final String month;
  final String year;
  final List<ContingentEntry> entries;
  final double totalAmount;
  final String status; // "draft" | "submitted"

  const ContingentFormData({
    this.formRef = 'Contingent Bill',
    required this.employeeId,
    required this.month,
    required this.year,
    required this.entries,
    this.totalAmount = 0,
    this.status = 'draft',
  });

  factory ContingentFormData.fromJson(Map<String, dynamic> json) =>
      ContingentFormData(
        formRef: json['form_ref'] ?? 'Contingent Bill',
        employeeId: json['employee_id'] ?? '',
        month: json['month'] ?? '',
        year: json['year'] ?? '',
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => ContingentEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalAmount: (json['total_amount'] ?? 0).toDouble(),
        status: json['status'] ?? 'draft',
      );

  Map<String, dynamic> toJson() => {
        'form_ref': formRef,
        'employee_id': employeeId,
        'month': month,
        'year': year,
        'entries': entries.map((e) => e.toJson()).toList(),
        'total_amount': totalAmount,
        'status': status,
      };
}
