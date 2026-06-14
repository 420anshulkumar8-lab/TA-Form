// lib/models/employee_profile.dart
import 'package:hive/hive.dart';

part 'employee_profile.g.dart';

@HiveType(typeId: 0)
class EmployeeProfile extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String designation;

  @HiveField(2)
  String gradeLevel; // e.g. "Level-6"

  @HiveField(3)
  double basicPay;

  @HiveField(4)
  String dateOfAppointment; // DD/MM/YYYY

  @HiveField(5)
  String headquarters;

  @HiveField(6)
  String division;

  @HiveField(7)
  String mobile;

  @HiveField(8)
  String employeeId;

  @HiveField(9)
  String hqStationCode; // e.g. GZB, NDLS — for AI context

  EmployeeProfile({
    this.name = '',
    this.designation = '',
    this.gradeLevel = '',
    this.basicPay = 0,
    this.dateOfAppointment = '',
    this.headquarters = '',
    this.division = '',
    this.mobile = '',
    this.employeeId = '',
    this.hqStationCode = '',
  });

  bool get isComplete =>
      name.isNotEmpty &&
      designation.isNotEmpty &&
      gradeLevel.isNotEmpty &&
      basicPay > 0 &&
      headquarters.isNotEmpty &&
      division.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'name': name,
        'employee_id': employeeId,
        'designation': designation,
        'department': division,
        'headquarters': headquarters,
        'hq_station_code': hqStationCode,
        'grade_pay_level': gradeLevel,
        'basic_pay': basicPay,
        'date_of_appointment': dateOfAppointment,
      };

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) =>
      EmployeeProfile(
        name: json['name'] ?? '',
        designation: json['designation'] ?? '',
        gradeLevel: json['grade_pay_level'] ?? '',
        basicPay: (json['basic_pay'] ?? 0).toDouble(),
        headquarters: json['headquarters'] ?? '',
        hqStationCode: json['hq_station_code'] ?? '',
        division: json['department'] ?? '',
        employeeId: json['employee_id'] ?? '',
        dateOfAppointment: json['date_of_appointment'] ?? '',
      );
}
