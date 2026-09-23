import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/plan_builder.dart';
import 'package:study_planner/study_advisor.dart';
import 'package:study_planner/study_events.dart';
import 'package:study_planner/study_recommendation.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_evidence.dart';
import 'package:study_planner/topic_evidence_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';

import 'support/hive_memory.dart';

/// Focus → "nasıl geçti" → yorum → uyarlanma. Bir cevap hiçbir şeyi
/// değiştirmiyorsa sahtedir; burada gerçek provider'larla cevabın rozeti,
/// öneriyi ve planı nasıl değiştirdiği — ve TEK bir cevabın konuyu "zayıf"
/// ilan ETMEDİĞİ — doğrulanır.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  ({ProviderContainer c, String subjectId, String topicId}) setup() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Bölünebilme');
    return (c: c, subjectId: subjectId, topicId: c.read(topicProvider).first.id);
  }

  /// Bir Focus çalışması yapıp bitirir; cevabı [feeling]. Saatin ilerlemesi
  /// için çağıran taraf araya bekleme koyar.
  Future<String> study(
    ({ProviderContainer c, String subjectId, String topicId}) t, {
    int? feeling,
    int minutes = 25,
  }) async {
    final events = t.c.read(studyEventsProvider);
    final runId = events.newRunId();
    events.recordFocusActivity(
      runId: runId,
      minutes: minutes,
      mode: 'serbest',
      subjectId: t.subjectId,
      topicId: t.topicId,
    );
    await events.finishFocusRun(
        runId: runId, topicId: t.topicId, feeling: feeling);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    return runId;
  }

  DifficultySignal signalOf(ProviderContainer c, String topicId) =>
      c.read(topicDifficultyProvider)[topicId] ?? DifficultySignal.none;

  test('cevap çalışmaya (tüm dilimlerine) yazılır; verilmeyen cevap null kalır',
      () async {
    final t = setup();
    final events = t.c.read(studyEventsProvider);
    final runId = events.newRunId();
    for (var i = 0; i < 3; i++) {
      events.recordFocusActivity(
          runId: runId,
          minutes: 25,
          mode: 'pomodoro',
          subjectId: t.subjectId,
          topicId: t.topicId);
    }
    expect(t.c.read(focusSessionProvider).every((s) => s.feeling == null), isTrue,
        reason: 'cevap verilmedi: "iyi geçti" DEĞİL, bilinmiyor');

    await events.finishFocusRun(
        runId: runId, topicId: t.topicId, feeling: FocusFeeling.hard);
    final all = t.c.read(focusSessionProvider);
    expect(all.length, 3);
    expect(all.every((s) => s.feeling == FocusFeeling.hard), isTrue);
  });

  test('TEK "zorlandım": hafif sinyal — rozet + hatırlatma, konu "zayıf" DEĞİL',
      () async {
    final t = setup();
    await study(t, feeling: FocusFeeling.hard);

    expect(signalOf(t.c, t.topicId), DifficultySignal.recent);
    final e = t.c.read(topicEvidenceProvider)[t.topicId]!;
    expect(e.state, TopicEvidenceState.struggling);
    expect(e.label, 'Son çalışmanda zorlandın');
    expect(e.label, isNot(contains('Zayıf')));

    // Öneri motoru: hafif bir dürtme, ağır bir sonuç değil.
    final done = TaskModel(
      id: 'y',
      title: 'eski',
      subjectId: t.subjectId,
      dueDate: DateTime.now().subtract(const Duration(days: 10)),
      isCompleted: true,
      createdAt: DateTime(2026, 1, 1),
    );
    final subjects = t.c.read(subjectProvider);
    final base = StudyAdvisor.suggest(
        subjects: subjects, tasks: [done], now: DateTime.now()).single;
    final recent = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: [done],
      now: DateTime.now(),
      struggledTopicsBySubject: t.c.read(struggledTopicNamesBySubjectProvider),
    ).single;
    expect(recent.reason, contains('zorlandığını söylemiştin'));
    expect(recent.topicName, 'Bölünebilme');
    expect(recent.score - base.score, closeTo(0.08, 0.001));
  });

  test('ART ARDA iki "zorlandım": doğrulanmış sinyal — daha ağır puan, somut gerekçe, plana girer',
      () async {
    final t = setup();
    await study(t, feeling: FocusFeeling.hard);
    await study(t, feeling: FocusFeeling.hard);

    expect(signalOf(t.c, t.topicId), DifficultySignal.repeated);
    final e = t.c.read(topicEvidenceProvider)[t.topicId]!;
    expect(e.state, TopicEvidenceState.strugglingRepeatedly);
    expect(e.sentence, 'Bu konuda üst üste zorlandığını söyledin.');

    final done = TaskModel(
      id: 'y',
      title: 'dün',
      subjectId: t.subjectId,
      dueDate: DateTime.now().subtract(const Duration(days: 1)),
      isCompleted: true,
      createdAt: DateTime(2026, 1, 1),
    );
    final rec = runStudyAdvisor(
      t.c.read,
      limit: 1,
    );
    // taskProvider'da görev yok → runner boş görev listesiyle çalışır; gerekçe
    // yine de doğrulanmış zorlanmayı söyler (kapsama vb. daha önce gelmez).
    expect(rec.single.topicName, 'Bölünebilme');
    expect(rec.single.reason, contains('üst üste zorlandığını'));

    // ...ve öneriyi Focus'a TAŞINABİLİR bir niyete çevirir (gerekçe + konu id).
    final intent = intentForSuggestion(t.c.read, rec.single);
    expect(intent.topicId, t.topicId);
    expect(intent.subjectId, t.subjectId);
    expect(intent.reason, contains('üst üste'));
    expect(done.isCompleted, isTrue); // (fixture sanity)
  });

  test('davranışsal kanıt birleşince tek cevap da "doğrulanmış" olur '
      '(zorlandım + gerçek süre tahminin çok üstünde)', () async {
    final t = setup();
    final task = t.c.read(taskProvider.notifier).addTask(
          title: 'Bölünebilme',
          subjectId: t.subjectId,
          dueDate: DateTime.now(),
          estimatedMinutes: 20,
          topicId: t.topicId,
        );
    final events = t.c.read(studyEventsProvider);
    final runId = events.newRunId();
    events.recordFocusActivity(
      runId: runId,
      minutes: 40, // tahminin 2 katı
      mode: 'serbest',
      subjectId: t.subjectId,
      topicId: t.topicId,
      taskId: task.id,
    );
    await events.finishFocusRun(
      runId: runId,
      topicId: t.topicId,
      taskId: task.id,
      feeling: FocusFeeling.hard,
      completeTask: true,
    );
    expect(t.c.read(overranTopicIdsProvider), {t.topicId});
    expect(signalOf(t.c, t.topicId), DifficultySignal.repeated);
  });

  test('sonraki "normaldi/iyi gitti" sinyali temizler; cevapsız çalışma temizlemez',
      () async {
    final t = setup();
    await study(t, feeling: FocusFeeling.hard);
    await study(t); // cevap verilmedi (Şimdilik geç)
    expect(signalOf(t.c, t.topicId), DifficultySignal.recent);

    await study(t, feeling: FocusFeeling.ok);
    expect(signalOf(t.c, t.topicId), DifficultySignal.none);
    expect(t.c.read(topicEvidenceProvider)[t.topicId]!.hasBadge, isFalse);
  });

  test('sonuç mesajı verisi: zorlanma "üst üste"ye dönüştü mü / kalktı mı',
      () async {
    final t = setup();
    final events = t.c.read(studyEventsProvider);

    var runId = events.newRunId();
    events.recordFocusActivity(
        runId: runId,
        minutes: 20,
        mode: 'serbest',
        subjectId: t.subjectId,
        topicId: t.topicId);
    var r = await events.finishFocusRun(
        runId: runId, topicId: t.topicId, feeling: FocusFeeling.hard);
    expect(r.difficultyBefore, DifficultySignal.none);
    expect(r.difficultyAfter, DifficultySignal.recent);

    await Future<void>.delayed(const Duration(milliseconds: 15));
    runId = events.newRunId();
    events.recordFocusActivity(
        runId: runId,
        minutes: 20,
        mode: 'serbest',
        subjectId: t.subjectId,
        topicId: t.topicId);
    r = await events.finishFocusRun(
        runId: runId, topicId: t.topicId, feeling: FocusFeeling.hard);
    expect(r.difficultyAfter, DifficultySignal.repeated);

    await Future<void>.delayed(const Duration(milliseconds: 15));
    runId = events.newRunId();
    events.recordFocusActivity(
        runId: runId,
        minutes: 20,
        mode: 'serbest',
        subjectId: t.subjectId,
        topicId: t.topicId);
    r = await events.finishFocusRun(
        runId: runId, topicId: t.topicId, feeling: FocusFeeling.great);
    expect(r.difficultyBefore, DifficultySignal.repeated);
    expect(r.difficultyAfter, DifficultySignal.none);
  });

  group('TopicEvidenceEngine.difficultySignals (saf)', () {
    final now = DateTime(2026, 9, 20, 12);
    FocusSession s(String topic, int? feeling, DateTime at,
            {String? runId}) =>
        FocusSession(
          id: '$topic-$at-$runId',
          endedAt: at,
          minutes: 25,
          mode: 'serbest',
          subjectId: 'sub',
          topicId: topic,
          feeling: feeling,
          runId: runId,
        );
    final d1 = now.subtract(const Duration(days: 1));
    final d2 = now.subtract(const Duration(days: 2));

    test('14 günden eski "zorlandım" artık güncel değil', () {
      expect(
        TopicEvidenceEngine.difficultySignals(
          [s('a', FocusFeeling.hard, now.subtract(const Duration(days: 15)))],
          now: now,
        ),
        isEmpty,
      );
    });

    test('konusuz seans hiçbir konuyu etkilemez', () {
      expect(
        TopicEvidenceEngine.difficultySignals([
          FocusSession(
            id: 'x',
            endedAt: now,
            minutes: 25,
            mode: 'serbest',
            feeling: FocusFeeling.hard,
          ),
        ], now: now),
        isEmpty,
      );
    });

    test('bir çalışma = bir oy: aynı çalışmanın 3 bloğu "üst üste" sayılmaz', () {
      final out = TopicEvidenceEngine.difficultySignals([
        s('a', FocusFeeling.hard, d1, runId: 'r1'),
        s('a', FocusFeeling.hard, d1.add(const Duration(minutes: 30)),
            runId: 'r1'),
        s('a', FocusFeeling.hard, d1.add(const Duration(minutes: 60)),
            runId: 'r1'),
      ], now: now);
      expect(out['a'], DifficultySignal.recent);
    });

    test('iki AYRI çalışma "zorlandım" → repeated', () {
      final out = TopicEvidenceEngine.difficultySignals([
        s('a', FocusFeeling.hard, d2, runId: 'r1'),
        s('a', FocusFeeling.hard, d1, runId: 'r2'),
      ], now: now);
      expect(out['a'], DifficultySignal.repeated);
    });

    test('araya giren "iyi gitti" zinciri koparır', () {
      final out = TopicEvidenceEngine.difficultySignals([
        s('a', FocusFeeling.hard, now.subtract(const Duration(days: 3)),
            runId: 'r1'),
        s('a', FocusFeeling.great, d2, runId: 'r2'),
        s('a', FocusFeeling.hard, d1, runId: 'r3'),
      ], now: now);
      expect(out['a'], DifficultySignal.recent);
    });

    test('her konu kendi son cevabına göre değerlendirilir', () {
      final out = TopicEvidenceEngine.difficultySignals([
        s('a', FocusFeeling.hard, d2, runId: 'r1'),
        s('a', FocusFeeling.great, d1, runId: 'r2'),
        s('b', FocusFeeling.ok, d2, runId: 'r3'),
        s('b', FocusFeeling.hard, d1, runId: 'r4'),
      ], now: now);
      expect(out.containsKey('a'), isFalse);
      expect(out['b'], DifficultySignal.recent);
    });
  });

  group('rozet önceliği', () {
    test('deneme kanıtı, çalışmadaki zorlanmayı ezer', () {
      final e = TopicEvidenceEngine.classify(
        isExamWeak: true,
        isRecentlyResolved: false,
        difficulty: DifficultySignal.repeated,
        status: TopicStatus.studied,
        updatedAt: null,
      );
      expect(e.state, TopicEvidenceState.weakConfirmed);
    });

    test('zorlanma, "düzeliyor"dan önce gelir (seans daha taze olabilir)', () {
      final e = TopicEvidenceEngine.classify(
        isExamWeak: false,
        isRecentlyResolved: true,
        difficulty: DifficultySignal.recent,
        status: TopicStatus.studied,
        updatedAt: null,
      );
      expect(e.state, TopicEvidenceState.struggling);
    });

    test('kanıt yoksa cümle de yok (uydurma gerekçe üretilmez)', () {
      expect(TopicEvidence.none.sentence, isNull);
    });
  });

  group('StudyAdvisor önceliği', () {
    final now = DateTime(2026, 9, 10, 12);
    final sub = SubjectModel(
      id: 's1',
      name: 'Fizik',
      colorValue: 0,
      createdAt: DateTime(2026, 1, 1),
    );

    test('deneme kanıtı (examWeak) zorlanma gerekçesini ezer', () {
      final out = StudyAdvisor.suggest(
        subjects: [sub],
        tasks: const [],
        now: now,
        examWeakTopicsBySubject: {'s1': ['Vektörler']},
        repeatedStruggleTopicsBySubject: {'s1': ['Kuvvet']},
      ).single;
      expect(out.reason, contains('Vektörler'));
      expect(out.topicName, 'Vektörler');
    });

    test('kronik erteleme gerekçesinde konu adı taşınmaz', () {
      final avoided = TaskModel(
        id: 't',
        title: 'x',
        subjectId: 's1',
        dueDate: DateTime(2026, 9, 9),
        createdAt: DateTime(2026, 1, 1),
        postponeCount: 3,
      );
      final out = StudyAdvisor.suggest(
        subjects: [sub],
        tasks: [avoided],
        now: now,
        repeatedStruggleTopicsBySubject: {'s1': ['Kuvvet']},
      ).single;
      expect(out.reason, contains('ertelendi'));
      expect(out.topicName, isNull);
    });

    test('gerekçe ile eylem AYRIŞMAZ: konu adı yalnız gerekçe o konuyu anıyorsa döner',
        () {
      // Hiç görev yok → "Henüz hiç görev eklemedin" (genel), tek zorlanma bunu
      // ezmez — dolayısıyla öneri bir konuya işaret ETMEZ.
      final out = StudyAdvisor.suggest(
        subjects: [sub],
        tasks: const [],
        now: now,
        struggledTopicsBySubject: {'s1': ['Kuvvet']},
      ).single;
      expect(out.reason, 'Henüz hiç görev eklemedin');
      expect(out.topicName, isNull);
    });

    test('tek zorlanma hedef-açık çarpanını tetiklemez; doğrulanmış olan tetikler',
        () {
      final base = StudyAdvisor.suggest(
        subjects: [sub],
        tasks: const [],
        now: now,
        goalGapAmplifier: 1.0,
        struggledTopicsBySubject: {'s1': ['Kuvvet']},
      ).single.score;
      final noGap = StudyAdvisor.suggest(
        subjects: [sub],
        tasks: const [],
        now: now,
        struggledTopicsBySubject: {'s1': ['Kuvvet']},
      ).single.score;
      expect(base, noGap, reason: 'tek cevap gerçek zayıflık kanıtı değildir');

      final repeatedWithGap = StudyAdvisor.suggest(
        subjects: [sub],
        tasks: const [],
        now: now,
        goalGapAmplifier: 1.0,
        repeatedStruggleTopicsBySubject: {'s1': ['Kuvvet']},
      ).single.score;
      final repeatedNoGap = StudyAdvisor.suggest(
        subjects: [sub],
        tasks: const [],
        now: now,
        repeatedStruggleTopicsBySubject: {'s1': ['Kuvvet']},
      ).single.score;
      expect(repeatedWithGap, greaterThan(repeatedNoGap));
    });
  });

  group('PlanBuilder: doğrulanmış zorlanma plana girer', () {
    final sub = SubjectModel(
      id: 's1',
      name: 'Matematik',
      colorValue: 0,
      createdAt: DateTime(2026, 1, 1),
    );

    test('"(tekrar)" bloğu + öğrencinin kendi kanıtına dayalı gerçek gerekçe', () {
      final result = PlanBuilder.build(
        orderedSubjects: [sub],
        capacityMinutes: 60,
        energy: 'orta',
        struggledTopics: {
          's1': [
            (
              name: 'Bölünebilme',
              id: 't1',
              reason: '"Bölünebilme" konusunda üst üste zorlandığını söyledin.'
            ),
          ],
        },
      );
      final block = result.blocks.single;
      expect(block.title, 'Matematik: Bölünebilme (tekrar)');
      expect(block.topicId, 't1');
      expect(block.reason, contains('üst üste zorlandığını'));
      expect(result.reason, contains('Üst üste zorlandığını söylediğin'));
    });

    test('haftalık plan da aynı havuzu kullanır (gerçek gerekçeyle)', () {
      final week = PlanBuilder.buildWeek(
        orderedSubjects: [sub],
        minutesPerDay: 45,
        startDate: DateTime(2026, 9, 23),
        days: 2,
        struggledTopics: {
          's1': [(name: 'Bölünebilme', id: 't1', reason: 'gerçek gerekçe')],
        },
      );
      final first = week.days.first.blocks.single;
      expect(first.title, 'Matematik: Bölünebilme (tekrar)');
      expect(first.topicId, 't1');
      expect(first.reason, 'gerçek gerekçe');
      expect(week.reason, contains('Üst üste zorlandığını söylediğin'));
    });

    test('deneme kanıtı olan konu önce planlanır (kanıt hiyerarşisi)', () {
      final result = PlanBuilder.build(
        orderedSubjects: [sub],
        capacityMinutes: 45,
        energy: 'orta',
        examWeakTopics: {
          's1': [(name: 'Türev', id: 't-exam')],
        },
        struggledTopics: {
          's1': [(name: 'Bölünebilme', id: 't1', reason: 'r')],
        },
      );
      expect(result.blocks.single.topicId, 't-exam');
    });
  });
}
