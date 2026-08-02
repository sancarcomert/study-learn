import 'package:hive/hive.dart';

part 'user_progress.g.dart';

@HiveType(typeId: 3)
class UserProgress extends HiveObject {

  @HiveField(0)
  int xp;

  @HiveField(1)
  int level;

  @HiveField(2)
  int totalCompletedTasks;

  UserProgress({
    this.xp = 0,
    this.level = 1,
    this.totalCompletedTasks = 0,
  });
}