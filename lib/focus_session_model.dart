import 'package:hive/hive.dart';

part 'focus_session_model.g.dart';

/// Tamamlanan bir odak dilimi. `UserStatsModel.focusMinutes` (tarihsiz
/// kümülatif toplam) yerini almaz — onun yanında, tarihli kayıt tutar ki
/// İstatistik'te trend gösterilebilsin. Ayrı Hive box'ında (typeId 8);
/// mevcut modellere dokunulmadı.
@HiveType(typeId: 8)
class FocusSession extends HiveObject {
  @HiveField(0)
  String id;

  /// Dilimin bittiği an (gün grafiği bunun tarihine göre).
  @HiveField(1)
  DateTime endedAt;

  @HiveField(2)
  int minutes;

  /// "serbest" | "pomodoro"
  @HiveField(3)
  String mode;

  /// Hangi derse çalışıldığı — opsiyonel, geçmişte "45 dk, Serbest" gibi
  /// içeriksiz kayıtlar yerine "Matematik · 45 dk" gösterebilmek için.
  /// Nullable: eski kayıtlarda ve ders seçilmeden başlatılan seanslarda null.
  @HiveField(4)
  String? subjectId;

  /// Konu Takip'teki bir konuya bağlıysa id'si — seans bitince o konu
  /// otomatik "çalışıldı"ya geçer (task_provider'daki görev-konu bağıyla
  /// aynı desen).
  @HiveField(5)
  String? topicId;

  /// Kullanıcının seans başında yazdığı serbest not (ör. görev başlığı).
  /// Önceden yalnız bildirim metninde kullanılıp atılıyordu — artık kalıcı.
  @HiveField(6)
  String? note;

  /// Öğrencinin seans bitince tek dokunuşla verdiği "nasıl geçti" cevabı —
  /// [FocusFeeling] sabitleri (0 zorlandım, 1 iyi, 2 çok iyi). Nullable:
  /// eski kayıtlarda ve cevap verilmeyen (atlanan) seanslarda null — "hiç
  /// sorulmadı/cevaplanmadı" demek, "iyi geçti" DEĞİL.
  @HiveField(7)
  int? feeling;

  /// Bu seans bir GÖREVDEN başlatıldıysa o görevin id'si. Görev tamamlanınca
  /// "bu çalışma zaten ölçüldü mü?" (ve gerçek harcanan süre) sorularının
  /// tek kaynağı — görev tamamlaması aynı çalışmayı ikinci kez saymasın diye.
  @HiveField(8)
  String? taskId;

  /// Aynı Focus çalışmasının (bir ya da çok dilimden — Pomodoro blokları,
  /// arka plana alma checkpoint'leri) dilimlerini birbirine bağlayan kimlik.
  /// "Bir çalışma = bir olay" bunun üzerinden sayılır (konu ilerlemesi,
  /// "üst üste zorlandım" gibi). Eski kayıtlarda null: her dilim kendi başına
  /// bir çalışma sayılır.
  @HiveField(9)
  String? runId;

  /// Dilimin ait olduğu çalışmanın kimliği (runId yoksa kayıt kimliği).
  String get runKey => runId ?? id;

  FocusSession({
    required this.id,
    required this.endedAt,
    required this.minutes,
    required this.mode,
    this.subjectId,
    this.topicId,
    this.note,
    this.feeling,
    this.taskId,
    this.runId,
  });
}

/// [FocusSession.feeling] değerleri.
class FocusFeeling {
  const FocusFeeling._();

  static const int hard = 0; // Zorlandım
  static const int ok = 1; // Normaldi
  static const int great = 2; // İyi gitti

  static String label(int feeling) => switch (feeling) {
        hard => 'Zorlandım',
        great => 'İyi gitti',
        _ => 'Normaldi',
      };

  static String emoji(int feeling) => switch (feeling) {
        hard => '😕',
        great => '🔥',
        _ => '🙂',
      };
}
