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
  int level; // 1-9

  @HiveField(3)
  double basicPay;

  @HiveField(4)
  String dateOfAppointment; // DD/MM/YYYY

  @HiveField(5)
  String headquarter;

  @HiveField(6)
  String division;

  @HiveField(7)
  String employeeNo;

  @HiveField(8)
  String railway; // dropdown value, or the custom text if "Other"

  @HiveField(9)
  String department; // dropdown value, or the custom text if "Other"

  @HiveField(10)
  String photoPath; // local file path of the optional profile picture

  EmployeeProfile({
    this.name = '',
    this.designation = '',
    this.level = 1,
    this.basicPay = 0,
    this.dateOfAppointment = '',
    this.headquarter = '',
    this.division = '',
    this.employeeNo = '',
    this.railway = '',
    this.department = '',
    this.photoPath = '',
  });

  bool get isComplete =>
      name.isNotEmpty &&
      designation.isNotEmpty &&
      employeeNo.isNotEmpty &&
      railway.isNotEmpty &&
      division.isNotEmpty &&
      headquarter.isNotEmpty &&
      department.isNotEmpty &&
      basicPay > 0;

  Map<String, dynamic> toJson() => {
        'name': name,
        'designation': designation,
        'level': level,
        'basic_pay': basicPay,
        'date_of_appointment': dateOfAppointment,
        'headquarter': headquarter,
        'division': division,
        'employee_no': employeeNo,
        'railway': railway,
        'department': department,
        'photo_path': photoPath,
      };

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) =>
      EmployeeProfile(
        name: json['name'] ?? '',
        designation: json['designation'] ?? '',
        level: (json['level'] ?? 1) is int
            ? json['level'] ?? 1
            : int.tryParse('${json['level']}') ?? 1,
        basicPay: (json['basic_pay'] ?? 0).toDouble(),
        dateOfAppointment: json['date_of_appointment'] ?? '',
        headquarter: json['headquarter'] ?? '',
        division: json['division'] ?? '',
        employeeNo: json['employee_no'] ?? '',
        railway: json['railway'] ?? '',
        department: json['department'] ?? '',
        photoPath: json['photo_path'] ?? '',
      );
}
