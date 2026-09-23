import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/deneme_change_engine.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/goal_gap_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/stats_provider.dart';
import 'package:study_planner/study_advisor.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/stats_insight_engine.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/topic_evidence.dart';
import 'package:study_planner/topic_evidence_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';
import 'package:study_planner/user_stats_model.dart';

/// Faz 9 — DENEME → ZAYIFLIK → HEDEF FARKI → ADVISOR → PLAN döngüsünü UÇTAN
/// UCA, gerçek Hive/Riverpod ile izler. Yalnız sınıfların teknik olarak
/// bağlı olduğunu değil, GERÇEKTEN farklı bir davranış ürettiğini kanıtlar:
///
/// Hedef: TYT 70
/// Deneme 1: 64 net, Matematik'te Türev zayıf → gap=6, Matematik advisor'da
///           "denemede yanlış yapmıştın" gerekçesiyle öne çıkar.
/// Deneme 2: 67 net, Türev artık zayıf değil → gap=3 (6'dan indi), Türev
///           "iyileşme" olarak işaretlenir, Matematik'in advisor gerekçesi
///           ARTIK "denemede yanlış yapmıştın" DEĞİLDİR (çünkü kanıt kalktı).
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_loop_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(SubjectModelAdapter());
    Hive.registerAdapter(TopicStatusAdapter());
    Hive.registerAdapter(TopicModelAdapter());
    Hive.registerAdapter(DenemeSectionScoreAdapter());
    Hive.registerAdapter(DenemeEntryAdapter());
    Hive.registerAdapter(UserStatsModelAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.openBox<SubjectModel>(HiveBoxes.subjectsBoxName);
    await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName);
    await Hive.openBox<DenemeEntry>(HiveBoxes.denemelerBoxName);
    await Hive.openBox<UserStatsModel>(HiveBoxes.statsBoxName);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveBoxes.subjectsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.topicsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.denemelerBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.statsBoxName);
  });

  test(
      'GOAL → DENEME → GAP → ADVISOR → STUDY → RE-EVALUATION → ROZET → STATS '
      'uçtan uca gerçekten değişir (Faz 9 / Bölüm 4)', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    // --- GOAL: TYT hedefi 70 ---
    c.read(statsProvider.notifier).setTargetNet('TYT', 70);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    c.read(subjectProvider.notifier).addSubject('Fizik', 0);
    final subjects = c.read(subjectProvider);
    final matId = subjects.firstWhere((s) => s.name == 'Matematik').id;

    c.read(topicProvider.notifier).addTopic(matId, 'Türev');
    final turevId = c
        .read(topicProvider)
        .firstWhere((t) => t.subjectId == matId && t.name == 'Türev')
        .id;

    final denemeNotifier = c.read(denemeProvider.notifier);

    // --- DENEME 1: CURRENT STATE = 64, Türev zayıf ---
    denemeNotifier.addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 1),
      sections: [
        DenemeSectionScore(
          subject: 'Matematik',
          correct: 16,
          wrong: 0,
          weakTopicIds: [turevId],
        ),
        DenemeSectionScore(subject: 'Türkçe', correct: 48, wrong: 0),
      ],
    );

    // GAP: 70 - 64 = 6.
    final gap1 = c.read(primaryGoalGapProvider);
    expect(gap1, isNotNull);
    expect(gap1!.gap, 6);

    // Matematik'in GERÇEK deneme kanıtı var.
    expect(
      c.read(examWeakTopicNamesBySubjectProvider)[matId],
      contains('Türev'),
    );

    // Advisor bu kanıtı Matematik'i öne çıkarmak için kullanır.
    final tasks = <TaskModel>[];
    final advisor1 = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      examWeakTopicsBySubject: c.read(examWeakTopicNamesBySubjectProvider),
      goalGapAmplifier: c.read(goalGapAmplifierProvider),
    );
    expect(advisor1.first.subjectId, matId);
    expect(advisor1.first.reason, contains('denemede yanlış yapmıştın'));

    // TOPIC EVIDENCE ROZETİ — Konu Takip'te Türev satırı OTOMATİK
    // "Zayıf — denemeden doğrulandı" gösterir, öğrenci hiçbir yerde elle
    // bir "zayıf" bayrağı işaretlemedi.
    expect(
      c.read(topicEvidenceProvider)[turevId]?.state,
      TopicEvidenceState.weakConfirmed,
    );

    // --- STUDY: öğrenci Türev'i çalışır (konu durumu ilerler) ---
    c.read(topicProvider.notifier).setStatus(turevId, TopicStatus.studied);
    expect(
      c.read(topicProvider).firstWhere((t) => t.id == turevId).status,
      TopicStatus.studied,
    );

    // --- DENEME 2 (RESULT): net 67'ye çıktı, Türev artık zayıf değil ---
    denemeNotifier.addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 15),
      sections: [
        DenemeSectionScore(
          subject: 'Matematik',
          correct: 18,
          wrong: 0,
          weakTopicIds: const [], // artık zayıf değil
        ),
        DenemeSectionScore(subject: 'Türkçe', correct: 49, wrong: 0),
      ],
    );

    // UPDATED GAP: 70 - 67 = 3, önceki denemeye göre 3 net kapandı.
    final gap2 = c.read(primaryGoalGapProvider);
    expect(gap2!.gap, 3);
    expect(gap2.gapChange, 3);

    // RE-EVALUATION cümlesi — GoalGap değişimini yakalar.
    final summary = DenemeChangeEngine.summarize(goalGap: gap2);
    expect(summary, contains('6'));
    expect(summary, contains('3'));

    // İYİLEŞME ANI — Türev artık zayıf konu listesinde değil.
    expect(
      c.read(resolvedWeakTopicsBySubjectProvider)[matId],
      contains('Türev'),
    );

    // Matematik'in artık GERÇEK bir deneme kanıtı YOK.
    expect(
      c.read(examWeakTopicNamesBySubjectProvider)[matId],
      isNull,
    );

    // DAVRANIŞ GERÇEKTEN DEĞİŞTİ: advisor artık Matematik'i "denemede
    // yanlış yapmıştın" gerekçesiyle önermiyor (kanıt kalktı).
    final advisor2 = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      examWeakTopicsBySubject: c.read(examWeakTopicNamesBySubjectProvider),
      goalGapAmplifier: c.read(goalGapAmplifierProvider),
    );
    final matSuggestion2 =
        advisor2.where((s) => s.subjectId == matId).firstOrNull;
    if (matSuggestion2 != null) {
      expect(matSuggestion2.reason, isNot(contains('denemede yanlış yapmıştın')));
    }

    // TOPIC EVIDENCE ROZETİ OTOMATİK GÜNCELLENDİ — öğrenci Konu Takip'e
    // gidip Türev'i elle "artık zayıf değil" diye işaretlemedi; rozet
    // SADECE yeni denemeyle kendiliğinden "Düzeliyor"ya döndü (Bölüm 1 +
    // Faz 4 madde 10 — çift/manuel durum bakımı yok).
    expect(
      c.read(topicEvidenceProvider)[turevId]?.state,
      TopicEvidenceState.improving,
    );

    // STATS/COACH DA AYNI DURUMU YANSITIYOR — ikinci bir hesap icat
    // edilmeden, aynı resolvedWeakTopicsBySubjectProvider'dan.
    final insights = StatsInsightEngine.build(
      tasksThisWeek: 0,
      tasksLastWeek: 0,
      focusMinutesThisWeek: 0,
      focusMinutesLastWeek: 0,
      goalGap: gap2,
      resolvedWeakTopicsBySubject: c.read(resolvedWeakTopicsBySubjectProvider),
    );
    expect(insights.any((i) => i.body.contains('Türev')), isTrue);
  });
}
