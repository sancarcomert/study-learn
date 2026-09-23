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
      hasSeenNotificationPrompt: fields[9] as bool?,
      examDate: fields[10] as DateTime?,
      focusMinutes: fields[11] == null ? 0 : fields[11] as int,
      hasSeenTaskHints: fields[12] == null ? false : fields[12] as bool,
      gradeLevel: fields[13] as int?,
      hasSeenExactAlarmPrompt: fields[14] == null ? false : fields[14] as bool,
      hasAddedFirstTask: fields[15] == null ? true : fields[15] as bool,
      targetNetTYT: fields[16] as double?,
      targetNetAYT: fields[17] as double?,
      lastCarryOverPromptDate: fields[18] as DateTime?,
      themeMode: fields[19] is String ? fields[19] as String : 'light',
      bonusXp: fields[20] == null ? 0 : fields[20] as int,
      selfReportedWeakSubjectName: fields[21] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserStatsModel obj) {
    writer
      ..writeByte(22)
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
      ..write(obj.userName)
      ..writeByte(9)
      ..write(obj.hasSeenNotificationPrompt)
      ..writeByte(10)
      ..write(obj.examDate)
      ..writeByte(11)
      ..write(obj.focusMinutes)
      ..writeByte(12)
      ..write(obj.hasSeenTaskHints)
      ..writeByte(13)
      ..write(obj.gradeLevel)
      ..writeByte(14)
      ..write(obj.hasSeenExactAlarmPrompt)
      ..writeByte(15)
      ..write(obj.hasAddedFirstTask)
      ..writeByte(16)
      ..write(obj.targetNetTYT)
      ..writeByte(17)
      ..write(obj.targetNetAYT)
      ..writeByte(18)
      ..write(obj.lastCarryOverPromptDate)
      ..writeByte(19)
      ..write(obj.themeMode)
      ..writeByte(20)
      ..write(obj.bonusXp)
      ..writeByte(21)
      ..write(obj.selfReportedWeakSubjectName);
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
