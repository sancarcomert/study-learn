import 'format_minutes.dart';
import 'task_model.dart';

/// Bugünün ÇALIŞMA özeti: gerçekleşen ↔ planlanan. İki sayı bilerek AYRI ve
/// karıştırılmaz:
/// - [actualMinutes]: gerçekten ÖLÇÜLMÜŞ odak süresi (FocusSession kayıtları +
///   devam eden seansın henüz yazılmamış kısmı). Tahmin, XP ya da görev sayısı
///   ASLA buraya girmez.
/// - [plannedMinutes]: bugünün görevlerinde öğrencinin yazdığı TAHMİNİ süreler.
///   Süresi girilmemiş görev 0 sayılır (uydurma süre yok); hiç süre girilmemişse
///   plan yoktur ([hasPlan] false).
class TodayStudy {
  final int actualMinutes;
  final int plannedMinutes;

  /// Şu an devam eden bir seans varsa onun sayılan süresi (dk); yoksa null.
  final int? runningMinutes;

  /// Bugüne vadeli görev sayısı ve bunlardan bitenler — plan TAMAMLANDIĞI hâlde
  /// (görev işaretlenerek) ölçülmüş süre yoksa satır "henüz başlamadın" DEMEZ.
  final int tasksToday;
  final int tasksDone;

  const TodayStudy({
    required this.actualMinutes,
    required this.plannedMinutes,
    this.runningMinutes,
    this.tasksToday = 0,
    this.tasksDone = 0,
  });

  bool get planDone => tasksToday > 0 && tasksDone >= tasksToday;

  bool get hasPlan => plannedMinutes > 0;
  bool get hasStudied => actualMinutes > 0;

  /// [loggedMinutes]: bugün yazılmış FocusSession dakikaları. [liveMinutes]:
  /// devam eden seansın henüz yazılmamış tam dakikası. Planlanan: vadesi bugün
  /// olan TÜM görevlerin (bitenler dahil) tahmini süreleri — "bugünkü plan".
  factory TodayStudy.compute({
    required Iterable<TaskModel> tasks,
    required int loggedMinutes,
    int liveMinutes = 0,
    int? runningMinutes,
    required DateTime now,
  }) {
    var planned = 0;
    var today = 0;
    var done = 0;
    for (final t in tasks) {
      final d = t.dueDate;
      if (d.year == now.year && d.month == now.month && d.day == now.day) {
        planned += t.estimatedMinutes ?? 0;
        today++;
        if (t.isCompleted) done++;
      }
    }
    return TodayStudy(
      actualMinutes: loggedMinutes + liveMinutes,
      plannedMinutes: planned,
      runningMinutes: runningMinutes,
      tasksToday: today,
      tasksDone: done,
    );
  }
}

/// Home başlığının altındaki tek satır: gerçekleşen ↔ planlanan. Görev sayısı
/// ("3/5 görev") DEĞİL, gerçek çalışma dakikası — Dodom görev yöneticisi gibi
/// değil, çalışmayı başlatan bir sistem gibi konuşur.
String todayStudyLine(TodayStudy s, {required bool hasTasksToday}) {
  if (s.hasStudied && s.hasPlan) {
    return '${formatMinutes(s.actualMinutes)} çalıştın · plan '
        '${formatMinutes(s.plannedMinutes)}';
  }
  if (s.hasStudied) return '${formatMinutes(s.actualMinutes)} çalıştın';
  // Plan görev işaretlenerek bitmiş ama Odak'ta ölçülmüş süre yok: "başlamadın"
  // yanlış olur; ölçülmediğini dürüstçe söyle.
  if (s.planDone) return 'Bugünkü görevlerin tamam · odak süresi ölçülmedi';
  if (s.hasPlan) {
    return 'Bugünkü plan ${formatMinutes(s.plannedMinutes)} · henüz başlamadın';
  }
  return hasTasksToday
      ? 'Henüz başlamadın — ilk çalışma hazır.'
      : 'Bugün hedeflerine bir adım daha yaklaşalım.';
}
