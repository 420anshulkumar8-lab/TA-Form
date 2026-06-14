// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'employee_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class EmployeeProfileAdapter extends TypeAdapter<EmployeeProfile> {
  @override
  final int typeId = 0;

  @override
  EmployeeProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EmployeeProfile(
      name: fields[0] as String? ?? '',
      designation: fields[1] as String? ?? '',
      gradeLevel: fields[2] as String? ?? '',
      basicPay: (fields[3] as num?)?.toDouble() ?? 0,
      dateOfAppointment: fields[4] as String? ?? '',
      headquarters: fields[5] as String? ?? '',
      division: fields[6] as String? ?? '',
      mobile: fields[7] as String? ?? '',
      employeeId: fields[8] as String? ?? '',
      hqStationCode: fields[9] as String? ?? '',
    );
  }

  @override
  void write(BinaryWriter writer, EmployeeProfile obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.designation)
      ..writeByte(2)
      ..write(obj.gradeLevel)
      ..writeByte(3)
      ..write(obj.basicPay)
      ..writeByte(4)
      ..write(obj.dateOfAppointment)
      ..writeByte(5)
      ..write(obj.headquarters)
      ..writeByte(6)
      ..write(obj.division)
      ..writeByte(7)
      ..write(obj.mobile)
      ..writeByte(8)
      ..write(obj.employeeId)
      ..writeByte(9)
      ..write(obj.hqStationCode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EmployeeProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
