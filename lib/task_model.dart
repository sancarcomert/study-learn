import 'package:hive/hive.dart';

part 'task_model.g.dart';

@HiveType(typeId: 1)
enum TaskPriority {
  @HiveField(0)
  low,

  @HiveField(1)
  medium,

  @HiveField(2)
  high,
}

@HiveType(typeId: 5)
enum TopicDifficulty {
  @HiveField(0)
  easy,

  @HiveField(1)
  medium,

  @HiveField(2)
  hard,
}

@HiveType(typeId: 2)
class TaskModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? subjectId;

  @HiveField(3)
  DateTime dueDate;

  @HiveField(4)
  bool isCompleted;

  @HiveField(5)
  TaskPriority priority;

  @HiveField(6)
  DateTime createdAt;

  @HiveField(7)
  DateTime? completedAt;

  @HiveField(8)
  DateTime? scheduledTime;

  @HiveField(9)
  int? estimatedMinutes;

  @HiveField(10)
  TopicDifficulty difficulty;

  TaskModel({
    required this.id,
    required this.title,
    this.subjectId,
    required this.dueDate,
    this.isCompleted = false,
    this.priority = TaskPriority.medium,
    required this.createdAt,
    this.completedAt,
    this.scheduledTime,
    this.estimatedMinutes,
    this.difficulty = TopicDifficulty.medium,
  });
}