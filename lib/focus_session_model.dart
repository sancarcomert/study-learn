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

  FocusSession({
    required this.id,
    required this.endedAt,
    required this.minutes,
    required this.mode,
  });
}
