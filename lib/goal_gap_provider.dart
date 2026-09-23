import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'deneme_provider.dart';
import 'goal_gap_engine.dart';
import 'stats_provider.dart';

/// [examType] ("TYT"/"AYT") için ham hedef/net/sınav-tarihi verisini Hive'dan
/// çıkarıp [GoalGapEngine.compute]'a besler. Tek bu dosya Hive'a dokunur —
/// StudyAdvisor/Stats/Coach/Home hepsi AŞAĞIDAKİ provider'lardan okur, kendi
/// hesabını İCAT ETMEZ (bkz. PHASE 7'deki "tek doğruluk kaynağı" kuralı).
GoalGap _computeGap(Ref ref, String examType) {
  final stats = ref.watch(statsProvider);
  final target = examType == 'TYT' ? stats.targetNetTYT : stats.targetNetAYT;
  // denemeByTypeProvider tarihe göre ARTAN sıralı (bkz. deneme_provider.dart)
  // — son eleman en güncel, ondan önceki eleman "bir önceki deneme".
  final entries = ref.watch(denemeByTypeProvider(examType));
  final currentNet = entries.isEmpty ? null : entries.last.totalNet;
  final previousNet =
      entries.length >= 2 ? entries[entries.length - 2].totalNet : null;
  return GoalGapEngine.compute(
    examType: examType,
    target: target,
    currentNet: currentNet,
    previousNet: previousNet,
    examDate: stats.examDate,
  );
}

final tytGoalGapProvider = Provider<GoalGap>((ref) => _computeGap(ref, 'TYT'));
final aytGoalGapProvider = Provider<GoalGap>((ref) => _computeGap(ref, 'AYT'));

/// GOAL → GAP zincirinin tek kaynağı — Home/Stats/Coach/StudyAdvisor hepsi
/// BURADAN okur (bkz. GoalGapEngine.primary). Hiçbir hedef girilmemişse null.
final primaryGoalGapProvider = Provider<GoalGap?>((ref) {
  final tyt = ref.watch(tytGoalGapProvider);
  final ayt = ref.watch(aytGoalGapProvider);
  final gradeLevel = ref.watch(statsProvider).gradeLevel;
  return GoalGapEngine.primary(tyt, ayt, gradeLevel: gradeLevel);
});

/// StudyAdvisor'a geçilen 0..1 bağlamsal çarpan — bkz.
/// GoalGapEngine.priorityAmplifier'daki not (gerçek zayıflık kanıtı yoksa
/// hiçbir etkisi olmaz).
final goalGapAmplifierProvider = Provider<double>((ref) {
  return GoalGapEngine.priorityAmplifier(ref.watch(primaryGoalGapProvider));
});
