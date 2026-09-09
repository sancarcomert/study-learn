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

  // Onboarding akışının gösterilip gösterilmediğini işaretler.
  // Nullable: mevcut (bu alan eklenmeden önce oluşturulmuş) kayıtlarda
  // hiç yazılmadığı için Hive bunu null olarak okur — kullanım yerinde
  // bu null, "true" (onboarding'i atla) olarak yorumlanır, çünkü bu bir
  // zaten var olan kullanıcı demektir. Sadece yeni oluşturulan
  // UserStatsModel() çağrısında açıkça false verilir.
  @HiveField(7)
  bool? hasCompletedOnboarding;

  // Kullanıcının kendi girdiği isim — Profile ekranındaki sabit
  // "Öğrenci" yerine kişiselleştirme için eklendi. Nullable: bu alan
  // eklenmeden önce oluşturulmuş kayıtlarda null gelir, UI tarafında
  // null ise "Öğrenci" varsayılanı gösterilir.
  @HiveField(8)
  String? userName;

  // Bildirim izni açıklama ekranının gösterilip gösterilmediğini işaretler.
  // hasCompletedOnboarding ile aynı desen: nullable, çünkü bu alan
  // eklenmeden önce oluşturulmuş kayıtlarda null okunur — bu da "henüz
  // gösterilmedi" anlamına gelir, mevcut kullanıcılar da bir kere görür.
  @HiveField(9)
  bool? hasSeenNotificationPrompt;

  // Kullanıcının hedeflediği sınav tarihi (YKS vb). Opsiyonel — onboarding'de
  // atlanabilir, sonradan İstatistik ekranından girilebilir. Null ise
  // hiçbir yerde geri sayım gösterilmez.
  @HiveField(10)
  DateTime? examDate;

  // Odak seanslarında GERÇEKTEN ölçülen toplam dakika. totalStudyMinutes'tan
  // ayrı tutulur: o alan tamamlanan görevlerin TAHMİNİ süresini biriktirir,
  // bu ise kronometreyle ölçülen gerçek süreyi. İkisi karışmasın diye ayrı.
  // defaultValue: bu alan eklenmeden önce yazılmış kayıtlarda fields[11]
  // null döner; non-nullable int cast'i patlamasın diye 0 varsayılır.
  @HiveField(11, defaultValue: 0)
  int focusMinutes;

  UserStatsModel({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.dailyGoal = 3,
    this.freezesAvailable = 1,
    this.totalCompletedTasks = 0,
    this.totalStudyMinutes = 0,
    this.hasCompletedOnboarding = false,
    this.userName,
    this.hasSeenNotificationPrompt = false,
    this.examDate,
    this.focusMinutes = 0,
  });
}