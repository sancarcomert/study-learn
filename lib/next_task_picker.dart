import 'task_model.dart';
import 'task_time_status.dart';

/// Home'un "şimdi ne yapmalıyım?" kartı için bugünün sıradaki görevini seçer.
///
/// Önceden yalnız SAATLİ görevler aday oluyordu — oysa Coach'un günlük planı
/// ve onboarding'in ilk görevi bilerek saatsiz (gün-kapsamlı) üretilir; bu
/// yüzden plan kurulduktan sonra Home "plan yok" diyordu. Artık saatsiz
/// bugünkü görevler de aday: zamanlı olanlar önce (öğrenci saat verdiyse o
/// bir taahhüttür), sonra saatsizler.
class NextTaskPicker {
  const NextTaskPicker._();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static int _priorityRank(TaskPriority p) => switch (p) {
        TaskPriority.high => 2,
        TaskPriority.medium => 1,
        TaskPriority.low => 0,
      };

  /// Bugünün tamamlanmamış SAATLİ görevleri, saate göre.
  static List<TaskModel> timedToday(Iterable<TaskModel> tasks, DateTime now) {
    return tasks
        .where((t) =>
            !t.isCompleted &&
            t.scheduledTime != null &&
            _sameDay(t.scheduledTime!, now))
        .toList()
      ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
  }

  /// Bugünün tamamlanmamış SAATSİZ görevleri: önce yüksek öncelik, sonra bir
  /// gerekçesi (sourceReason) olanlar (somut bir sinyalden geldiler), sonra
  /// eklenme sırası.
  static List<TaskModel> untimedToday(Iterable<TaskModel> tasks, DateTime now) {
    return tasks
        .where((t) =>
            !t.isCompleted &&
            t.scheduledTime == null &&
            _sameDay(t.dueDate, now))
        .toList()
      ..sort((a, b) {
        final byPriority =
            _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
        if (byPriority != 0) return byPriority;
        final aReason = a.sourceReason != null ? 0 : 1;
        final bReason = b.sourceReason != null ? 0 : 1;
        if (aReason != bReason) return aReason.compareTo(bReason);
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  /// Kartta gösterilecek görev: sürüyor > yaklaşan > geciken (saatliler),
  /// hiçbiri yoksa saatsizlerin en öncelikli olanı. Bugün bekleyen görev yoksa
  /// null.
  static TaskModel? pick(Iterable<TaskModel> tasks, DateTime now) {
    final timed = timedToday(tasks, now);
    TaskModel? firstWith(TaskTimeStatus s) {
      for (final t in timed) {
        if (t.timeStatusAt(now) == s) return t;
      }
      return null;
    }

    return firstWith(TaskTimeStatus.inProgress) ??
        firstWith(TaskTimeStatus.upcoming) ??
        firstWith(TaskTimeStatus.overdue) ??
        (() {
          final untimed = untimedToday(tasks, now);
          return untimed.isEmpty ? null : untimed.first;
        })();
  }

  /// "Sıradakiler" listesi: bugünün bekleyen görevleri (saatliler saat
  /// sırasıyla, sonra saatsizler), kartta zaten gösterilen [exclude] hariç.
  static List<TaskModel> remaining(
    Iterable<TaskModel> tasks,
    DateTime now, {
    TaskModel? exclude,
  }) {
    return [
      ...timedToday(tasks, now),
      ...untimedToday(tasks, now),
    ].where((t) => t.id != exclude?.id).toList();
  }
}
