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

  FocusSession({
    required this.id,
    required this.endedAt,
    required this.minutes,
    required this.mode,
    this.subjectId,
    this.topicId,
    this.note,
  });
}
