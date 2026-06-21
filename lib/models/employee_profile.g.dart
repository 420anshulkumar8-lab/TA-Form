// GENERATED CODE - DO NOT MODIFY BY HAND
// Hand-authored to match the exact output of hive_generator for this
// class. If you change employee_profile.dart fields, regenerate via:
//   flutter pub run build_runner build --delete-conflicting-outputs

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
      name: fields[0] as String,
      designation: fields[1] as String,
      level: fields[2] as int,
      basicPay: fields[3] as double,
      dateOfAppointment: fields[4] as String,
      headquarter: fields[5] as String,
      division: fields[6] as String,
      employeeNo: fields[7] as String,
      railway: fields[8] as String,
      department: fields[9] as String,
      photoPath: fields[10] == null ? '' : fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, EmployeeProfile obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.designation)
      ..writeByte(2)
      ..write(obj.level)
      ..writeByte(3)
      ..write(obj.basicPay)
      ..writeByte(4)
      ..write(obj.dateOfAppointment)
      ..writeByte(5)
      ..write(obj.headquarter)
      ..writeByte(6)
      ..write(obj.division)
      ..writeByte(7)
      ..write(obj.employeeNo)
      ..writeByte(8)
      ..write(obj.railway)
      ..writeByte(9)
      ..write(obj.department)
      ..writeByte(10)
      ..write(obj.photoPath);
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
