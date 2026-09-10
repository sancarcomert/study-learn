import 'package:hive/hive.dart';

part 'daily_closeout_model.g.dart';

/// "Bugünü kapat" ritüelinin bir günlük kaydı (docs/rakip_analizi §6 B3).
/// Forest/YPT gibi rakiplerin vermediği "kapanış" hissi: akşam kısa bir özet
/// + yarına tek cümlelik niyet.
///
/// Ayrı Hive box'ında (`daily_closeouts`, typeId 9). Mevcut modellere
/// dokunulmadı — FocusSession / TopicModel ile aynı izole desen. Gün başına
/// tek kayıt: [id] gün anahtarıdır ("2026-09-10"), `put` üzerine yazar.
@HiveType(typeId: 9)
class DailyCloseout extends HiveObject {
  @HiveField(0)
  String id;

  /// Kapatılan gün (saat 00:00).
  @HiveField(1)
  DateTime date;

  /// Yarına tek cümlelik niyet. Boş olabilir (kullanıcı yazmadan kapattı).
  @HiveField(2)
  String intent;

  /// O gün tamamlanan görev sayısı (kapatma anındaki anlık görüntü).
  @HiveField(3)
  int completedTasks;

  /// O gün kronometreyle ölçülen odak dakikası (anlık görüntü).
  @HiveField(4)
  int focusMinutes;

  /// Günün kapatıldığı an.
  @HiveField(5)
  DateTime closedAt;

  DailyCloseout({
    required this.id,
    required this.date,
    required this.intent,
    required this.completedTasks,
    required this.focusMinutes,
    required this.closedAt,
  });

  static String dayKey(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}';

  static String _two(int n) => n.toString().padLeft(2, '0');
}
