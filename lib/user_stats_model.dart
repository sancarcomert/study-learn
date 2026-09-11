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

  // Home'daki tek seferlik "görev ipuçları" şeridi gösterildi mi?
  // defaultValue: eski kayıtlar için de "gösterilmedi" (bir kere görürler).
  @HiveField(12, defaultValue: false)
  bool hasSeenTaskHints;

  // Kullanıcının sınıfı — kişiselleştirme için (onboarding'de sorulur,
  // Profil'den değiştirilir). 9–12 = lise sınıfı, 13 = Mezun. Nullable:
  // girmeyen / eski kayıtlarda null; UI "belirtilmemiş" gösterir ve
  // varsayılan (nazik) davranışa düşer.
  @HiveField(13)
  int? gradeLevel;

  // Odak seansı "tam zamanında bildirim" izin açıklamasının gösterilip
  // gösterilmediğini işaretler — hasSeenNotificationPrompt ile aynı desen,
  // ayrı tutulur çünkü bu SCHEDULE_EXACT_ALARM'a özel (Android 13+'ta
  // normal bildirim izninden bağımsız, ayrı bir Ayarlar ekranına yönlendirir).
  @HiveField(14, defaultValue: false)
  bool hasSeenExactAlarmPrompt;

  // İlk-60-saniye psikolojisi: kullanıcının kendi eklediği ilk (gerçek)
  // görev bir kez küçük bir kutlama alır. defaultValue: true — eski
  // kayıtlarda (zaten görevi olan kullanıcılarda) bu alan yokken true
  // okunur, yani "zaten geçti" sayılır, geriye dönük kutlama çıkmaz.
  // Yeni kullanıcı için constructor'da açıkça false verilir. Onboarding'in
  // eklediği örnek görev bunu true YAPMAZ — yalnız Yeni Görev ekranı ve
  // Çalışma Koçu'nun gerçek eklemeleri sayılır (bkz. add_task_screen,
  // coach_screen).
  @HiveField(15, defaultValue: true)
  bool hasAddedFirstTask;

  UserStatsModel({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    // Yeni kullanıcı için 1: ilk gün tek görevle "hedefi tamamladın"
    // hissini yakalasın. Mevcut kayıtlar zaten kendi değerini taşır.
    this.dailyGoal = 1,
    this.freezesAvailable = 1,
    this.totalCompletedTasks = 0,
    this.totalStudyMinutes = 0,
    this.hasCompletedOnboarding = false,
    this.userName,
    this.hasSeenNotificationPrompt = false,
    this.examDate,
    this.focusMinutes = 0,
    this.hasSeenTaskHints = false,
    this.gradeLevel,
    this.hasSeenExactAlarmPrompt = false,
    this.hasAddedFirstTask = false,
  });

  /// 13 = Mezun, 9–12 = lise sınıfı, null = belirtilmemiş.
  static const int mezun = 13;

  static String gradeLabel(int? g) => switch (g) {
        null => 'Sınıf belirtilmedi',
        mezun => 'Mezun',
        _ => '$g. sınıf',
      };

  /// Sınava odaklı ton (11–12 + mezun) mu, alışkanlık odaklı (9–10) mu?
  static bool isExamFocused(int? g) => g != null && (g >= 11);
}