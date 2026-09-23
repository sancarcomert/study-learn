// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deneme_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DenemeSectionScoreAdapter extends TypeAdapter<DenemeSectionScore> {
  @override
  final int typeId = 10;

  @override
  DenemeSectionScore read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DenemeSectionScore(
      subject: fields[0] as String,
      correct: fields[1] as int,
      wrong: fields[2] as int,
      blank: fields[3] as int,
      weakTopicIds: fields[4] == null
          ? <String>[]
          : (fields[4] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, DenemeSectionScore obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.subject)
      ..writeByte(1)
      ..write(obj.correct)
      ..writeByte(2)
      ..write(obj.wrong)
      ..writeByte(3)
      ..write(obj.blank)
      ..writeByte(4)
      ..write(obj.weakTopicIds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DenemeSectionScoreAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class DenemeEntryAdapter extends TypeAdapter<DenemeEntry> {
  @override
  final int typeId = 11;

  @override
  DenemeEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DenemeEntry(
      id: fields[0] as String,
      examType: fields[1] as String,
      name: fields[2] as String?,
      date: fields[3] as DateTime,
      sections: (fields[4] as List).cast<DenemeSectionScore>(),
    );
  }

  @override
  void write(BinaryWriter writer, DenemeEntry obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.examType)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.sections);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DenemeEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
