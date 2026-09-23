import 'focus_session_model.dart';
import 'task_model.dart';

/// Bir günün PLANI: "bu gün ne yapmam gerekiyor?" — Görevler sekmesinin gün
/// şeridi ve gün özeti bunu kullanır.
class DayPlanSummary {
  final int total;
  final int completed;
  final int plannedMinutes;

  const DayPlanSummary({
    required this.total,
    required this.completed,
    required this.plannedMinutes,
  });

  int get pending => total - completed;
  bool get isEmpty => total == 0;
  bool get allDone => total > 0 && completed == total;
}

/// Bir gün içinde tek bir Focus ÇALIŞMASI (tüm dilimleri birleşik).
class DayFocusRun {
  final String runKey;
  final String? subjectId;
  final String? topicId;
  final String? taskId;
  final int minutes;

  /// Öğrencinin cevabı ([FocusFeeling]); cevaplanmadıysa null.
  final int? feeling;

  const DayFocusRun({
    required this.runKey,
    required this.subjectId,
    required this.topicId,
    required this.taskId,
    required this.minutes,
    required this.feeling,
  });
}

/// Bir günün GERÇEK KAYDI: "o gün ne planlandı, ne yapıldı, gerçekte ne kadar
/// sürdü?" Çalışma Takvimi'nde bir güne dokununca gösterilir. Yeni bir veri
/// kaynağı DEĞİL — görevler ve Focus çalışmalarından türer.
class DayLog {
  final DateTime day;

  /// O gün planlanan (vade tarihi o gün) VE o gün tamamlanan görevler —
  /// tekrarsız. Plan-gerçek karşılaştırması için.
  final List<TaskModel> tasks;

  /// O gün yapılan Focus çalışmaları (çalışma başına tek satır).
  final List<DayFocusRun> runs;

  const DayLog({required this.day, required this.tasks, required this.runs});

  int get focusMinutes => runs.fold(0, (a, r) => a + r.minutes);
  int get completedCount => tasks.where((t) => t.isCompleted).length;
  bool get isEmpty => tasks.isEmpty && runs.isEmpty;

  /// Bir göreve bağlı çalışma(lar) — gerçek süre ve cevap bunlardan.
  Iterable<DayFocusRun> runsForTask(String taskId) =>
      runs.where((r) => r.taskId == taskId);

  /// Hiçbir listelenen göreve bağlı olmayan çalışmalar (konu kısayolundan,
  /// serbest, ya da başka güne ait görevden).
  List<DayFocusRun> get looseRuns {
    final ids = {for (final t in tasks) t.id};
    return runs.where((r) => r.taskId == null || !ids.contains(r.taskId)).toList();
  }
}

class DaySummaries {
  const DaySummaries._();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DayPlanSummary plan(Iterable<TaskModel> tasks, DateTime day) {
    var total = 0;
    var completed = 0;
    var minutes = 0;
    for (final t in tasks) {
      if (!_sameDay(t.dueDate, day)) continue;
      total++;
      if (t.isCompleted) completed++;
      minutes += t.estimatedMinutes ?? 0;
    }
    return DayPlanSummary(
      total: total,
      completed: completed,
      plannedMinutes: minutes,
    );
  }

  static DayLog log(
    DateTime day,
    Iterable<TaskModel> tasks,
    Iterable<FocusSession> sessions,
  ) {
    // Tamamlanma günü (taskCompletionDay ile aynı kural): completedAt yoksa
    // vade tarihi.
    final dayTasks = tasks
        .where((t) =>
            _sameDay(t.dueDate, day) ||
            (t.isCompleted && _sameDay(t.completedAt ?? t.dueDate, day)))
        .toList()
      ..sort((a, b) {
        // Tamamlanmamışlar önce (yapılacak), sonra tamamlananlar; içeride saat.
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        final at = a.scheduledTime, bt = b.scheduledTime;
        if (at != null && bt != null) return at.compareTo(bt);
        if (at != null) return -1;
        if (bt != null) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });

    final byRun = <String, List<FocusSession>>{};
    for (final s in sessions) {
      if (!_sameDay(s.endedAt, day)) continue;
      byRun.putIfAbsent(s.runKey, () => []).add(s);
    }
    final runs = <DayFocusRun>[];
    byRun.forEach((key, list) {
      list.sort((a, b) => a.endedAt.compareTo(b.endedAt));
      final first = list.first;
      final answered = list.where((s) => s.feeling != null);
      runs.add(DayFocusRun(
        runKey: key,
        subjectId: first.subjectId,
        topicId: first.topicId,
        taskId: first.taskId,
        minutes: list.fold(0, (a, s) => a + s.minutes),
        feeling: answered.isEmpty ? null : answered.last.feeling,
      ));
    });

    return DayLog(day: day, tasks: dayTasks, runs: runs);
  }
}
