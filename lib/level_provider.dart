import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'level_system.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'topic_provider.dart';

/// Kullanıcının güncel seviyesi — mevcut sağlayıcılardan **türetilir**,
/// kendi durumu yoktur. Girdi değişince (görev tamamlandı, seri uzadı,
/// konu işaretlendi) otomatik yeniden hesaplanır.
final levelProvider = Provider<LevelInfo>((ref) {
  final longestStreak = ref.watch(statsProvider).longestStreak;

  final completedTasks =
      ref.watch(taskProvider).where((t) => t.isCompleted).length;

  final coveredTopics = ref
      .watch(coverageBySubjectProvider)
      .values
      .fold<int>(0, (sum, c) => sum + c.covered);

  return LevelSystem.compute(
    completedTasks: completedTasks,
    longestStreak: longestStreak,
    coveredTopics: coveredTopics,
  );
});
