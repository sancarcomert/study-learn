// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_session_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FocusSessionAdapter extends TypeAdapter<FocusSession> {
  @override
  final int typeId = 8;

  @override
  FocusSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FocusSession(
      id: fields[0] as String,
      endedAt: fields[1] as DateTime,
      minutes: fields[2] as int,
      mode: fields[3] as String,
      subjectId: fields[4] as String?,
      topicId: fields[5] as String?,
      note: fields[6] as String?,
      feeling: fields[7] as int?,
      taskId: fields[8] as String?,
      runId: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FocusSession obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.endedAt)
      ..writeByte(2)
      ..write(obj.minutes)
      ..writeByte(3)
      ..write(obj.mode)
      ..writeByte(4)
      ..write(obj.subjectId)
      ..writeByte(5)
      ..write(obj.topicId)
      ..writeByte(6)
      ..write(obj.note)
      ..writeByte(7)
      ..write(obj.feeling)
      ..writeByte(8)
      ..write(obj.taskId)
      ..writeByte(9)
      ..write(obj.runId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
