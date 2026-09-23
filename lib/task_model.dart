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

  // Kaç kez ertelendi (TaskSwipeActions'taki sağa-kaydır). Önceden hiç
  // tutulmuyordu — bir görev 10 kere ertelenmiş olsa bile sistem bunu
  // "bugüne kalan sıradan bir görev"den ayırt edemiyordu. Artık kronik
  // ertelemeyi StudyAdvisor + "bugüne taşı" diyaloğu fark edip farklı
  // (cezalandırmayan, ama görünür) şekilde ele alabiliyor.
  // defaultValue: eski kayıtlarda 0 — hiç ertelenmemiş sayılır, doğru.
  @HiveField(14, defaultValue: 0)
  int postponeCount;

  // Gerçekte harcanan dakika — Odak Seansı bu göreve bağlı başlatılıp
  // tamamlanınca (bkz. focus_screen._completeLinkedTask) doldurulur.
  // estimatedMinutes'ın aksine ölçülmüş: "planlanan ≠ gerçekleşen"
  // farkını görünür kılar. Nullable — eski kayıtlarda ve odaksız
  // tamamlanan görevlerde null kalır, migration gerekmez.
  @HiveField(15)
  int? actualMinutes;

  // Sistemin OTOMATİK olarak yeniden planladığı sayaç — "Önceki günden kalan
  // görevleri taşı" (bkz. home_screen._maybeShowCarryOverPrompt) burayı
  // artırır. [postponeCount]'tan BİLİNÇLİ OLARAK AYRI: postponeCount yalnız
  // öğrencinin kendi kaydırma jestiyle (TaskSwipeActions/postponeTask)
  // ertelediği görevleri sayar — StudyAdvisor'ın "kaçınma" sinyali VE bu
  // sayacın ürettiği "N kez ertelendi" gerekçesi SADECE buna bakar. İkisi
  // aynı alanda birleşseydi, öğrenci birkaç gün uzak kalıp sistem geri kalanı
  // günlere yaydığında, hiç kaçınmamış olsa bile "kaçınıyorsun" mesajı
  // alırdı — sistem davranışı öğrenci davranışı gibi etiketlenmiş olurdu.
  // defaultValue: eski kayıtlarda 0.
  @HiveField(16, defaultValue: 0)
  int systemRescheduleCount;

  // Bu görevin PlanBuilder/StudyAdvisor tarafından ÖNERİLDİĞİNDE üretilen,
  // somut/gerçek bir sinyale dayanan kısa gerekçesi (ör. "Son denemende bu
  // konudan yanlış yapmıştın"). Yalnız coach_screen'in otomatik plan
  // akışından (_proposeDay/_proposeWeek → PlanBuilder) gelen görevlerde
  // dolu — kullanıcının kendi yazdığı görevlerde (manuel ekleme, tek
  // cümlelik "yarın 2 saat matematik" gibi) null kalır, çünkü zaten
  // kendi kararı, açıklamaya gerek yok. Sahte/jenerik bir gerekçe ASLA
  // üretilmez (bkz. PlanBuilder.titleFor) — somut sinyal yoksa null.
  // AddTaskScreen düzenleme modunda salt-okunur gösterilir (bkz. Faz 6/7).
  @HiveField(17)
  String? sourceReason;

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
    this.postponeCount = 0,
    this.actualMinutes,
    this.systemRescheduleCount = 0,
    this.sourceReason,
  });
}