import 'task_model.dart';

/// Zamanlanmış bir görevin şu ana göre durumu. Veriye yazılmaz —
/// scheduledTime + estimatedMinutes'tan anlık türetilir.
enum TaskTimeStatus {
  /// scheduledTime yok ya da görev tamamlanmış — zaman rozeti gösterilmez.
  none,

  /// Başlama saati henüz gelmedi.
  upcoming,

  /// Başladı, tahmini bitiş saati geçmedi.
  inProgress,

  /// Bitiş saati (tahmini yoksa başlama saati) geçti, hâlâ tamamlanmadı.
  overdue,
}

extension TaskTimeStatusX on TaskModel {
  TaskTimeStatus timeStatusAt(DateTime now) {
    final start = scheduledTime;
    if (start == null || isCompleted) return TaskTimeStatus.none;
    if (now.isBefore(start)) return TaskTimeStatus.upcoming;

    final end = estimatedMinutes != null
        ? start.add(Duration(minutes: estimatedMinutes!))
        : start;
    if (now.isBefore(end)) return TaskTimeStatus.inProgress;
    return TaskTimeStatus.overdue;
  }

  bool isOverdueAt(DateTime now) =>
      timeStatusAt(now) == TaskTimeStatus.overdue;

  /// Görev geçmiş bir güne ait ve hâlâ tamamlanmadı mı? (Gün seviyesi —
  /// saat/dakika bakılmaz.) "Bugüne taşı" önerisi bunu kullanır.
  bool isPastDayIncompleteAt(DateTime now) {
    if (isCompleted) return false;
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    return due.isBefore(today);
  }
}
