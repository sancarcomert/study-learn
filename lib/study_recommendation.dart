import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deneme_provider.dart';
import 'focus_session_provider.dart';
import 'goal_gap_provider.dart';
import 'stats_provider.dart';
import 'study_advisor.dart';
import 'study_intent.dart';
import 'subject_provider.dart';
import 'task_model.dart';
import 'task_provider.dart';
import 'topic_evidence_provider.dart';
import 'topic_provider.dart';

/// `ref.watch` / `ref.read` (hem `Ref` hem `WidgetRef`) bu imzayla eşleşir —
/// öneri motorunu çağıran ekranlar kendi okuma stratejisini (izleyerek/tek
/// seferlik) seçer, motorun girdileri TEK yerde toplanır.
typedef ProviderReader = T Function<T>(ProviderListenable<T> provider);

/// [StudyAdvisor.suggest]'in TÜM girdilerini uygulamanın canlı verisinden
/// toplayıp çağırır. Önceden aynı ~15 satırlık bağlantı Home, İstatistik ve
/// Koç'ta (3 yerde) kopyalanmıştı; yeni bir sinyal eklendiğinde birinin
/// atlanması, ekranların birbiriyle çelişen öneriler vermesi demekti.
List<StudySuggestion> runStudyAdvisor(ProviderReader read,
    {required int limit}) {
  final subjects = read(subjectProvider);
  if (subjects.isEmpty) return const [];
  final coverage = read(coverageBySubjectProvider);
  return StudyAdvisor.suggest(
    subjects: subjects,
    tasks: read(taskProvider),
    examDate: read(statsProvider).examDate,
    limit: limit,
    coveragePercent: {
      for (final e in coverage.entries)
        if (e.value.hasTopics) e.key: e.value.ratio,
    },
    weakestDenemeSubjectId: read(weakestDenemeSubjectIdProvider),
    focusMinutesBySubject: read(focusMinutesBySubjectProvider),
    staleReviewSubjectIds: read(staleReviewSubjectIdsProvider),
    worseningDenemeSubjectIds: read(worseningDenemeSubjectIdsProvider),
    difficultTopicsBySubject: read(difficultTopicNamesBySubjectProvider),
    selfReportedWeakSubjectId: read(selfReportedWeakSubjectIdProvider),
    examWeakTopicsBySubject: read(examWeakTopicNamesBySubjectProvider),
    goalGapAmplifier: read(goalGapAmplifierProvider),
    struggledTopicsBySubject: read(struggledTopicNamesBySubjectProvider),
    repeatedStruggleTopicsBySubject:
        read(repeatedStruggleTopicNamesBySubjectProvider),
  );
}

/// Bir öneriyi Focus'un anlayacağı [StudyIntent]'e çevirir; öneri bir konuyu
/// anıyorsa o konunun gerçek id'sini kaynak sağlayıcılardan (deneme / çalışma
/// cevapları) çözer — arayüz isimden id tahmin etmez.
StudyIntent intentForSuggestion(ProviderReader read, StudySuggestion s) {
  String? topicId;
  final name = s.topicName;
  if (name != null) {
    final candidates = [
      ...?read(examWeakTopicsBySubjectProvider)[s.subjectId],
      ...?read(repeatedStruggleTopicsBySubjectProvider)[s.subjectId],
      ...?read(struggledTopicsBySubjectProvider)[s.subjectId],
    ];
    topicId = candidates.firstWhereOrNull((t) => t.name == name)?.id;
  }
  return StudyIntent.forRecommendation(s, topicId: topicId);
}

/// Bir görevin öğrenciye gösterilecek "neden"i: göreve bağlı konunun CANLI
/// kanıtı (deneme / çalışma) önce, yoksa planlanırken yazılmış gerekçe. İkisi
/// de yoksa null. Home kartı, görev satırı ve Focus AYNI metni göstersin diye
/// tek yerde.
String? reasonForTask(ProviderReader read, TaskModel task) {
  final topicId = task.topicId;
  if (topicId != null) {
    final live = read(topicEvidenceProvider)[topicId]?.sentence;
    if (live != null) return live;
  }
  return task.sourceReason;
}

/// Bir görevden Focus niyeti — gerekçe [reasonForTask] ile.
StudyIntent intentForTask(ProviderReader read, TaskModel task) =>
    StudyIntent.forTask(task, reason: reasonForTask(read, task));
