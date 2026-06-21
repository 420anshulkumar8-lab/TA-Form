// lib/models/trip_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Plain Dart models for TA data. Stored as JSON inside Hive ta_sessions.
//
// The form is a single flat list of rows the user builds manually with the
// (+) / delete-row controls — there is no automatic "trip" detection.
// ─────────────────────────────────────────────────────────────────────────────

enum RowType { travel, stay }

/// How the "Vehicle / Train No." cell of a travel row was filled.
enum VehicleEntryType { train, other }

class TripRow {
  final RowType rowType;

  // ── Travel row fields ──────────────────────────────────────────────────
  final String date; // DD/MM/YYYY — must fall within the session's month
  final VehicleEntryType vehicleEntryType;
  final String vehicleNumber; // 5-digit train no., or free text if "other"
  final String departureTime; // HH:MM (24h)
  final String arrivalTime; // HH:MM (24h)
  final String fromLocation;
  final String toLocation;
  final double distanceKm; // optional
  final String dayNight; // "Day" | "Night" | "" (optional)
  final String purpose; // free text
  final double rateAmount; // auto-calculated from departure/arrival + level

  // ── Stay row fields ───────────────────────────────────────────────────
  final String dateFrom; // DD/MM/YYYY
  final String dateTo; // DD/MM/YYYY
  final String location;
  final int nights;
  final double daAmount;

  const TripRow({
    required this.rowType,
    this.date = '',
    this.vehicleEntryType = VehicleEntryType.train,
    this.vehicleNumber = '',
    this.departureTime = '',
    this.arrivalTime = '',
    this.fromLocation = '',
    this.toLocation = '',
    this.distanceKm = 0,
    this.dayNight = '',
    this.purpose = '',
    this.rateAmount = 0,
    this.dateFrom = '',
    this.dateTo = '',
    this.location = '',
    this.nights = 0,
    this.daAmount = 0,
  });

  TripRow copyWith({
    RowType? rowType,
    String? date,
    VehicleEntryType? vehicleEntryType,
    String? vehicleNumber,
    String? departureTime,
    String? arrivalTime,
    String? fromLocation,
    String? toLocation,
    double? distanceKm,
    String? dayNight,
    String? purpose,
    double? rateAmount,
    String? dateFrom,
    String? dateTo,
    String? location,
    int? nights,
    double? daAmount,
  }) {
    return TripRow(
      rowType: rowType ?? this.rowType,
      date: date ?? this.date,
      vehicleEntryType: vehicleEntryType ?? this.vehicleEntryType,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      departureTime: departureTime ?? this.departureTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      distanceKm: distanceKm ?? this.distanceKm,
      dayNight: dayNight ?? this.dayNight,
      purpose: purpose ?? this.purpose,
      rateAmount: rateAmount ?? this.rateAmount,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      location: location ?? this.location,
      nights: nights ?? this.nights,
      daAmount: daAmount ?? this.daAmount,
    );
  }

  factory TripRow.fromJson(Map<String, dynamic> json) {
    final type = json['row_type'] == 'stay' ? RowType.stay : RowType.travel;
    return TripRow(
      rowType: type,
      date: json['date'] ?? '',
      vehicleEntryType: json['vehicle_entry_type'] == 'other'
          ? VehicleEntryType.other
          : VehicleEntryType.train,
      vehicleNumber: json['vehicle_number'] ?? '',
      departureTime: json['departure_time'] ?? '',
      arrivalTime: json['arrival_time'] ?? '',
      fromLocation: json['from_location'] ?? '',
      toLocation: json['to_location'] ?? '',
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      dayNight: json['day_night'] ?? '',
      purpose: json['purpose'] ?? '',
      rateAmount: (json['rate_amount'] ?? 0).toDouble(),
      dateFrom: json['date_from'] ?? '',
      dateTo: json['date_to'] ?? '',
      location: json['location'] ?? '',
      nights: json['nights'] ?? 0,
      daAmount: (json['da_amount'] ?? 0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    if (rowType == RowType.stay) {
      return {
        'row_type': 'stay',
        'date_from': dateFrom,
        'date_to': dateTo,
        'location': location,
        'nights': nights,
        'da_amount': daAmount,
      };
    }
    return {
      'row_type': 'travel',
      'date': date,
      'vehicle_entry_type':
          vehicleEntryType == VehicleEntryType.other ? 'other' : 'train',
      'vehicle_number': vehicleNumber,
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'from_location': fromLocation,
      'to_location': toLocation,
      'distance_km': distanceKm,
      'day_night': dayNight,
      'purpose': purpose,
      'rate_amount': rateAmount,
    };
  }
}

class TaFormData {
  final String formRef;
  final String employeeId;
  final String month;
  final String year;
  final List<TripRow> rows;
  final double grandTravelTotal;
  final double grandDaTotal;
  final double grandTotal;
  final String status; // "draft" | "submitted"

  const TaFormData({
    this.formRef = 'GA-31',
    required this.employeeId,
    required this.month,
    required this.year,
    required this.rows,
    this.grandTravelTotal = 0,
    this.grandDaTotal = 0,
    this.grandTotal = 0,
    this.status = 'draft',
  });

  factory TaFormData.fromJson(Map<String, dynamic> json) => TaFormData(
        formRef: json['form_ref'] ?? 'GA-31',
        employeeId: json['employee_id'] ?? '',
        month: json['month'] ?? '',
        year: json['year'] ?? '',
        rows: (json['rows'] as List<dynamic>? ?? [])
            .map((r) => TripRow.fromJson(r as Map<String, dynamic>))
            .toList(),
        grandTravelTotal: (json['grand_travel_total'] ?? 0).toDouble(),
        grandDaTotal: (json['grand_da_total'] ?? 0).toDouble(),
        grandTotal: (json['grand_total'] ?? 0).toDouble(),
        status: json['status'] ?? 'draft',
      );

  Map<String, dynamic> toJson() => {
        'form_ref': formRef,
        'employee_id': employeeId,
        'month': month,
        'year': year,
        'rows': rows.map((r) => r.toJson()).toList(),
        'grand_travel_total': grandTravelTotal,
        'grand_da_total': grandDaTotal,
        'grand_total': grandTotal,
        'status': status,
      };
}
