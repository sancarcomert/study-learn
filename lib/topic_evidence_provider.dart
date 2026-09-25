import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'day_rollover.dart';

import 'deneme_provider.dart';
import 'focus_session_provider.dart';
import 'task_provider.dart' show overranTopicIdsProvider;
import 'topic_evidence.dart';
import 'topic_model.dart';
import 'topic_provider.dart';

/// Öğrencinin çalışma sonu cevaplarından (+ aynı konuda gerçek sürenin tahmini
/// aşması gibi davranışsal kanıttan) konu başına [DifficultySignal] — bkz.
/// [TopicEvidenceEngine.difficultySignals]. Tek kaynak: rozet, Home önerisi,
/// Focus bağlamı, Coach planı ve öneri motoru buradan okur.
final topicDifficultyProvider = Provider<Map<String, DifficultySignal>>((ref) {
  return TopicEvidenceEngine.difficultySignals(
    ref.watch(focusSessionProvider),
    overranTopicIds: ref.watch(overranTopicIdsProvider),
  );
});

/// [topicDifficultyProvider]'ın [signal] seviyesindeki konuları, ders bazında
/// {ad, id} — examWeakTopicsBySubjectProvider ile aynı şekil (StudyAdvisor'a
/// adlar, Home/Plan'a id lazım).
Map<String, List<({String name, String id})>> _bySubject(
  Map<String, DifficultySignal> signals,
  List<TopicModel> topics,
  DifficultySignal signal,
) {
  final result = <String, List<({String name, String id})>>{};
  for (final t in topics) {
    if (signals[t.id] != signal) continue;
    result.putIfAbsent(t.subjectId, () => []).add((name: t.name, id: t.id));
  }
  return result;
}

/// Son çalışmada "zorlandım" denen (henüz doğrulanmamış, tek sinyal) konular.
final struggledTopicsBySubjectProvider =
    Provider<Map<String, List<({String name, String id})>>>((ref) => _bySubject(
          ref.watch(topicDifficultyProvider),
          ref.watch(topicProvider),
          DifficultySignal.recent,
        ));

/// Birbirini doğrulayan kanıtla "üst üste zorlanılan" konular.
final repeatedStruggleTopicsBySubjectProvider =
    Provider<Map<String, List<({String name, String id})>>>((ref) => _bySubject(
          ref.watch(topicDifficultyProvider),
          ref.watch(topicProvider),
          DifficultySignal.repeated,
        ));

Map<String, List<String>> _names(
        Map<String, List<({String name, String id})>> m) =>
    m.map((k, v) => MapEntry(k, v.map((t) => t.name).toList()));

final struggledTopicNamesBySubjectProvider = Provider<Map<String, List<String>>>(
    (ref) => _names(ref.watch(struggledTopicsBySubjectProvider)));

final repeatedStruggleTopicNamesBySubjectProvider =
    Provider<Map<String, List<String>>>(
        (ref) => _names(ref.watch(repeatedStruggleTopicsBySubjectProvider)));

/// TEK KAYNAK (Bölüm 1) — her konu için TEK bir [TopicEvidence]. Home/Stats/
/// Coach/PlanBuilder'ın zaten kullandığı AYNI ham sinyallerden
/// ([currentWeakTopicIdSetProvider], [resolvedWeakTopicIdSetProvider] —
/// deneme_provider.dart) türer; ayrı bir rozet mantığı İCAT EDİLMEZ. Ayrı bir
/// dosyada durur (topic_provider.dart DEĞİL) çünkü deneme_provider.dart zaten
/// topic_provider.dart'a bağımlı — döngüsel import olmasın diye burada
/// birleştirilir (bkz. goal_gap_provider.dart ile aynı desen).
final topicEvidenceProvider = Provider<Map<String, TopicEvidence>>((ref) {
  ref.watch(dayRolloverProvider);
  final topics = ref.watch(topicProvider);
  final weakIds = ref.watch(currentWeakTopicIdSetProvider);
  final resolvedIds = ref.watch(resolvedWeakTopicIdSetProvider);
  final difficulty = ref.watch(topicDifficultyProvider);
  final now = DateTime.now();

  return {
    for (final t in topics)
      t.id: TopicEvidenceEngine.classify(
        isExamWeak: weakIds.contains(t.id),
        isRecentlyResolved: resolvedIds.contains(t.id),
        difficulty: difficulty[t.id] ?? DifficultySignal.none,
        status: t.status,
        updatedAt: t.updatedAt,
        now: now,
      ),
  };
});
