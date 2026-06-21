// lib/models/trip_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Plain Dart models for TA data. Stored as JSON inside Hive ta_sessions.
//
// A month's TA is a list of TripGroups ("Trip 1", "Trip 2", ...). Each trip
// represents one headquarters-out-and-back journey and contains one or more
// TripRow "legs" (e.g. GZB→NDLS, NDLS→GZB). All legs of a trip share a single
// Purpose, entered once and shown merged across the trip's rows.
// ─────────────────────────────────────────────────────────────────────────────

/// How the "Vehicle / Train No." cell of a leg was filled.
enum VehicleEntryType { train, other }

/// One travel leg (a single row in the printed table) belonging to a Trip.
class TripRow {
  final String date; // DD/MM/YYYY — must fall within the session's month
  final bool dateIsSuggested; // true until the user explicitly confirms it
  final VehicleEntryType vehicleEntryType;
  final String vehicleNumber; // 5-digit train no., or free text if "other"
  final String departureTime; // HH:MM (24h)
  final String arrivalTime; // HH:MM (24h)
  final String fromLocation;
  final bool fromIsSuggested; // true until the user explicitly confirms it
  final String toLocation;
  final bool toIsSuggested; // true until the user explicitly confirms it
  final double distanceKm; // optional
  final String dayNight; // "Day" | "Night" | "" (optional)
  final double rateAmount; // auto-calculated from departure/arrival + level

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
    this.rateAmount = 0,
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
    double? rateAmount,
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
      rateAmount: rateAmount ?? this.rateAmount,
    );
  }

  factory TripRow.fromJson(Map<String, dynamic> json) {
    return TripRow(
      date: json['date'] ?? '',
      dateIsSuggested: json['date_is_suggested'] ?? false,
      vehicleEntryType: json['vehicle_entry_type'] == 'other'
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
      rateAmount: (json['rate_amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'date_is_suggested': dateIsSuggested,
        'vehicle_entry_type':
            vehicleEntryType == VehicleEntryType.other ? 'other' : 'train',
        'vehicle_number': vehicleNumber,
        'departure_time': departureTime,
        'arrival_time': arrivalTime,
        'from_location': fromLocation,
        'from_is_suggested': fromIsSuggested,
        'to_location': toLocation,
        'to_is_suggested': toIsSuggested,
        'distance_km': distanceKm,
        'day_night': dayNight,
        'rate_amount': rateAmount,
      };
}

/// A single headquarters-out-and-back trip: one shared Purpose + its legs.
class TripGroup {
  final String purpose; // shared by every leg in this trip
  final List<TripRow> legs;

  const TripGroup({
    this.purpose = '',
    required this.legs,
  });

  TripGroup copyWith({String? purpose, List<TripRow>? legs}) {
    return TripGroup(
      purpose: purpose ?? this.purpose,
      legs: legs ?? this.legs,
    );
  }

  double get tripTotal => legs.fold(0.0, (sum, r) => sum + r.rateAmount);

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

  /// A fresh trip group with 2 blank legs (the default starting state).
  static TripGroup blank() => const TripGroup(
        legs: [TripRow(), TripRow()],
      );
}

class TaFormData {
  final String formRef;
  final String employeeId;
  final String month;
  final String year;
  final List<TripGroup> trips;
  final double grandTotal;
  final String status; // "draft" | "submitted"

  const TaFormData({
    this.formRef = 'GA-31',
    required this.employeeId,
    required this.month,
    required this.year,
    required this.trips,
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
        grandTotal: (json['grand_total'] ?? 0).toDouble(),
        status: json['status'] ?? 'draft',
      );

  Map<String, dynamic> toJson() => {
        'form_ref': formRef,
        'employee_id': employeeId,
        'month': month,
        'year': year,
        'trips': trips.map((t) => t.toJson()).toList(),
        'grand_total': grandTotal,
        'status': status,
      };
}
