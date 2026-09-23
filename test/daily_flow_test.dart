import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/focus_anchor.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/home_screen.dart';
import 'package:study_planner/next_task_picker.dart';
import 'package:study_planner/study_events.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/today_study.dart';
import 'package:study_planner/topic_evidence.dart';
import 'package:study_planner/topic_evidence_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// GÜNLÜK ÇALIŞMA AKIŞI — "şimdi ne yapacağım?" Öğrenci Home'u açar, tek dokunuşla
/// başlar; gerçek çalışma dakikası Home'da görünür; yeni kanıt sıradaki öneriyi
/// değiştirir. Gerçek Home + Focus, gerçek provider'lar.
void main() {
  final today = DateTime.now();
  final day = DateTime(today.year, today.month, today.day);

  Future<void> frames(WidgetTester tester, [int n = 4]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  TaskModel task(
    String title, {
    String subject = 's-mat',
    String? topicId,
    int? minutes,
    TaskPriority priority = TaskPriority.medium,
    int order = 0,
    String? reason,
    bool done = false,
  }) =>
      TaskModel(
        id: 'task-$title',
        title: title,
        subjectId: subject,
        topicId: topicId,
        dueDate: day,
        estimatedMinutes: minutes,
        priority: priority,
        sourceReason: reason,
        isCompleted: done,
        completedAt: done ? DateTime.now() : null,
        createdAt: DateTime(2026, 9, 1, 8, order),
      );

  TopicModel topic(String id, String name, {String subject = 's-mat'}) =>
      TopicModel(
        id: id,
        subjectId: subject,
        name: name,
        createdAt: DateTime(2026, 9, 1),
      );

  Future<void> seed({
    List<TaskModel> tasks = const [],
    List<TopicModel> topics = const [],
    List<DenemeEntry> denemeler = const [],
    List<FocusSession> sessions = const [],
  }) async {
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
    for (final s in [
      ('s-mat', 'Matematik'),
      ('s-fiz', 'Fizik'),
      ('s-tur', 'Türkçe'),
    ]) {
      await HiveBoxes.subjects.put(
        s.$1,
        SubjectModel(
          id: s.$1,
          name: s.$2,
          colorValue: 0xFF6750A4,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
    }
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
  }

  Future<ProviderContainer> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    return container;
  }

  FocusSession run(String id, int minutes,
          {String? topicId, String? taskId, int? feeling, DateTime? at}) =>
      FocusSession(
        id: id,
        endedAt: at ?? DateTime.now(),
        minutes: minutes,
        mode: 'serbest',
        subjectId: 's-mat',
        topicId: topicId,
        taskId: taskId,
        runId: 'run-$id',
        feeling: feeling,
      );

  group('saf mantık', () {
    test('TodayStudy: gerçek ≠ plan; süresiz görev 0, uydurma süre yok', () {
      final s = TodayStudy.compute(
        tasks: [
          task('a', minutes: 60),
          task('b', minutes: 40, done: true), // biten görev de plana dahil
          task('c'), // süre girilmemiş → 0
          TaskModel(
            id: 'yarin',
            title: 'yarın',
            dueDate: day.add(const Duration(days: 1)),
            estimatedMinutes: 500,
            createdAt: DateTime(2026, 9, 1),
          ),
        ],
        loggedMinutes: 40,
        liveMinutes: 5,
        now: today,
      );
      expect(s.plannedMinutes, 100);
      expect(s.actualMinutes, 45);
      expect(s.hasPlan, isTrue);
    });

    test('todayStudyLine: dakika söyler, görev sayısı değil', () {
      String line(int actual, int planned) => todayStudyLine(
            TodayStudy(actualMinutes: actual, plannedMinutes: planned),
            hasTasksToday: true,
          );
      expect(line(75, 100), '1 sa 15 dk çalıştın · plan 1 sa 40 dk');
      expect(line(25, 0), '25 dk çalıştın');
      expect(line(0, 100), 'Bugünkü plan 1 sa 40 dk · henüz başlamadın');
      expect(line(0, 0), 'Henüz başlamadın — ilk çalışma hazır.');
    });

    test('FocusAnchorMath.unloggedMinutes: yazılmamış canlı dakika (kırpılmış)', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final raw = {
        'mode': 'free',
        'blockMin': 25,
        'committedSec': 15 * 60,
        'loggedSec': 10 * 60,
        'segStartMs': now,
        'lastActiveMs': now,
      };
      expect(FocusAnchorMath.unloggedMinutes(raw, nowMs: now), 5);
      // duraklatılmış seans: yazılmış süreden fazlası sayılmaz
      final paused = {...raw}..remove('segStartMs');
      expect(FocusAnchorMath.unloggedMinutes(paused, nowMs: now), 0);
    });

    test('sıra: GÜÇLÜ kanıt öne alır; tek "zorlandım" sırayı oynatmaz', () {
      final a = task('a', topicId: 't-a', order: 1);
      final b = task('b', topicId: 't-b', order: 2);
      final c = task('c', topicId: 't-c', order: 3);
      final d = task('d', topicId: 't-d', order: 4, priority: TaskPriority.high);
      TopicEvidence ev(TopicEvidenceState s) => TopicEvidence(s, 'x');
      final evidence = {
        't-a': ev(TopicEvidenceState.struggling), // tek cevap: sırayı DEĞİŞTİRMEZ
        't-b': ev(TopicEvidenceState.weakConfirmed), // deneme: en öne
        't-c': ev(TopicEvidenceState.strugglingRepeatedly), // doğrulanmış: ikinci
        't-d': ev(TopicEvidenceState.improving), // düzeliyor: sırayı değiştirmez
      };
      final order = NextTaskPicker.untimedToday([a, b, c, d], today,
              evidenceByTopic: evidence)
          .map((t) => t.id);
      expect(order, ['task-b', 'task-c', 'task-d', 'task-a']);
      expect(
          NextTaskPicker.isRecommendedOrder([a, b, c, d],
              evidenceByTopic: evidence),
          isTrue);
    });

    test('hiç sinyal yoksa "önerilen sıra" denmez, öğrencinin kendi sırası korunur',
        () {
      final tasks = [task('ikinci', order: 2), task('birinci', order: 1)];
      expect(NextTaskPicker.untimedToday(tasks, today).map((t) => t.title),
          ['birinci', 'ikinci']);
      expect(NextTaskPicker.isRecommendedOrder(tasks), isFalse);
    });

    test('saati saatler sonraki görev "şimdi"nin eylemi değil; hazır bekleyen öne geçer',
        () {
      final now = DateTime(today.year, today.month, today.day, 10, 0);
      final later = task('akşam', order: 1).._setTime(
          DateTime(today.year, today.month, today.day, 20, 0));
      final ready = task('hazır', order: 2);
      expect(NextTaskPicker.pick([later, ready], now)?.title, 'hazır');
      // Başlamasına 30 dk kala saatli görev "şimdi"dir.
      final soon = task('yakında', order: 3).._setTime(
          DateTime(today.year, today.month, today.day, 10, 30));
      expect(NextTaskPicker.pick([soon, ready], now)?.title, 'yakında');
      // Hazır bekleyen yoksa saatli olan yine önerilir.
      expect(NextTaskPicker.pick([later], now)?.title, 'akşam');
    });
  });

  group('Home — bellek kutularıyla', () {
    setUp(openMemoryBoxes);
    tearDown(closeMemoryBoxes);

    testWidgets(
        'JOURNEY A/J: Home → "Başla" → Focus çalışır durumda + bağlam tam → geri çık → '
        'banner → Focus\'a dönüş: görev/konu/gerekçe kaybolmaz', (tester) async {
      await seed(
        tasks: [task('Bölünebilme', topicId: 't-b', minutes: 25)],
        topics: [topic('t-b', 'Bölünebilme')],
        denemeler: [
          DenemeEntry(
            id: 'd',
            examType: 'TYT',
            date: today.subtract(const Duration(days: 2)),
            sections: [
              DenemeSectionScore(
                  subject: 'Matematik',
                  correct: 20,
                  wrong: 10,
                  weakTopicIds: ['t-b']),
            ],
          ),
        ],
      );
      final c = await pumpHome(tester);

      // Tek dominant eylem: kartta ne / ne kadar / neden + "Başla".
      expect(find.text('Bölünebilme'), findsWidgets);
      expect(find.text('Matematik · Bölünebilme · 25 dk'), findsOneWidget);
      expect(find.text('Son denemende burada zorlandın.'), findsOneWidget);
      expect(find.text('Başla'), findsOneWidget);

      // Başla → başka hiçbir karar yok: Focus AÇIK ve SAYAÇ ÇALIŞIYOR.
      await tester.tap(find.text('Başla'));
      await frames(tester);
      expect(find.text('ODAK SEANSI'), findsOneWidget);
      expect(find.text('Duraklat'), findsOneWidget);
      expect(find.text('Son denemende burada zorlandın.'), findsOneWidget);
      expect(find.text('Matematik · 25 dk'), findsOneWidget);
      final anchor = HiveBoxes.focusAnchor.get('current') as Map;
      expect(anchor['taskId'], 'task-Bölünebilme');
      expect(anchor['topicId'], 't-b');
      expect(anchor['runId'], isNotNull);

      // Geri çık → "arka plana al" → Home'da banner, çalışma sürüyor.
      await tester.binding.handlePopRoute();
      await frames(tester);
      expect(find.text('Sayaç arka planda sürsün mü?'), findsOneWidget);
      await tester.tap(find.text('Arka Plana Al'));
      await frames(tester);
      expect(find.textContaining('Odak devam ediyor'), findsOneWidget);
      expect(find.textContaining('dk odaktasın'), findsOneWidget);

      // Banner → Focus: görev/konu/gerekçe kaybolmadı, AYNI çalışma.
      await tester.tap(find.textContaining('Odak devam ediyor'));
      await frames(tester);
      expect(find.text('ODAK SEANSI'), findsOneWidget);
      expect(find.text('Son denemende burada zorlandın.'), findsOneWidget);
      expect(find.text('Duraklat'), findsOneWidget);
      expect(
          (HiveBoxes.focusAnchor.get('current') as Map)['runId'], anchor['runId']);

      // Niyet + başlatma kanıt DEĞİL: hiçbir seans/dakika yok, konu değişmedi.
      expect(c.read(focusSessionProvider), isEmpty);
      expect(c.read(topicEvidenceProvider)['t-b']!.label,
          'Zayıf — denemeden doğrulandı');
    });

    testWidgets(
        'JOURNEY A: hemen "Bitir" (1 dk\'dan kısa) → hiçbir sahte çalışma dakikası '
        'oluşmaz; Home "henüz başlamadın" der', (tester) async {
      await seed(tasks: [task('Polinomlar', minutes: 25)]);
      await pumpHome(tester);

      await tester.tap(find.text('Başla'));
      await frames(tester);
      await tester.tap(find.text('Bitir'));
      await frames(tester);

      expect(find.text('ODAK SEANSI'), findsNothing);
      expect(find.text('Bugünkü plan 25 dk · henüz başlamadın'), findsOneWidget);
    });

    testWidgets(
        'JOURNEY B/E: 5 görev → Home mantıklı sıra önerir (kanıt > öncelik > gerekçe > '
        'ekleme), Başla doğru bağlamla açar, tamamlanınca tekrar üretmez',
        (tester) async {
      await seed(
        tasks: [
          task('Türkçe paragraf', subject: 's-tur', minutes: 20, order: 1),
          task('Fizik hareket',
              subject: 's-fiz', topicId: 't-h', minutes: 30, order: 2),
          task('Matematik limit',
              topicId: 't-l',
              minutes: 25,
              order: 3,
              priority: TaskPriority.high),
          task('Matematik türev', topicId: 't-t', minutes: 25, order: 4),
          task('Kimya', minutes: 15, order: 5),
        ],
        topics: [
          topic('t-h', 'Hareket', subject: 's-fiz'),
          topic('t-l', 'Limit'),
          topic('t-t', 'Türev'),
        ],
        // Türev: deneme kanıtı; Hareket: doğrulanmış (üst üste) zorlanma.
        denemeler: [
          DenemeEntry(
            id: 'd',
            examType: 'TYT',
            date: today.subtract(const Duration(days: 3)),
            sections: [
              DenemeSectionScore(
                  subject: 'Matematik',
                  correct: 20,
                  wrong: 8,
                  weakTopicIds: ['t-t']),
            ],
          ),
        ],
        sessions: [
          FocusSession(
            id: 'h1',
            endedAt: today.subtract(const Duration(days: 3)),
            minutes: 20,
            mode: 'serbest',
            subjectId: 's-fiz',
            topicId: 't-h',
            runId: 'rh1',
            feeling: FocusFeeling.hard,
          ),
          FocusSession(
            id: 'h2',
            endedAt: today.subtract(const Duration(days: 1)),
            minutes: 20,
            mode: 'serbest',
            subjectId: 's-fiz',
            topicId: 't-h',
            runId: 'rh2',
            feeling: FocusFeeling.hard,
          ),
        ],
      );
      final c = await pumpHome(tester);

      // Odak = deneme kanıtı olan (Türev); ardından doğrulanmış zorlanma (Hareket),
      // sonra yüksek öncelik (Limit), sonra ekleme sırası (Türkçe, Kimya).
      expect(find.text('Matematik türev'), findsOneWidget);
      expect(find.text('Önerilen sıra'), findsOneWidget);
      double y(String t) => tester.getTopLeft(find.text(t)).dy;
      expect(y('Fizik hareket') < y('Matematik limit'), isTrue);
      expect(y('Matematik limit') < y('Türkçe paragraf'), isTrue);
      expect(y('Türkçe paragraf') < y('Kimya'), isTrue);
      // Gerekçeler gerçek kaynaktan; kanıtsızlarda uydurma yok.
      expect(find.text('Son denemende burada zorlandın.'), findsOneWidget);
      expect(find.text('Bu konuda üst üste zorlandığını söyledin.'),
          findsOneWidget);

      // Odak kartı listede TEKRAR görünmez; "Sonra:" doğru.
      expect(find.text('Matematik türev'), findsOneWidget);
      expect(find.text('Sonra: Fizik hareket'), findsOneWidget);

      // Başla → doğru bağlam.
      await tester.tap(find.text('Başla'));
      await frames(tester);
      expect(find.text('ODAK SEANSI'), findsOneWidget);
      expect(find.text('Matematik · 25 dk'), findsOneWidget);
      final anchor = HiveBoxes.focusAnchor.get('current') as Map;
      expect(anchor['taskId'], 'task-Matematik türev');
      expect(anchor['topicId'], 't-t');
      await tester.tap(find.text('Bitir'));
      await frames(tester);

      // JOURNEY E: görev tamamlanınca plan yeniden üretilmez, tekrar etmez.
      await c.read(taskProvider.notifier).completeTask('task-Matematik türev');
      await frames(tester);
      expect(find.text('Matematik türev'), findsNothing);
      expect(find.text('Fizik hareket'), findsOneWidget, reason: 'sıradaki artık odak');
      expect(find.text('Sonra: Matematik limit'), findsOneWidget);
      expect(find.text('Türkçe paragraf'), findsOneWidget);

      // Test temizliği: hedef kutlaması diyaloğunu kapat, snackbar bitsin.
      if (find.text('Günlük hedef tamamlandı!').evaluate().isNotEmpty) {
        await tester.tapAt(const Offset(5, 5));
      }
      await frames(tester, 16);
    });

    testWidgets('JOURNEY C: gerçek 25 dk çalışma → Home\'da "25 dk çalıştın" (XP/görev değil)',
        (tester) async {
      await seed(
        tasks: [task('Polinomlar', minutes: 25)],
        sessions: [run('s1', 25, taskId: 'task-Polinomlar')],
      );
      await pumpHome(tester);
      expect(find.text('25 dk çalıştın · plan 25 dk'), findsOneWidget);
    });

    testWidgets(
        'JOURNEY D: plan 100 dk, gerçek 40 dk → Home ikisini AYRI ve doğru gösterir',
        (tester) async {
      await seed(
        tasks: [
          task('A', minutes: 60, order: 1),
          task('B', minutes: 40, order: 2),
        ],
        sessions: [run('s1', 40)],
      );
      await pumpHome(tester);
      expect(find.text('40 dk çalıştın · plan 1 sa 40 dk'), findsOneWidget);
    });

    testWidgets(
        'devam eden seans: yazılmamış canlı dakika da bugünkü toplama eklenir '
        '(Focus\'tan çıkınca kaybolmaz)', (tester) async {
      await seed(
        tasks: [task('Polinomlar', minutes: 60)],
        sessions: [run('s1', 20)],
      );
      final now = DateTime.now().millisecondsSinceEpoch;
      await HiveBoxes.focusAnchor.put('current', {
        'mode': 'free',
        'phase': 'work',
        'blockMin': 25,
        'pomoCycle': 1,
        'committedSec': 15 * 60, // 15 dk çalışıldı, henüz yazılmadı
        'loggedSec': 0,
        'segStartMs': now,
        'lastActiveMs': now,
        'subjectId': 's-mat',
        'topicId': null,
        'note': 'Polinomlar',
        'runId': 'live',
        'taskId': 'task-Polinomlar',
        'reason': null,
      });
      await pumpHome(tester);
      // 20 dk yazılmış + 15 dk canlı = 35 dk; banner bu seansı gösterir.
      expect(find.text('35 dk çalıştın · plan 1 sa'), findsOneWidget);
      expect(find.text('15 dk odaktasın'), findsOneWidget);
    });

    testWidgets(
        'JOURNEY F: yeni güçlü kanıt (deneme) gelince SONRAKİ öneri değişir; '
        'ekran her küçük olayda zıplamaz', (tester) async {
      await seed(
        tasks: [
          task('Fizik hareket', subject: 's-fiz', minutes: 30, order: 1),
          task('Matematik türev', topicId: 't-t', minutes: 25, order: 2),
        ],
        topics: [topic('t-t', 'Türev')],
      );
      final c = await pumpHome(tester);
      // Kanıt yok: öğrencinin sırası (Fizik), "önerilen sıra" iddiası yok.
      expect(find.text('Fizik hareket'), findsOneWidget);
      expect(find.text('Sonra: Matematik türev'), findsOneWidget);
      expect(find.text('Önerilen sıra'), findsNothing);

      // Küçük olay: tek "zorlandım" → SIRA DEĞİŞMEZ.
      final ev = c.read(studyEventsProvider);
      final r1 = ev.newRunId();
      ev.recordFocusActivity(
          runId: r1, minutes: 10, mode: 'serbest', subjectId: 's-mat', topicId: 't-t');
      await ev.finishFocusRun(
          runId: r1, topicId: 't-t', feeling: FocusFeeling.hard);
      await tester.pump();
      expect(find.text('Sonra: Matematik türev'), findsOneWidget,
          reason: 'tek cevap sırayı oynatmaz');
      // ...ama gerekçe olarak görünür.
      expect(find.text('Son çalışmanda burada zorlandın.'), findsOneWidget);

      // Güçlü kanıt: deneme Türev'i zayıf gösteriyor → sıradaki öneri DEĞİŞİR.
      c.read(denemeProvider.notifier).addEntry(
        examType: 'TYT',
        date: DateTime.now(),
        sections: [
          DenemeSectionScore(
              subject: 'Matematik', correct: 18, wrong: 10, weakTopicIds: ['t-t']),
        ],
      );
      await tester.pump();
      expect(find.text('Sonra: Fizik hareket'), findsOneWidget);
      expect(find.text('Önerilen sıra'), findsOneWidget);
    });

    testWidgets(
        'JOURNEY G: öneriyi reddedip listedeki BAŞKA çalışmayı başlatmak: doğru bağlam, '
        'öneri ve sistem bozulmaz', (tester) async {
      await seed(
        tasks: [
          task('Matematik türev', topicId: 't-t', minutes: 25, order: 1),
          task('Fizik hareket', subject: 's-fiz', minutes: 30, order: 2),
        ],
        topics: [topic('t-t', 'Türev')],
      );
      final c = await pumpHome(tester);
      expect(find.text('Başla'), findsOneWidget);

      // Listedeki satıra dokun (öneri değil, kendi seçimi) → Focus AÇILIR ama
      // sayaç kendiliğinden başlamaz (öğrenci bilinçli seçti, "Başlat" der).
      await tester.tap(find.text('Fizik hareket'));
      await frames(tester);
      expect(find.text('ODAK SEANSI'), findsOneWidget);
      expect(find.text('Fizik hareket'), findsWidgets);
      expect(find.text('Başlat'), findsOneWidget);
      expect(HiveBoxes.focusAnchor.get('current'), isNull);

      await tester.binding.handlePopRoute();
      await frames(tester);
      // Home aynı: öneri hâlâ Türev, hiçbir kayıt değişmedi.
      expect(find.text('Matematik türev'), findsOneWidget);
      expect(c.read(focusSessionProvider), isEmpty);
      expect(c.read(taskProvider).every((t) => !t.isCompleted), isTrue);
    });

    testWidgets(
        'JOURNEY I: yeterli kanıt yoksa sahte kişiselleştirme YOK — dürüst tek cümle, '
        '"önerilen sıra"/jenerik gerekçe yok', (tester) async {
      await seed(tasks: [
        task('Polinomlar', minutes: 25, order: 1),
        task('Paragraf', subject: 's-tur', minutes: 20, order: 2),
      ]);
      await pumpHome(tester);

      expect(find.text('Bugünkü planında sıradaki çalışma.'), findsOneWidget);
      expect(find.text('Önerilen sıra'), findsNothing);
      expect(find.textContaining('zorlandın'), findsNothing);
      expect(find.textContaining('denemede'), findsNothing);
    });

    testWidgets(
        'görev yokken de tek eylem: öneri "Başla" ile ders bağlamlı, çalışır Focus açar',
        (tester) async {
      await seed();
      await pumpHome(tester);
      expect(find.text('Başla'), findsOneWidget);
      expect(find.textContaining('25 dk'), findsWidgets);

      await tester.tap(find.text('Başla'));
      await frames(tester);
      expect(find.text('ODAK SEANSI'), findsOneWidget);
      expect(find.text('Duraklat'), findsOneWidget);
      final anchor = HiveBoxes.focusAnchor.get('current') as Map;
      expect(anchor['subjectId'], isNotNull);
      expect(anchor['taskId'], isNull);
    });

    testWidgets(
        'JOURNEY I (öneri yolu): görev yokken jenerik "dengeli ilerle" gerekçesi '
        'gösterilmez', (tester) async {
      await seed();
      await pumpHome(tester);
      expect(find.textContaining('Dengeli ilerlemek'), findsNothing);
    });
  });

  group('JOURNEY H — yeniden açılış (disk)', () {
    setUpAll(registerHiveAdaptersOnce);
    tearDownAll(() async => Hive.close());

    test('bugünkü gerçek süre, plan ve kalan sıra yeniden açılışta korunur', () async {
      Future<void> open() async {
        await Hive.openBox<SubjectModel>(HiveBoxes.subjectsBoxName);
        await Hive.openBox<TaskModel>(HiveBoxes.tasksBoxName);
        await Hive.openBox<UserStatsModel>(HiveBoxes.statsBoxName);
        await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName);
        await Hive.openBox<FocusSession>(HiveBoxes.focusSessionsBoxName);
        await Hive.openBox<DenemeEntry>(HiveBoxes.denemelerBoxName);
        await Hive.openBox(HiveBoxes.focusAnchorBoxName);
      }

      await open();
      final c1 = ProviderContainer();
      final a = c1.read(taskProvider.notifier).addTask(
          title: 'A', dueDate: day, estimatedMinutes: 60);
      c1.read(taskProvider.notifier)
          .addTask(title: 'B', dueDate: day, estimatedMinutes: 40);
      final ev = c1.read(studyEventsProvider);
      final r = ev.newRunId();
      ev.recordFocusActivity(
          runId: r, minutes: 40, mode: 'serbest', taskId: a.id);
      await ev.finishFocusRun(runId: r, taskId: a.id, completeTask: true);
      c1.dispose();
      await Hive.close();

      await open();
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      final tasks = c2.read(taskProvider);
      final study = TodayStudy.compute(
        tasks: tasks,
        loggedMinutes: c2.read(focusTodayMinutesProvider),
        now: DateTime.now(),
      );
      expect(study.actualMinutes, 40);
      expect(study.plannedMinutes, 100);
      // Kalan plan: yalnız B (A tamamlandı) — tekrar üretilmedi.
      expect(NextTaskPicker.remaining(tasks, DateTime.now()).map((t) => t.title),
          ['B']);
      await Hive.close();
    });
  });
}

extension on TaskModel {
  void _setTime(DateTime t) => scheduledTime = t;
}
