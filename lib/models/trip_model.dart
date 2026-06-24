// lib/models/trip_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Amount logic: one amount per unique date across the ENTIRE month, regardless
// of how many trips or rows fall on that date. The user picks the amount from
// a dropdown (4 options based on their Level). Amount is stored in
// TaFormData.dateAmounts as a Map<String date, double amount> so that every
// row sharing the same date automatically shows the same merged amount cell.
// ─────────────────────────────────────────────────────────────────────────────

enum VehicleEntryType { train, other, halt }

/// One travel leg — a single row in the printed table.
class TripRow {
  final String date; // DD/MM/YYYY
  final bool dateIsSuggested;
  final VehicleEntryType vehicleEntryType;
  final String vehicleNumber;
  final String departureTime; // HH:MM (24h)
  final String arrivalTime; // HH:MM (24h)
  final String fromLocation;
  final bool fromIsSuggested;
  final String toLocation;
  final bool toIsSuggested;
  final double distanceKm; // optional
  final String dayNight; // "Day" | "Night" | ""

  const TripRow({
    this.date = '',
    this.dateIsSuggested = false,
    this.vehicleEntryType = VehicleEntryType.train,
    this.vehicleNumber = '',
    this.departureTime = '',
    this.arrivalTime = '',
    this.fromLocation = '',
    this.fromIsSuggested = false,
    this.toLocation = '',
    this.toIsSuggested = false,
    this.distanceKm = 0,
    this.dayNight = '',
  });

  TripRow copyWith({
    String? date,
    bool? dateIsSuggested,
    VehicleEntryType? vehicleEntryType,
    String? vehicleNumber,
    String? departureTime,
    String? arrivalTime,
    String? fromLocation,
    bool? fromIsSuggested,
    String? toLocation,
    bool? toIsSuggested,
    double? distanceKm,
    String? dayNight,
  }) {
    return TripRow(
      date: date ?? this.date,
      dateIsSuggested: dateIsSuggested ?? this.dateIsSuggested,
      vehicleEntryType: vehicleEntryType ?? this.vehicleEntryType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      fromLocation: fromLocation ?? this.fromLocation,
      fromIsSuggested: fromIsSuggested ?? this.fromIsSuggested,
      toLocation: toLocation ?? this.toLocation,
      toIsSuggested: toIsSuggested ?? this.toIsSuggested,
      distanceKm: distanceKm ?? this.distanceKm,
      dayNight: dayNight ?? this.dayNight,
    );
  }

  factory TripRow.fromJson(Map<String, dynamic> json) => TripRow(
        date: json['date'] ?? '',
        dateIsSuggested: json['date_is_suggested'] ?? false,
        vehicleEntryType: json['vehicle_entry_type'] == 'halt'
            ? VehicleEntryType.halt
            : json['vehicle_entry_type'] == 'other'
                ? VehicleEntryType.other
                : VehicleEntryType.train,
        vehicleNumber: json['vehicle_number'] ?? '',
        departureTime: json['departure_time'] ?? '',
        arrivalTime: json['arrival_time'] ?? '',
        fromLocation: json['from_location'] ?? '',
        fromIsSuggested: json['from_is_suggested'] ?? false,
        toLocation: json['to_location'] ?? '',
        toIsSuggested: json['to_is_suggested'] ?? false,
        distanceKm: (json['distance_km'] ?? 0).toDouble(),
        dayNight: json['day_night'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'date_is_suggested': dateIsSuggested,
        'vehicle_entry_type': vehicleEntryType == VehicleEntryType.halt
            ? 'halt'
            : vehicleEntryType == VehicleEntryType.other
                ? 'other'
                : 'train',
        'vehicle_number': vehicleNumber,
        'departure_time': departureTime,
        'arrival_time': arrivalTime,
        'from_location': fromLocation,
        'from_is_suggested': fromIsSuggested,
        'to_location': toLocation,
        'to_is_suggested': toIsSuggested,
        'distance_km': distanceKm,
        'day_night': dayNight,
      };
}

/// One headquarters-out-and-back journey: shared Purpose + its legs.
class TripGroup {
  final String purpose;
  final List<TripRow> legs;

  const TripGroup({
    this.purpose = '',
    required this.legs,
  });

  TripGroup copyWith({String? purpose, List<TripRow>? legs}) => TripGroup(
        purpose: purpose ?? this.purpose,
        legs: legs ?? this.legs,
      );

  factory TripGroup.fromJson(Map<String, dynamic> json) => TripGroup(
        purpose: json['purpose'] ?? '',
        legs: (json['legs'] as List<dynamic>? ?? [])
            .map((r) => TripRow.fromJson(r as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'purpose': purpose,
        'legs': legs.map((r) => r.toJson()).toList(),
      };

  static TripGroup blank() => const TripGroup(legs: [TripRow(), TripRow()]);
}

class TaFormData {
  final String formRef;
  final String employeeId;
  final String month;
  final String year;
  final List<TripGroup> trips;

  /// Date → amount map. Key = "DD/MM/YYYY", value = user-selected amount.
  /// One entry per unique date across all trips. Used to render the merged
  /// Amount cell and to compute the grand total.
  final Map<String, double> dateAmounts;

  final double grandTotal;
  final String status;

  const TaFormData({
    this.formRef = 'GA-31',
    required this.employeeId,
    required this.month,
    required this.year,
    required this.trips,
    this.dateAmounts = const {},
    this.grandTotal = 0,
    this.status = 'draft',
  });

  factory TaFormData.fromJson(Map<String, dynamic> json) => TaFormData(
        formRef: json['form_ref'] ?? 'GA-31',
        employeeId: json['employee_id'] ?? '',
        month: json['month'] ?? '',
        year: json['year'] ?? '',
        trips: (json['trips'] as List<dynamic>? ?? [])
            .map((t) => TripGroup.fromJson(t as Map<String, dynamic>))
            .toList(),
        dateAmounts: (json['date_amounts'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num).toDouble())),
        grandTotal: (json['grand_total'] ?? 0).toDouble(),
        status: json['status'] ?? 'draft',
      );

  Map<String, dynamic> toJson() => {
        'form_ref': formRef,
        'employee_id': employeeId,
        'month': month,
        'year': year,
        'trips': trips.map((t) => t.toJson()).toList(),
        'date_amounts': dateAmounts,
        'grand_total': grandTotal,
        'status': status,
      };
}
