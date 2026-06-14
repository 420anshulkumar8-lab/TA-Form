// lib/models/trip_model.dart
// ─────────────────────────────────────────────────────────────────────────────
// Plain Dart models for TA trip data. Stored as JSON inside Hive ta_sessions.
// ─────────────────────────────────────────────────────────────────────────────

enum RowType { travel, stay }

class TripRow {
  final RowType rowType;

  // ── Travel row fields ──────────────────────────────────────────────────────
  final String date; // DD/MM/YYYY
  final String vehicleNumber;
  final String mode;
  final String departureTime; // HH:MM
  final String arrivalTime; // HH:MM
  final String fromLocation;
  final String toLocation;
  final double distanceKm;
  final String dayNight; // "Day" | "Night"
  final bool isLastRowOfTrip;
  final String purpose; // "↑" for non-last rows
  final double rateAmount;

  // ── Stay row fields ────────────────────────────────────────────────────────
  final String dateFrom; // DD/MM/YYYY
  final String dateTo; // DD/MM/YYYY
  final String location;
  final int nights;
  final double daAmount;

  const TripRow({
    required this.rowType,
    this.date = '',
    this.vehicleNumber = '',
    this.mode = '',
    this.departureTime = '',
    this.arrivalTime = '',
    this.fromLocation = '',
    this.toLocation = '',
    this.distanceKm = 0,
    this.dayNight = 'Day',
    this.isLastRowOfTrip = false,
    this.purpose = '',
    this.rateAmount = 0,
    this.dateFrom = '',
    this.dateTo = '',
    this.location = '',
    this.nights = 0,
    this.daAmount = 0,
  });

  factory TripRow.fromJson(Map<String, dynamic> json) {
    final type =
        json['row_type'] == 'stay' ? RowType.stay : RowType.travel;
    return TripRow(
      rowType: type,
      date: json['date'] ?? '',
      vehicleNumber: json['vehicle_number'] ?? '',
      mode: json['mode'] ?? '',
      departureTime: json['departure_time'] ?? '',
      arrivalTime: json['arrival_time'] ?? '',
      fromLocation: json['from_location'] ?? '',
      toLocation: json['to_location'] ?? '',
      distanceKm: (json['distance_km'] ?? 0).toDouble(),
      dayNight: json['day_night'] ?? 'Day',
      isLastRowOfTrip: json['is_last_row_of_trip'] ?? false,
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
      'vehicle_number': vehicleNumber,
      'mode': mode,
      'departure_time': departureTime,
      'arrival_time': arrivalTime,
      'from_location': fromLocation,
      'to_location': toLocation,
      'distance_km': distanceKm,
      'day_night': dayNight,
      'is_last_row_of_trip': isLastRowOfTrip,
      'purpose': purpose,
      'rate_amount': rateAmount,
    };
  }
}

class Trip {
  final int tripId;
  final String purposeFormal;
  final List<TripRow> rows;
  final double tripTravelTotal;
  final double tripDaTotal;
  final double tripTotal;

  const Trip({
    required this.tripId,
    required this.purposeFormal,
    required this.rows,
    this.tripTravelTotal = 0,
    this.tripDaTotal = 0,
    this.tripTotal = 0,
  });

  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        tripId: json['trip_id'] ?? 0,
        purposeFormal: json['purpose_formal'] ?? '',
        rows: (json['rows'] as List<dynamic>? ?? [])
            .map((r) => TripRow.fromJson(r as Map<String, dynamic>))
            .toList(),
        tripTravelTotal: (json['trip_travel_total'] ?? 0).toDouble(),
        tripDaTotal: (json['trip_da_total'] ?? 0).toDouble(),
        tripTotal: (json['trip_total'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'trip_id': tripId,
        'purpose_formal': purposeFormal,
        'rows': rows.map((r) => r.toJson()).toList(),
        'trip_travel_total': tripTravelTotal,
        'trip_da_total': tripDaTotal,
        'trip_total': tripTotal,
      };
}

class TaFormData {
  final String formRef;
  final String employeeId;
  final String month;
  final String year;
  final List<Trip> trips;
  final double grandTravelTotal;
  final double grandDaTotal;
  final double grandTotal;
  final String status; // "pending" | "submitted"

  const TaFormData({
    this.formRef = 'GA-31',
    required this.employeeId,
    required this.month,
    required this.year,
    required this.trips,
    this.grandTravelTotal = 0,
    this.grandDaTotal = 0,
    this.grandTotal = 0,
    this.status = 'pending',
  });

  int get totalRows =>
      trips.fold(0, (sum, t) => sum + t.rows.length);

  factory TaFormData.fromJson(Map<String, dynamic> json) => TaFormData(
        formRef: json['form_ref'] ?? 'GA-31',
        employeeId: json['employee_id'] ?? '',
        month: json['month'] ?? '',
        year: json['year'] ?? '',
        trips: (json['trips'] as List<dynamic>? ?? [])
            .map((t) => Trip.fromJson(t as Map<String, dynamic>))
            .toList(),
        grandTravelTotal: (json['grand_travel_total'] ?? 0).toDouble(),
        grandDaTotal: (json['grand_da_total'] ?? 0).toDouble(),
        grandTotal: (json['grand_total'] ?? 0).toDouble(),
        status: json['status'] ?? 'pending',
      );

  Map<String, dynamic> toJson() => {
        'form_ref': formRef,
        'employee_id': employeeId,
        'month': month,
        'year': year,
        'trips': trips.map((t) => t.toJson()).toList(),
        'grand_travel_total': grandTravelTotal,
        'grand_da_total': grandDaTotal,
        'grand_total': grandTotal,
        'status': status,
      };
}
