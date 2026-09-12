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

  // Tekrarlayan görev altyapısı (V1: günlük/haftalık).
  // İkisi de nullable — mevcut kayıtlarda otomatik null okunur,
  // "bu görev tekrarlı değil" anlamına gelir. Migration gerekmez.

  // Aynı seriye ait tüm örnekleri birbirine bağlayan kimlik.
  // V1'de sadece kayıt amaçlı tutuluyor — seri düzenleme/silme
  // henüz bu alanı kullanmıyor (bilinçli olarak V1 dışı).
  @HiveField(11)
  String? recurringGroupId;

  // null: tekrarsız, "daily": her gün, "weekly": haftanın bu günü.
  // Haftanın hangi günü olduğu ayrıca tutulmuyor — bu bilgi zaten
  // her örneğin kendi dueDate.weekday değerinde var.
  @HiveField(12)
  String? recurrenceRule;

  // Konu Takip'teki bir konuya bağlı görev — bağlıysa, görev tamamlanınca
  // o konu otomatik "çalışıldı"ya geçer (ikisini elle ayrı ayrı işaretleme
  // zorunluluğu kalkar). Nullable: bağımsız/eski görevlerde null.
  @HiveField(13)
  String? topicId;

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
    this.recurringGroupId,
    this.recurrenceRule,
    this.topicId,
  });
}