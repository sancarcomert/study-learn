// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TopicModelAdapter extends TypeAdapter<TopicModel> {
  @override
  final int typeId = 7;

  @override
  TopicModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TopicModel(
      id: fields[0] as String,
      subjectId: fields[1] as String,
      name: fields[2] as String,
      status: fields[3] as TopicStatus,
      createdAt: fields[4] as DateTime,
      updatedAt: fields[5] as DateTime?,
      activityKeys: (fields[6] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, TopicModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.subjectId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.updatedAt)
      ..writeByte(6)
      ..write(obj.activityKeys);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TopicStatusAdapter extends TypeAdapter<TopicStatus> {
  @override
  final int typeId = 6;

  @override
  TopicStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TopicStatus.notStarted;
      case 1:
        return TopicStatus.studied;
      case 2:
        return TopicStatus.reviewed;
      default:
        return TopicStatus.notStarted;
    }
  }

  @override
  void write(BinaryWriter writer, TopicStatus obj) {
    switch (obj) {
      case TopicStatus.notStarted:
        writer.writeByte(0);
        break;
      case TopicStatus.studied:
        writer.writeByte(1);
        break;
      case TopicStatus.reviewed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
