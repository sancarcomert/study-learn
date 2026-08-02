import 'package:hive/hive.dart';

part 'user_stats_model.g.dart';

@HiveType(typeId: 4)
class UserStatsModel extends HiveObject {
  @HiveField(0)
  int currentStreak;

  @HiveField(1)
  int longestStreak;

  @HiveField(2)
  DateTime? lastCompletedDate;

  @HiveField(3)
  int dailyGoal;

  @HiveField(4)
  int freezesAvailable;

@HiveField(5)
int totalCompletedTasks;

@HiveField(6)
int totalStudyMinutes;
  UserStatsModel({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.dailyGoal = 3,
    this.freezesAvailable = 1,
    this.totalCompletedTasks = 0,
    this.totalStudyMinutes = 0,
  });
}