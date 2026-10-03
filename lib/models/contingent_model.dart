// lib/models/contingent_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Contingent Bill data (stored as JSON in Hive). Same shape as the TA table:
//   ContingentGroup  = "Contingent N": ONE merged Purpose + its rows
//   ContingentRow    = Date | From | To | Km | Amount (each row has its OWN
//                      amount — no date-wise merging, no bracket)
// Old saved data (flat 'entries' list, one purpose per entry) is converted on
// load: every old entry becomes its own group with a single row.
// ─────────────────────────────────────────────────────────────────────────────

class ContingentRow {
  final String date; // DD/MM/YYYY — must fall within the session's month
  final String fromLocation;
  final String toLocation;
  final double distanceKm; // optional
  final double amount;

  const ContingentRow({
    this.date = '',
    this.fromLocation = '',
    this.toLocation = '',
    this.distanceKm = 0,
    this.amount = 0,
  });

  ContingentRow copyWith({
    String? date,
    String? fromLocation,
    String? toLocation,
    double? distanceKm,
    double? amount,
  }) {
    return ContingentRow(
      date: date ?? this.date,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      distanceKm: distanceKm ?? this.distanceKm,
      amount: amount ?? this.amount,
    );
  }

  factory ContingentRow.fromJson(Map<String, dynamic> json) => ContingentRow(
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

/// One "Contingent N" block: a shared Purpose + its rows.
class ContingentGroup {
  final String purpose;
  final List<ContingentRow> rows;

  const ContingentGroup({this.purpose = '', required this.rows});

  ContingentGroup copyWith({String? purpose, List<ContingentRow>? rows}) =>
      ContingentGroup(
        purpose: purpose ?? this.purpose,
        rows: rows ?? this.rows,
      );

  double get total => rows.fold(0.0, (a, r) => a + r.amount);

  factory ContingentGroup.fromJson(Map<String, dynamic> json) =>
      ContingentGroup(
        purpose: json['purpose'] ?? '',
        rows: (json['rows'] as List<dynamic>? ?? [])
            .map((r) => ContingentRow.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'rows': rows.map((r) => r.toJson()).toList(),
      };

  static ContingentGroup blank() =>
      const ContingentGroup(rows: [ContingentRow()]);
}

class ContingentFormData {
  final String formRef;
  final String employeeId;
  final String month;
  final String year;
  final List<ContingentGroup> groups;
  final double totalAmount;
  final String status; // "draft" | "submitted"

  const ContingentFormData({
    this.formRef = 'Contingent Bill',
    required this.employeeId,
    required this.month,
    required this.year,
    required this.groups,
    this.totalAmount = 0,
    this.status = 'draft',
  });

  factory ContingentFormData.fromJson(Map<String, dynamic> json) {
    List<ContingentGroup> groups;
    if (json['groups'] != null) {
      groups = (json['groups'] as List<dynamic>)
          .map((g) => ContingentGroup.fromJson(g as Map<String, dynamic>))
          .toList();
    } else {
      // Legacy flat entries → one group (one row) per old entry.
      groups = (json['entries'] as List<dynamic>? ?? []).map((e) {
        final m = e as Map<String, dynamic>;
        return ContingentGroup(
          purpose: m['purpose'] ?? '',
          rows: [ContingentRow.fromJson(m)],
        );
      }).toList();
    }
    return ContingentFormData(
      formRef: json['form_ref'] ?? 'Contingent Bill',
      employeeId: json['employee_id'] ?? '',
      month: json['month'] ?? '',
      year: json['year'] ?? '',
      groups: groups,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      status: json['status'] ?? 'draft',
    );
  }

  Map<String, dynamic> toJson() => {
        'form_ref': formRef,
        'employee_id': employeeId,
        'month': month,
        'year': year,
        'groups': groups.map((g) => g.toJson()).toList(),
        'total_amount': totalAmount,
        'status': status,
      };
}
