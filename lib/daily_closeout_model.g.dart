// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_closeout_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DailyCloseoutAdapter extends TypeAdapter<DailyCloseout> {
  @override
  final int typeId = 9;

  @override
  DailyCloseout read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DailyCloseout(
      id: fields[0] as String,
      date: fields[1] as DateTime,
      intent: fields[2] as String,
      completedTasks: fields[3] as int,
      focusMinutes: fields[4] as int,
      closedAt: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, DailyCloseout obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.date)
      ..writeByte(2)
      ..write(obj.intent)
      ..writeByte(3)
      ..write(obj.completedTasks)
      ..writeByte(4)
      ..write(obj.focusMinutes)
      ..writeByte(5)
      ..write(obj.closedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyCloseoutAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
