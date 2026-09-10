import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'rank_system.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'topic_provider.dart';

/// Kullanıcının güncel rütbesi — mevcut sağlayıcılardan **türetilir**,
/// kendi durumu yoktur. Girdi değişince (görev tamamlandı, hedef tutturuldu,
/// konu işaretlendi) otomatik yeniden hesaplanır.
final rankProvider = Provider<RankInfo>((ref) {
  // "Günü bitirme" = günlük hedefin tutturulduğu gün sayısı.
  // UserStatsModel.totalCompletedTasks bu sayacı tutuyor (markGoalCompletedToday
  // her gün bir kez artırır) — isim yanıltıcı ama içerik bu.
  final goalDays = ref.watch(statsProvider).totalCompletedTasks;

  final completedTasks =
      ref.watch(taskProvider).where((t) => t.isCompleted).length;

  final coveredTopics = ref
      .watch(coverageBySubjectProvider)
      .values
      .fold<int>(0, (sum, c) => sum + c.covered);

  return RankSystem.compute(
    completedTasks: completedTasks,
    goalDays: goalDays,
    coveredTopics: coveredTopics,
  );
});
