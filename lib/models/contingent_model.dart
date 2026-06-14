// lib/models/contingent_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Plain Dart models for Contingent Bill data. Stored as JSON in Hive.
// ─────────────────────────────────────────────────────────────────────────────

class ContingentEntry {
  final int entryId;
  final String date; // DD/MM/YYYY
  final String by; // Auto/Taxi/Rickshaw/Bus/Other
  final String fromLocation;
  final String toLocation;
  final double distanceKm;
  final double amount;
  final bool verifiedAgainstTa;

  const ContingentEntry({
    required this.entryId,
    required this.date,
    required this.by,
    required this.fromLocation,
    required this.toLocation,
    this.distanceKm = 0,
    required this.amount,
    this.verifiedAgainstTa = true,
  });

  factory ContingentEntry.fromJson(Map<String, dynamic> json) =>
      ContingentEntry(
        entryId: json['entry_id'] ?? 0,
        date: json['date'] ?? '',
        by: json['by'] ?? '',
        fromLocation: json['from_location'] ?? '',
        toLocation: json['to_location'] ?? '',
        distanceKm: (json['distance_km'] ?? 0).toDouble(),
        amount: (json['amount'] ?? 0).toDouble(),
        verifiedAgainstTa: json['verified_against_ta'] ?? true,
      );

  Map<String, dynamic> toJson() => {
        'entry_id': entryId,
        'date': date,
        'by': by,
        'from_location': fromLocation,
        'to_location': toLocation,
        'distance_km': distanceKm,
        'amount': amount,
        'verified_against_ta': verifiedAgainstTa,
      };
}

class ContingentFormData {
  final String formRef;
  final String employeeId;
  final String month;
  final String year;
  final List<ContingentEntry> entries;
  final double totalAmount;
  final String status; // "pending" | "submitted"

  const ContingentFormData({
    this.formRef = 'Contingent Bill',
    required this.employeeId,
    required this.month,
    required this.year,
    required this.entries,
    this.totalAmount = 0,
    this.status = 'pending',
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
        status: json['status'] ?? 'pending',
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
