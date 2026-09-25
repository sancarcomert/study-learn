import '../deneme_provider.dart';
import '../focus_session_provider.dart';
import '../stats_provider.dart';
import '../study_advisor.dart';
import '../study_intent.dart';
import '../study_recommendation.dart';
import '../subject_model.dart';
import '../subject_provider.dart';
import '../task_model.dart';
import '../task_provider.dart';
import '../topic_evidence.dart';
import '../topic_evidence_provider.dart';
import '../topic_model.dart';
import '../topic_provider.dart';
import '../user_stats_model.dart';
import '../widgets/exam_countdown.dart';

/// NLU cevabının dayandığı GERÇEK Dodom verisinin anlık görüntüsü.
///
/// Yeni bir "akıllılık" icat edilmez: dersler/konular/görevler, konu kanıtı
/// (TopicEvidence), StudyAdvisor önerileri ve bugünkü ölçülmüş çalışma —
/// Home/Stats/Coach'un zaten kullandığı aynı kaynaklardan toplanır.
/// [NluResponder] yalnız bu nesneyi okur (saf ve test edilebilir).
class NluContext {
  final DateTime now;
  final List<SubjectModel> subjects;
  final List<TopicModel> topics;
  final Map<String, TopicEvidence> evidence;
  final List<TaskModel> tasks;

  /// StudyAdvisor'ın TÜM dersler için sıralı önerileri.
  final List<StudySuggestion> suggestions;

  /// Bugün ölçülmüş odak süresi (dk).
  final int studiedMinutesToday;
  final int? examDays;
  final String? weakestDenemeSubjectName;

  /// Coach'un zaten ürettiği hedef→fark cümlesi / genel ilerleme özeti
  /// (ikinci bir hesap icat edilmez).
  final String? goalGapSentence;
  final String? progressSummary;

  final StudyIntent Function(TaskModel task) taskIntent;
  final StudyIntent Function(StudySuggestion suggestion) suggestionIntent;

  const NluContext({
    required this.now,
    required this.subjects,
    required this.topics,
    required this.evidence,
    required this.tasks,
    required this.suggestions,
    required this.studiedMinutesToday,
    required this.examDays,
    required this.weakestDenemeSubjectName,
    required this.goalGapSentence,
    required this.progressSummary,
    required this.taskIntent,
    required this.suggestionIntent,
  });

  factory NluContext.fromReader(
    ProviderReader read, {
    DateTime? now,
    String? goalGapSentence,
    String? progressSummary,
  }) {
    final subjects = read(subjectProvider);
    final UserStatsModel stats = read(statsProvider);
    final examDate = stats.examDate;
    final n = now ?? DateTime.now();
    int? examDays;
    if (examDate != null) {
      final d = daysUntilExam(examDate);
      if (d >= 0) examDays = d;
    }
    return NluContext(
      now: n,
      subjects: subjects,
      topics: read(topicProvider),
      evidence: read(topicEvidenceProvider),
      tasks: read(taskProvider),
      suggestions: runStudyAdvisor(read, limit: subjects.length),
      studiedMinutesToday: read(focusTodayMinutesProvider),
      examDays: examDays,
      weakestDenemeSubjectName: read(weakestDenemeSubjectNameProvider),
      goalGapSentence: goalGapSentence,
      progressSummary: progressSummary,
      taskIntent: (t) => intentForTask(read, t),
      suggestionIntent: (s) => intentForSuggestion(read, s),
    );
  }

  SubjectModel? subjectById(String? id) {
    if (id == null) return null;
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  TopicModel? topicById(String? id) {
    if (id == null) return null;
    for (final t in topics) {
      if (t.id == id) return t;
    }
    return null;
  }
}
