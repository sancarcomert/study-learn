import 'task_model.dart';
import 'task_time_status.dart';
import 'topic_evidence.dart';

/// Home'un "şimdi ne yapmalıyım?" kartı için bugünün sıradaki görevini seçer.
///
/// Önceden yalnız SAATLİ görevler aday oluyordu — oysa Coach'un günlük planı
/// ve onboarding'in ilk görevi bilerek saatsiz (gün-kapsamlı) üretilir; bu
/// yüzden plan kurulduktan sonra Home "plan yok" diyordu. Artık saatsiz
/// bugünkü görevler de aday: zamanlı olanlar önce (öğrenci saat verdiyse o
/// bir taahhüttür), sonra saatsizler.
class NextTaskPicker {
  const NextTaskPicker._();

  /// Saatli bir görevin "şimdi" sayılacağı yakınlık (başlamasına en çok bu kadar
  /// kala).
  static const Duration imminentWindow = Duration(minutes: 60);

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

  /// Konu kanıtının SIRAYI değiştirme gücü. Yalnız GÜÇLÜ kanıt sırayı öne
  /// çeker (deneme kanıtı, doğrulanmış "üst üste zorlandım"); tek bir
  /// "zorlandım", "düzeliyor" ya da salt zaman ("tekrar gerekli") öğrencinin
  /// ekranını her küçük olayda oynatmasın diye sırayı DEĞİŞTİRMEZ — onlar
  /// yalnız gerekçe olarak görünür.
  static int strongEvidenceRank(TopicEvidence? e) => switch (e?.state) {
        TopicEvidenceState.weakConfirmed => 0,
        TopicEvidenceState.strugglingRepeatedly => 1,
        _ => 2,
      };

  /// Bugünün tamamlanmamış SAATSİZ görevleri, ÖNERİLEN SIRAYLA:
  /// 1) güçlü konu kanıtı olanlar (deneme zayıf > üst üste zorlandı),
  /// 2) yüksek öncelik,
  /// 3) somut bir gerekçesi (sourceReason) olanlar,
  /// 4) eklenme sırası (kanıt/öncelik yoksa öğrencinin kendi sırası korunur).
  /// [evidenceByTopic]: topicId → TopicEvidence (topicEvidenceProvider).
  static List<TaskModel> untimedToday(
    Iterable<TaskModel> tasks,
    DateTime now, {
    Map<String, TopicEvidence> evidenceByTopic = const {},
  }) {
    int rank(TaskModel t) => strongEvidenceRank(
        t.topicId == null ? null : evidenceByTopic[t.topicId]);
    return tasks
        .where((t) =>
            !t.isCompleted &&
            t.scheduledTime == null &&
            _sameDay(t.dueDate, now))
        .toList()
      ..sort((a, b) {
        final byEvidence = rank(a).compareTo(rank(b));
        if (byEvidence != 0) return byEvidence;
        final byPriority =
            _priorityRank(b.priority).compareTo(_priorityRank(a.priority));
        if (byPriority != 0) return byPriority;
        final aReason = a.sourceReason != null ? 0 : 1;
        final bReason = b.sourceReason != null ? 0 : 1;
        if (aReason != bReason) return aReason.compareTo(bReason);
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  /// Sıralama gerçekten bir SİNYALE dayanıyor mu (kanıt/öncelik/gerekçe)? Değilse
  /// sıra yalnız öğrencinin ekleme sırasıdır ve "önerilen sıra" denmez —
  /// sahte kesinlik yok.
  static bool isRecommendedOrder(
    Iterable<TaskModel> ordered, {
    Map<String, TopicEvidence> evidenceByTopic = const {},
  }) {
    return ordered.any((t) =>
        strongEvidenceRank(
                t.topicId == null ? null : evidenceByTopic[t.topicId]) <
            2 ||
        t.priority == TaskPriority.high ||
        t.sourceReason != null);
  }

  /// Kartta gösterilecek görev: sürüyor > yaklaşan > geciken (saatliler),
  /// hiçbiri yoksa saatsizlerin en öncelikli olanı. Bugün bekleyen görev yoksa
  /// null.
  static TaskModel? pick(
    Iterable<TaskModel> tasks,
    DateTime now, {
    Map<String, TopicEvidence> evidenceByTopic = const {},
  }) {
    final timed = timedToday(tasks, now);
    TaskModel? firstWith(TaskTimeStatus s) {
      for (final t in timed) {
        if (t.timeStatusAt(now) == s) return t;
      }
      return null;
    }

    // Yaklaşan saatli görev, YALNIZ yakınsa (imminentWindow) "şimdi"nin
    // eylemidir; saati saatler sonraysa "şimdi ne yapmalıyım?"ın cevabı değil
    // — o zaman hazır bekleyen (önerilen sıradaki) çalışma öne geçer.
    TaskModel? imminentUpcoming() {
      for (final t in timed) {
        if (t.timeStatusAt(now) == TaskTimeStatus.upcoming &&
            t.scheduledTime!.difference(now) <= imminentWindow) {
          return t;
        }
      }
      return null;
    }

    final untimed =
        untimedToday(tasks, now, evidenceByTopic: evidenceByTopic);
    return firstWith(TaskTimeStatus.inProgress) ??
        imminentUpcoming() ??
        firstWith(TaskTimeStatus.overdue) ??
        (untimed.isEmpty ? null : untimed.first) ??
        firstWith(TaskTimeStatus.upcoming);
  }

  /// "Sıradakiler" listesi: bugünün bekleyen görevleri (saatliler saat
  /// sırasıyla, sonra saatsizler), kartta zaten gösterilen [exclude] hariç.
  static List<TaskModel> remaining(
    Iterable<TaskModel> tasks,
    DateTime now, {
    TaskModel? exclude,
    Map<String, TopicEvidence> evidenceByTopic = const {},
  }) {
    return [
      ...timedToday(tasks, now),
      ...untimedToday(tasks, now, evidenceByTopic: evidenceByTopic),
    ].where((t) => t.id != exclude?.id).toList();
  }
}
