import 'study_advisor.dart';
import 'task_model.dart';
import 'topic_model.dart';

/// Süre verilmemiş bir çalışmanın varsayılan uzunluğu (dk). Focus bu süreyle
/// açılır; kartlar da "ne kadar?" sorusuna aynı sayıyla cevap verir — arayüzde
/// ve Focus'ta ayrı ayrı yazılmış bir "25" olmasın.
const int kDefaultFocusMinutes = 25;

/// Bir çalışma niyetinin NEREDEN geldiği.
enum StudyIntentSource {
  /// Öneri motorundan (Home kartı) — gerekçesi öğrenciye gösterilmiş öneri.
  recommendation,

  /// Bir görevden başlatıldı.
  task,

  /// Konu listesinden bir konuya dokunuldu ("bunu çalışmak istiyorum").
  topic,

  /// Hiçbir bağlam yok — serbest çalışma.
  free,
}

/// "Ne çalışıyorum, neden, ne kadar" — Focus'a giden BAĞLAM, tek bir alan
/// nesnesi olarak. Önceden Home/Görev/Konu/Koç Focus'u 7 ayrı gevşek parametreyle
/// açıyor, her biri bağlamı kendi kafasına göre yeniden kuruyordu (ve öneri
/// gerekçesi yolda kayboluyordu). Artık bağlamı KAYNAK üretir ve olduğu gibi
/// taşınır; Focus onu yeniden türetmez.
///
/// Bir niyet çalışma KANITI değildir: yalnızca "şunu yapmak istiyorum"dur.
/// Kanıt ancak gerçek bir çalışma olayından (bkz. StudyEvents) doğar.
class StudyIntent {
  final StudyIntentSource source;
  final String? subjectId;
  final String? topicId;

  /// Bağlı görev — Focus bitince tamamlanabilsin, harcanan süre görevle
  /// ilişkilensin diye.
  final String? taskId;

  /// Kısa "ne" başlığı (görev başlığı ya da konu adı).
  final String? title;

  /// Planlanan/önerilen süre, dakika.
  final int? targetMinutes;

  /// "Neden bu?" — öğrenciye HANGİ metin gösterildiyse o (öneri gerekçesi ya da
  /// görevin planlanırken yazılmış gerekçesi). Somut bir sinyal yoksa null;
  /// sahte gerekçe üretilmez.
  final String? reason;

  const StudyIntent({
    required this.source,
    this.subjectId,
    this.topicId,
    this.taskId,
    this.title,
    this.targetMinutes,
    this.reason,
  });

  /// Bağlamsız serbest çalışma.
  static const StudyIntent free = StudyIntent(source: StudyIntentSource.free);

  factory StudyIntent.forTask(TaskModel task, {String? reason}) => StudyIntent(
        source: StudyIntentSource.task,
        subjectId: task.subjectId,
        topicId: task.topicId,
        taskId: task.id,
        title: task.title,
        targetMinutes: task.estimatedMinutes,
        reason: reason ?? task.sourceReason,
      );

  factory StudyIntent.forTopic(TopicModel topic, {String? reason}) =>
      StudyIntent(
        source: StudyIntentSource.topic,
        subjectId: topic.subjectId,
        topicId: topic.id,
        title: topic.name,
        reason: reason,
      );

  /// Öneri motorunun önerisinden. [topicId], öneri belirli bir konuyu anıyorsa
  /// (bkz. [StudySuggestion.topicName]) o konunun gerçek id'si.
  factory StudyIntent.forRecommendation(
    StudySuggestion suggestion, {
    String? topicId,
  }) =>
      StudyIntent(
        source: StudyIntentSource.recommendation,
        subjectId: suggestion.subjectId,
        topicId: topicId,
        title: suggestion.topicName,
        reason: suggestion.reason == StudyAdvisor.genericReason
            ? null
            : suggestion.reason,
      );

  StudyIntent copyWith({String? reason}) => StudyIntent(
        source: source,
        subjectId: subjectId,
        topicId: topicId,
        taskId: taskId,
        title: title,
        targetMinutes: targetMinutes,
        reason: reason ?? this.reason,
      );
}
