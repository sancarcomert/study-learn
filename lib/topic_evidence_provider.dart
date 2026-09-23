import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deneme_provider.dart';
import 'topic_evidence.dart';
import 'topic_provider.dart';

/// TEK KAYNAK (Bölüm 1) — her konu için TEK bir [TopicEvidence]. Home/Stats/
/// Coach/PlanBuilder'ın zaten kullandığı AYNI ham sinyallerden
/// ([currentWeakTopicIdSetProvider], [resolvedWeakTopicIdSetProvider] —
/// deneme_provider.dart) türer; ayrı bir rozet mantığı İCAT EDİLMEZ. Ayrı bir
/// dosyada durur (topic_provider.dart DEĞİL) çünkü deneme_provider.dart zaten
/// topic_provider.dart'a bağımlı — döngüsel import olmasın diye burada
/// birleştirilir (bkz. goal_gap_provider.dart ile aynı desen).
final topicEvidenceProvider = Provider<Map<String, TopicEvidence>>((ref) {
  final topics = ref.watch(topicProvider);
  final weakIds = ref.watch(currentWeakTopicIdSetProvider);
  final resolvedIds = ref.watch(resolvedWeakTopicIdSetProvider);
  final now = DateTime.now();

  return {
    for (final t in topics)
      t.id: TopicEvidenceEngine.classify(
        isExamWeak: weakIds.contains(t.id),
        isRecentlyResolved: resolvedIds.contains(t.id),
        status: t.status,
        updatedAt: t.updatedAt,
        now: now,
      ),
  };
});
