// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TaskModelAdapter extends TypeAdapter<TaskModel> {
  @override
  final int typeId = 2;

  @override
  TaskModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskModel(
      id: fields[0] as String,
      title: fields[1] as String,
      subjectId: fields[2] as String?,
      dueDate: fields[3] as DateTime,
      isCompleted: fields[4] as bool,
      priority: fields[5] as TaskPriority,
      createdAt: fields[6] as DateTime,
      completedAt: fields[7] as DateTime?,
      scheduledTime: fields[8] as DateTime?,
      estimatedMinutes: fields[9] as int?,
      difficulty: fields[10] as TopicDifficulty,
    );
  }

  @override
  void write(BinaryWriter writer, TaskModel obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.subjectId)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.isCompleted)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.completedAt)
      ..writeByte(8)
      ..write(obj.scheduledTime)
      ..writeByte(9)
      ..write(obj.estimatedMinutes)
      ..writeByte(10)
      ..write(obj.difficulty);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskPriorityAdapter extends TypeAdapter<TaskPriority> {
  @override
  final int typeId = 1;

  @override
  TaskPriority read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskPriority.low;
      case 1:
        return TaskPriority.medium;
      case 2:
        return TaskPriority.high;
      default:
        return TaskPriority.low;
    }
  }

  @override
  void write(BinaryWriter writer, TaskPriority obj) {
    switch (obj) {
      case TaskPriority.low:
        writer.writeByte(0);
        break;
      case TaskPriority.medium:
        writer.writeByte(1);
        break;
      case TaskPriority.high:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskPriorityAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TopicDifficultyAdapter extends TypeAdapter<TopicDifficulty> {
  @override
  final int typeId = 5;

  @override
  TopicDifficulty read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TopicDifficulty.easy;
      case 1:
        return TopicDifficulty.medium;
      case 2:
        return TopicDifficulty.hard;
      default:
        return TopicDifficulty.easy;
    }
  }

  @override
  void write(BinaryWriter writer, TopicDifficulty obj) {
    switch (obj) {
      case TopicDifficulty.easy:
        writer.writeByte(0);
        break;
      case TopicDifficulty.medium:
        writer.writeByte(1);
        break;
      case TopicDifficulty.hard:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicDifficultyAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
