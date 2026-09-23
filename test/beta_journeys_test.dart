import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/app.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/stats_screen.dart';
import 'package:study_planner/study_events.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_evidence.dart';
import 'package:study_planner/topic_evidence_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_progress.dart';
import 'package:study_planner/topic_provider.dart';
import 'package:study_planner/user_stats_model.dart';
import 'package:study_planner/widgets/activity_heatmap.dart';

import 'support/hive_memory.dart';

/// BETA YOLCULUKLARI — gerçek uygulama kökü (`StudyPlannerApp`), gerçek
/// ekranlar, gerçek provider'lar. Süre beklemek yerine çalışan seans çapa
/// (HiveBoxes.focusAnchor) üzerinden geri yüklenir.
void main() {
  Future<void> frames(WidgetTester tester, [int n = 5]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<ProviderContainer> pumpApp(WidgetTester tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const StudyPlannerApp(),
    ));
    // google_fonts yazı tiplerini asenkron yükler; yükleme bitmeden çizim
    // ilerlerse çerçeve "debugSize" iddiası verir (testlere özgü — gömülü
    // fontlarla üretimde yok). Yüklemenin bitmesini gerçek zamanda bekle.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 800)));
    await frames(tester);
    return container;
  }

  Future<void> seedOnboarded({
    bool withSubject = true,
    List<String> topics = const [],
  }) async {
    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        hasCompletedOnboarding: true,
        dailyGoal: 0,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        lastCarryOverPromptDate: DateTime.now(),
      ),
    );
    if (!withSubject) return;
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
      await HiveBoxes.topics.put(
        'tp-$t',
        TopicModel(
          id: 'tp-$t',
          subjectId: 's-mat',
          name: t,
          createdAt: DateTime(2026, 9, 1),
        ),
      );
    }
  }

  group('bellek kutularıyla', () {
    setUp(openMemoryBoxes);
    tearDown(closeMemoryBoxes);

    testWidgets(
        'YOLCULUK 1 — ilk kullanım: onboarding → Home → anlamlı ilk eylem → Focus → '
        'bitir → kanıt → Home (çıkmaz yok)', (tester) async {
      bigScreen(tester);
      final c = await pumpApp(tester);

      // Onboarding: ders seç, başla.
      expect(find.text('Hoş geldin'), findsOneWidget);
      await tester.tap(find.text('Matematik').first);
      await tester.pump();
      await tester.ensureVisible(find.text('Başlayalım'));
      await tester.tap(find.text('Başlayalım'));
      await frames(tester);

      // İzin diyaloğu (bir kez) — reddet, akış devam etsin.
      if (find.text('Hatırlatmalara izin ver').evaluate().isNotEmpty) {
        await tester.tap(find.text('Şimdi Değil'));
        await frames(tester);
      }

      // Home: anlamlı ilk eylem — "Örnek" değil, yapılabilir bir görev.
      expect(find.text('Matematik: ilk çalışma'), findsOneWidget);
      expect(find.text('Matematik · 25 dk'), findsOneWidget);
      expect(find.textContaining('Örnek'), findsNothing);
      final task = c.read(taskProvider).single;

      // Başlat → Focus (15 dk çalışılmış seans çapadan geri yüklenir).
      await HiveBoxes.focusAnchor.put('current', {
        'mode': 'free',
        'phase': 'work',
        'blockMin': 25,
        'pomoCycle': 1,
        'committedSec': 15 * 60,
        'loggedSec': 0,
        'segStartMs': DateTime.now().millisecondsSinceEpoch,
        'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
        'subjectId': task.subjectId,
        'topicId': null,
        'note': task.title,
        'runId': 'first-run',
        'taskId': task.id,
        'reason': null,
      });
      await tester.tap(find.text('Matematik: ilk çalışma'));
      await frames(tester);
      expect(find.text('ODAK SEANSI'), findsOneWidget);

      // Bitir → nasıl geçti → görevi tamamla.
      await tester.tap(find.text('Bitir'));
      await frames(tester);
      expect(find.text('15 dk çalıştın'), findsOneWidget);
      await tester.tap(find.text('Görevi tamamlandı say'));
      await tester.pump();
      await tester.tap(find.text('İyi gitti'));
      await frames(tester, 8);

      // Kanıt kalıcı ve tutarlı.
      final sessions = c.read(focusSessionProvider);
      expect(sessions.fold<int>(0, (a, s) => a + s.minutes), 15);
      expect(sessions.every((s) => s.feeling == FocusFeeling.great), isTrue);
      final done = c.read(taskProvider).single;
      expect(done.isCompleted, isTrue);
      expect(done.actualMinutes, 15);

      // Home'a dönüldü ve çıkmaz yok: plan tamam, Koç'a yol açık.
      // (Hedef kutlaması varsa kapat.)
      if (find.text('Günlük hedef tamamlandı!').evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(5, 5));
        await frames(tester);
      }
      expect(find.text('Bugünkü planın tamam'), findsOneWidget);
      expect(find.text('Bugün için plan yok'), findsNothing);
      // Focus'tan sonra Home gerçek sonucu söyler: ölçülen 15 dk, plan 25 dk.
      expect(find.text('15 dk çalıştın · plan 25 dk'), findsOneWidget);
    });

    testWidgets(
        'YOLCULUK 2 — zayıf konu: deneme → öneri → Home → gerekçe → Focus → çalışma → '
        'sonuç; çalışmak zayıflığı SİLMEZ, yeni deneme kanıtı değiştirir',
        (tester) async {
      bigScreen(tester);
      await seedOnboarded(topics: ['Türev', 'Limit']);
      final c = await pumpApp(tester);

      // Deneme: Türev zayıf.
      c.read(denemeProvider.notifier).addEntry(
        examType: 'TYT',
        date: DateTime.now().subtract(const Duration(days: 5)),
        sections: [
          DenemeSectionScore(
              subject: 'Matematik',
              correct: 20,
              wrong: 8,
              weakTopicIds: ['tp-Türev']),
        ],
      );
      await frames(tester);

      const reasonTurev = '"Türev" konusunda denemede yanlış yapmıştın';
      expect(find.text(reasonTurev), findsOneWidget);
      expect(find.text('Türev'), findsOneWidget);

      // Dokun → Focus aynı gerekçe/konu; 15 dk çalış, "İyi gitti".
      await HiveBoxes.focusAnchor.put('current', {
        'mode': 'free',
        'phase': 'work',
        'blockMin': 25,
        'pomoCycle': 1,
        'committedSec': 15 * 60,
        'loggedSec': 0,
        'segStartMs': DateTime.now().millisecondsSinceEpoch,
        'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
        'subjectId': 's-mat',
        'topicId': 'tp-Türev',
        'note': 'Türev',
        'runId': 'run-turev',
        'taskId': null,
        'reason': reasonTurev,
      });
      await tester.tap(find.text(reasonTurev));
      await frames(tester);
      expect(find.text(reasonTurev), findsOneWidget,
          reason: 'gerekçe Focus\'ta kaybolmadı');
      await tester.tap(find.text('Bitir'));
      await frames(tester);
      await tester.tap(find.text('İyi gitti'));
      await frames(tester, 8);

      // Sonuç: konu "çalışıldı" (etkinlik); AMA zayıflık denemeden geldiği için
      // çalışmak onu silmez — öneri hâlâ aynı, gerekçe hâlâ deneme.
      expect(c.read(topicProvider).firstWhere((t) => t.id == 'tp-Türev').status,
          TopicStatus.studied);
      expect(find.text(reasonTurev), findsOneWidget,
          reason: 'STUDIED ≠ IMPROVED: yalnız yeni bir deneme zayıflığı kaldırır');

      // Yeni deneme: Türev artık zayıf değil, Limit zayıf → gelecek öneri DEĞİŞİR.
      c.read(denemeProvider.notifier).addEntry(
        examType: 'TYT',
        date: DateTime.now(),
        sections: [
          DenemeSectionScore(
              subject: 'Matematik',
              correct: 26,
              wrong: 4,
              weakTopicIds: ['tp-Limit']),
        ],
      );
      await frames(tester);
      expect(find.text(reasonTurev), findsNothing);
      expect(find.text('"Limit" konusunda denemede yanlış yapmıştın'),
          findsOneWidget);
      // Türev'in önceki zayıflığı çözüldü olarak görünür.
      expect(c.read(topicEvidenceProvider)['tp-Türev']!.label, 'Düzeliyor');
    });

    testWidgets(
        'YOLCULUK 3 — görev oluştur: ders → konu → otomatik başlık → Şimdi → kaydet → '
        'Home\'da bugünün eylemi (yeniden giriş yok)', (tester) async {
      bigScreen(tester);
      await seedOnboarded(topics: ['Bölünebilme']);
      final c = await pumpApp(tester);
      expect(find.text('Bugün için plan yok'), findsNothing);

      await tester.tap(find.byTooltip('Görev ekle').first);
      await frames(tester);
      await tester.tap(find.text('Matematik').last);
      await tester.pump();
      await tester.tap(find.text('Bölünebilme').last);
      await tester.pump();
      await tester.tap(find.text('Şimdi'));
      await tester.pump();
      await tester.tap(find.text('Görevi Ekle'));
      await frames(tester);

      final t = c.read(taskProvider).single;
      expect(t.title, 'Bölünebilme');
      // Home: bugünün eylemi, ders · konu meta ile.
      expect(find.text('Bölünebilme'), findsWidgets);
      expect(find.text('Matematik · Bölünebilme · 25 dk'), findsOneWidget);
    });

    testWidgets(
        'YOLCULUK 4 — konu kısayolu: Home → ders kısayolu → konuya dokun → Focus; '
        'sahte ilerleme YOK', (tester) async {
      bigScreen(tester);
      await seedOnboarded(topics: ['Bölünebilme']);
      final c = await pumpApp(tester);

      // Ders kısayolu kutusu (Home'da en altta; üstteki 'Matematik' odak kartı).
      await tester.ensureVisible(find.text('Matematik').last);
      await tester.tap(find.text('Matematik').last);
      await frames(tester);
      expect(find.text('Bölünebilme'), findsWidgets);
      await tester.tap(find.text('Bölünebilme').first);
      await frames(tester);

      expect(find.text('ODAK SEANSI'), findsOneWidget);
      final topic = c.read(topicProvider).single;
      expect(topic.status, TopicStatus.notStarted);
      expect(topic.activityKeys, isEmpty);
      expect(c.read(focusSessionProvider), isEmpty);
    });

    testWidgets(
        'YOLCULUK 6 — takvim: bir görevi Focus ile yap → günü aç → planlanan ↔ gerçek',
        (tester) async {
      bigScreen(tester);
      await seedOnboarded(topics: ['Bölünebilme']);
      final c = ProviderContainer();
      addTearDown(c.dispose);

      final task = c.read(taskProvider.notifier).addTask(
            title: 'Bölünebilme',
            subjectId: 's-mat',
            dueDate: DateTime.now(),
            estimatedMinutes: 30,
            topicId: 'tp-Bölünebilme',
          );
      final events = c.read(studyEventsProvider);
      final run = events.newRunId();
      events.recordFocusActivity(
        runId: run,
        minutes: 25,
        mode: 'serbest',
        subjectId: 's-mat',
        topicId: 'tp-Bölünebilme',
        taskId: task.id,
      );
      await events.finishFocusRun(
        runId: run,
        topicId: 'tp-Bölünebilme',
        taskId: task.id,
        feeling: FocusFeeling.hard,
        completeTask: true,
      );

      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: const MaterialApp(home: StatsScreen()),
      ));
      await frames(tester);
      final cells = find.descendant(
          of: find.byType(ActivityHeatmap),
          matching: find.byType(GestureDetector));
      await tester.ensureVisible(cells.last);
      await tester.tap(cells.last);
      await tester.pump();

      expect(find.text('25/30 dk 😕'), findsOneWidget,
          reason: 'planlanan 30, gerçekte 25, öğrenci "zorlandım" dedi');
      expect(find.text('1/1 görev · 25 dk odak'), findsOneWidget);
    });
  });

  group('disk tabanlı (yeniden başlatma)', () {
    // Dosya tabanlı kutular: yeniden başlatmayı (kapat → yeniden aç) gerçekten
    // sınamak için. Adapter'lar/Hive başlatma yardımcıyla tek sefer yapılır.
    setUpAll(registerHiveAdaptersOnce);
    tearDownAll(() async => Hive.close());

    test(
        'YOLCULUK 5 (kalıcılık) — çalışma + cevap + görev kapanışı diskten geri okunur; '
        'yeniden açılışta aynı olay TEKRAR sayılmaz', () async {
      Future<void> openAll() async {
        await Hive.openBox<SubjectModel>(HiveBoxes.subjectsBoxName);
        await Hive.openBox<TaskModel>(HiveBoxes.tasksBoxName);
        await Hive.openBox<UserStatsModel>(HiveBoxes.statsBoxName);
        await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName);
        await Hive.openBox<FocusSession>(HiveBoxes.focusSessionsBoxName);
      }

      await openAll();
      final c1 = ProviderContainer();
      c1.read(subjectProvider.notifier).addSubject('Matematik', 0);
      final sid = c1.read(subjectProvider).first.id;
      c1.read(topicProvider.notifier).addTopic(sid, 'Bölünebilme');
      final tid = c1.read(topicProvider).first.id;
      final task = c1.read(taskProvider.notifier).addTask(
            title: 'Bölünebilme',
            subjectId: sid,
            dueDate: DateTime.now(),
            estimatedMinutes: 25,
            topicId: tid,
          );
      final ev = c1.read(studyEventsProvider);
      final run = ev.newRunId();
      ev.recordFocusActivity(
          runId: run,
          minutes: 20,
          mode: 'serbest',
          subjectId: sid,
          topicId: tid,
          taskId: task.id);
      await ev.finishFocusRun(
          runId: run,
          topicId: tid,
          taskId: task.id,
          feeling: FocusFeeling.hard,
          completeTask: true);
      // Diske yazımların bitmesi için kutuları kapat (uygulama kapanışı).
      c1.dispose();
      await Hive.close();

      // "Yeniden başlatma": yeni kutular, yeni container.
      await openAll();
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final topic = c2.read(topicProvider).single;
      expect(topic.status, TopicStatus.studied);
      expect(topic.activityKeys, [TopicProgress.focusRunKey(run)]);
      final s = c2.read(focusSessionProvider).single;
      expect(s.feeling, FocusFeeling.hard);
      expect(s.taskId, task.id);
      expect(s.runId, run);
      final t = c2.read(taskProvider).single;
      expect(t.isCompleted, isTrue);
      expect(t.actualMinutes, 20);
      expect(c2.read(topicDifficultyProvider)[tid], DifficultySignal.recent);

      // Aynı çalışmanın geç gelen dilimi / görevin aç-kapası konuyu ilerletmez.
      c2.read(studyEventsProvider).recordFocusActivity(
          runId: run,
          minutes: 5,
          mode: 'serbest',
          subjectId: sid,
          topicId: tid,
          taskId: task.id);
      await c2.read(taskProvider.notifier).toggleTaskCompletion(task.id);
      await c2.read(taskProvider.notifier).toggleTaskCompletion(task.id);
      expect(c2.read(topicProvider).single.status, TopicStatus.studied);
      await Hive.close();
    });
  });
}
