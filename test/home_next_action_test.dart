import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/home_screen.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/study_events.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// Home'un asıl sözü: "şimdi ne yapmalıyım, neden, ne kadar, sonra ne olacak" —
/// ilk günden itibaren; ve dokununca bağlamın (gerekçe dahil) Focus'a KAYBOLMADAN
/// taşınması. Gerçek Home + gerçek Focus, gerçek provider'lar.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  final today = DateTime.now();

  Future<ProviderContainer> pumpHome(
    WidgetTester tester, {
    List<TaskModel> tasks = const [],
    List<TopicModel> topics = const [],
    List<DenemeEntry> denemeler = const [],
    List<FocusSession> sessions = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Bildirim/carry-over diyalogları ve platform çağrıları bu senaryoda
    // devreye girmesin: stats bilerek "hepsini görmüş / hedef 0".
    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        dailyGoal: 0,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        lastCarryOverPromptDate: DateTime.now(),
      ),
    );
    await HiveBoxes.subjects.put(
      's-mat',
      SubjectModel(
        id: 's-mat',
        name: 'Matematik',
        colorValue: 0xFF6750A4,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    for (final t in topics) {
      await HiveBoxes.topics.put(t.id, t);
    }
    for (final t in tasks) {
      await HiveBoxes.tasks.put(t.id, t);
    }
    for (final d in denemeler) {
      await HiveBoxes.denemeler.put(d.id, d);
    }
    for (final s in sessions) {
      await HiveBoxes.focusSessions.put(s.id, s);
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  TaskModel task(
    String title, {
    String? sourceReason,
    String? topicId,
    int? minutes,
    DateTime? scheduled,
  }) =>
      TaskModel(
        id: 'task-$title',
        title: title,
        subjectId: 's-mat',
        dueDate: DateTime(today.year, today.month, today.day),
        createdAt: DateTime(2026, 9, 1),
        estimatedMinutes: minutes,
        sourceReason: sourceReason,
        topicId: topicId,
        scheduledTime: scheduled,
      );

  TopicModel topic(String id, String name) => TopicModel(
        id: id,
        subjectId: 's-mat',
        name: name,
        createdAt: DateTime(2026, 9, 1),
      );

  FocusSession hardRun(String id, String topicId, Duration ago) => FocusSession(
        id: id,
        endedAt: DateTime.now().subtract(ago),
        minutes: 25,
        mode: 'serbest',
        subjectId: 's-mat',
        topicId: topicId,
        runId: 'run-$id',
        feeling: FocusFeeling.hard,
      );

  testWidgets(
      'YOLCULUK A: yeni öğrenci — saatsiz ilk görev Home\'da "Bugünün Odağı", '
      '"plan yok" DENMEZ', (tester) async {
    await pumpHome(tester, tasks: [task('Matematik: ilk çalışma', minutes: 25)]);

    expect(find.text('Matematik: ilk çalışma'), findsOneWidget);
    expect(find.text('Matematik · 25 dk'), findsOneWidget);
    expect(find.textContaining('0/1 görevi tamamladın'), findsOneWidget);
    expect(find.text('Bugün için plan yok'), findsNothing);
    expect(find.textContaining('Bir görev planlamadın'), findsNothing);
  });

  testWidgets('Coach planından gelen görev: gerekçesi kartta görünür',
      (tester) async {
    await pumpHome(tester, tasks: [
      task('Matematik: Türev (tekrar)',
          minutes: 45,
          sourceReason: 'Son denemende "Türev" konusundan yanlış yapmıştın.'),
    ]);

    expect(find.text('Matematik: Türev (tekrar)'), findsOneWidget);
    expect(find.text('Son denemende "Türev" konusundan yanlış yapmıştın.'),
        findsOneWidget);
  });

  testWidgets('kart "sonra ne var"ı söyler (bu bitince sırada ne?)',
      (tester) async {
    await pumpHome(tester, tasks: [
      task('Birinci', minutes: 20, sourceReason: 'x'),
      task('İkinci', minutes: 20),
    ]);
    expect(find.text('Sonra: İkinci'), findsOneWidget);
  });

  testWidgets(
      'öğrenci konuda "zorlandım" dediyse kart bunu CANLI gösterir '
      '(gerekçe planlanırken yazılmamış olsa bile)', (tester) async {
    await pumpHome(
      tester,
      tasks: [task('Matematik: Bölünebilme', topicId: 't-b', minutes: 25)],
      topics: [topic('t-b', 'Bölünebilme')],
      sessions: [hardRun('f1', 't-b', const Duration(hours: 20))],
    );

    expect(find.text('Matematik · Bölünebilme · 25 dk'), findsOneWidget);
    // TEK cevap: rozet/hatırlatma cümlesi (konu "zayıf" ilan edilmiyor).
    expect(find.text('Son çalışmanda burada zorlandın.'), findsOneWidget);
  });

  testWidgets('Bugün Kalanlar: saatsiz görevler de listelenir, kart görevi tekrarlanmaz',
      (tester) async {
    await pumpHome(tester, tasks: [
      task('Birinci', minutes: 20),
      task('İkinci', minutes: 20),
    ]);
    expect(find.text('Birinci'), findsOneWidget);
    expect(find.text('İkinci'), findsWidgets);
    expect(find.text('Bugün Kalanlar'), findsOneWidget);
    expect(find.text('1 görev'), findsOneWidget);
  });

  testWidgets(
      'YOLCULUK B: denemede yanlış konu → Home önerir → dokun → Focus AYNI gerekçeyi '
      've konuyu gösterir (bağlam kaybolmaz)', (tester) async {
    await pumpHome(
      tester,
      topics: [topic('t-turev', 'Türev')],
      denemeler: [
        DenemeEntry(
          id: 'd1',
          examType: 'TYT',
          date: DateTime.now().subtract(const Duration(days: 2)),
          sections: [
            DenemeSectionScore(
                subject: 'Matematik',
                correct: 20,
                wrong: 10,
                weakTopicIds: ['t-turev']),
          ],
        ),
      ],
    );

    // Home: konu başlık, ders meta, somut gerekçe.
    const reason = '"Türev" konusunda denemede yanlış yapmıştın';
    expect(find.text('Türev'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);

    // Dokun → Focus: aynı gerekçe + konu, ders/konu seçili.
    await tester.tap(find.text(reason));
    await tester.pumpAndSettle();
    expect(find.text('ODAK SEANSI'), findsOneWidget);
    expect(find.text(reason), findsOneWidget,
        reason: 'öneri gerekçesi Focus\'ta kaybolmamalı');
    expect(find.text('Matematik · 25 dk'), findsOneWidget);
    // Focus'a açılırken durum DEĞİŞMEDİ (niyet ≠ kanıt).
    // (container üzerinden aşağıda ayrıca doğrulanıyor)
  });

  testWidgets(
      'YOLCULUK E (domain): Home önerisi → Focus açılır (niyet ≠ kanıt) → ölçülmüş '
      'çalışma + "zorlandım" → konu TEK adım ilerler (arayüz akışı: '
      'focus_finish_flow_test)', (tester) async {
    // Doğrulanmış (üst üste) zorlanma: öneri konuyu adıyla, somut gerekçeyle söyler.
    final c = await pumpHome(
      tester,
      topics: [topic('t-b', 'Bölünebilme')],
      sessions: [
        hardRun('f1', 't-b', const Duration(days: 3)),
        hardRun('f2', 't-b', const Duration(days: 1)),
      ],
    );
    const reason = '"Bölünebilme" konusunda üst üste zorlandığını söyledin';
    expect(find.text(reason), findsOneWidget);

    await tester.tap(find.text(reason));
    await tester.pumpAndSettle();
    expect(find.text('ODAK SEANSI'), findsOneWidget);
    expect(find.text(reason), findsOneWidget);
    expect(find.text('Başlat'), findsOneWidget);

    // Niyet ≠ kanıt: Focus açıldı ama hiçbir çalışma kaydı/durum değişimi yok.
    expect(c.read(topicProvider).single.status, TopicStatus.notStarted);
    expect(c.read(focusSessionProvider).length, 2); // yalnız fixture

    // "Ölçülmüş 15 dk çalışma" (çapa yerine olay servisi — aynı kapı).
    final events = c.read(studyEventsProvider);
    final runId = events.newRunId();
    events.recordFocusActivity(
      runId: runId,
      minutes: 15,
      mode: 'serbest',
      subjectId: 's-mat',
      topicId: 't-b',
    );
    await events.finishFocusRun(
        runId: runId, topicId: 't-b', feeling: FocusFeeling.hard);
    await tester.pump();

    // Konu tek çalışmayla "çalışıldı", zorlanma üç kez doğrulandı.
    expect(c.read(topicProvider).single.status, TopicStatus.studied);
    expect(c.read(taskProvider), isEmpty);
  });
}
