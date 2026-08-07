// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_stats_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserStatsModelAdapter extends TypeAdapter<UserStatsModel> {
  @override
  final int typeId = 4;

  @override
  UserStatsModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserStatsModel(
      currentStreak: fields[0] as int,
      longestStreak: fields[1] as int,
      lastCompletedDate: fields[2] as DateTime?,
      dailyGoal: fields[3] as int,
      freezesAvailable: fields[4] as int,
      totalCompletedTasks: fields[5] as int,
      totalStudyMinutes: fields[6] as int,
      hasCompletedOnboarding: fields[7] as bool?,
      userName: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserStatsModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.currentStreak)
      ..writeByte(1)
      ..write(obj.longestStreak)
      ..writeByte(2)
      ..write(obj.lastCompletedDate)
      ..writeByte(3)
      ..write(obj.dailyGoal)
      ..writeByte(4)
      ..write(obj.freezesAvailable)
      ..writeByte(5)
      ..write(obj.totalCompletedTasks)
      ..writeByte(6)
      ..write(obj.totalStudyMinutes)
      ..writeByte(7)
      ..write(obj.hasCompletedOnboarding)
      ..writeByte(8)
      ..write(obj.userName);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserStatsModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}