import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/add_subject_sheet.dart';
import 'package:study_planner/focus_screen.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/home_screen.dart';
import 'package:study_planner/study_intent.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subjects_screen.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// BETA KAPISI — gerçek kullanımda karşılaşılacak, veriyi bozan / çelişki üreten
/// yolların (unutulan zamanlayıcı, çakışan seans, geri al, boş başlangıç)
/// gerçek ekranlarla sınanması.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<void> seedBasics({bool task = true}) async {
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
    await HiveBoxes.topics.put(
      't-b',
      TopicModel(
        id: 't-b',
        subjectId: 's-mat',
        name: 'Bölünebilme',
        createdAt: DateTime(2026, 9, 1),
      ),
    );
    if (task) {
      final n = DateTime.now();
      for (final e in {'A': 'Bölünebilme', 'B': 'Türev'}.entries) {
        await HiveBoxes.tasks.put(
          'task-${e.key}',
          TaskModel(
            id: 'task-${e.key}',
            title: e.value,
            subjectId: 's-mat',
            topicId: e.key == 'A' ? 't-b' : null,
            dueDate: DateTime(n.year, n.month, n.day),
            createdAt: DateTime(2026, 9, 1, e.key == 'A' ? 1 : 2),
            estimatedMinutes: 25,
          ),
        );
      }
    }
  }

  Future<ProviderContainer> openFocus(
    WidgetTester tester,
    StudyIntent intent,
  ) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FocusScreen(intent: intent)),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return container;
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  Map<String, dynamic> anchor({
    required String runId,
    required DateTime segStart,
    DateTime? lastActive,
    int committedSec = 0,
    String taskId = 'task-A',
    String topicId = 't-b',
  }) =>
      {
        'mode': 'free',
        'phase': 'work',
        'blockMin': 25,
        'pomoCycle': 1,
        'committedSec': committedSec,
        'loggedSec': 0,
        'segStartMs': segStart.millisecondsSinceEpoch,
        if (lastActive != null) 'lastActiveMs': lastActive.millisecondsSinceEpoch,
        'subjectId': 's-mat',
        'topicId': topicId,
        'note': 'Bölünebilme',
        'runId': runId,
        'taskId': taskId,
        'reason': null,
      };

  const taskA = StudyIntent(
    source: StudyIntentSource.task,
    subjectId: 's-mat',
    topicId: 't-b',
    taskId: 'task-A',
    title: 'Bölünebilme',
    targetMinutes: 25,
  );

  group('unutulan zamanlayıcı — sahte çalışma süresi ÜRETİLMEZ', () {
    testWidgets(
        '10 saat önce bırakılmış (eski çapa) seans: uygulama arka planda geçen '
        'zamanın tamamını "çalışma" saymaz', (tester) async {
      await seedBasics();
      await HiveBoxes.focusAnchor.put(
        'current',
        anchor(
            runId: 'old',
            segStart: DateTime.now().subtract(const Duration(hours: 10))),
      );
      final c = await openFocus(tester, taskA);

      await tester.tap(find.text('Bitir'));
      await settle(tester);

      final minutes =
          c.read(focusSessionProvider).fold<int>(0, (a, s) => a + s.minutes);
      // hedef (25) + 10 dk tolerans = en çok 35 dk; asla 600.
      expect(minutes, lessThanOrEqualTo(35));
      expect(minutes, greaterThan(0));
    });

    testWidgets(
        'arka plana alınmadan önce 10 dk çalışıldıysa: o 10 dk + hedefin kalanı + '
        'tolerans sayılır, sonrası değil', (tester) async {
      await seedBasics();
      final away = DateTime.now().subtract(const Duration(hours: 9));
      await HiveBoxes.focusAnchor.put(
        'current',
        anchor(
          runId: 'old',
          segStart: away.subtract(const Duration(minutes: 10)),
          lastActive: away,
        ),
      );
      final c = await openFocus(tester, taskA);
      await tester.tap(find.text('Bitir'));
      await settle(tester);

      final minutes =
          c.read(focusSessionProvider).fold<int>(0, (a, s) => a + s.minutes);
      expect(minutes, 35); // 10 + (25-10) + 10
    });

    testWidgets('kısa ara (5 dk) tamamen sayılır — meşru çalışma kırpılmaz',
        (tester) async {
      await seedBasics();
      final now = DateTime.now();
      await HiveBoxes.focusAnchor.put(
        'current',
        anchor(
          runId: 'old',
          segStart: now.subtract(const Duration(minutes: 20)),
          lastActive: now.subtract(const Duration(minutes: 5)),
        ),
      );
      final c = await openFocus(tester, taskA);
      await tester.tap(find.text('Bitir'));
      await settle(tester);

      final minutes =
          c.read(focusSessionProvider).fold<int>(0, (a, s) => a + s.minutes);
      expect(minutes, inInclusiveRange(19, 21));
    });
  });

  testWidgets(
      'devam eden A seansı varken B görevinden Focus açılırsa: B bağlamı görünür, '
      'A\'nın ölçülmüş dakikaları A\'ya kaydedilir (sessizce A\'ya dönülmez)',
      (tester) async {
    await seedBasics();
    final now = DateTime.now();
    await HiveBoxes.focusAnchor.put(
      'current',
      anchor(
        runId: 'run-A',
        segStart: now.subtract(const Duration(minutes: 12)),
        lastActive: now.subtract(const Duration(minutes: 1)),
      ),
    );
    final c = await openFocus(
      tester,
      const StudyIntent(
        source: StudyIntentSource.task,
        subjectId: 's-mat',
        taskId: 'task-B',
        title: 'Türev',
        targetMinutes: 25,
      ),
    );

    // B'nin bağlamı: başlık Türev, henüz çalışmıyor (Başlat görünür)
    expect(find.text('Türev'), findsWidgets);
    expect(find.text('Başlat'), findsOneWidget);

    // A'nın ölçülmüş dakikaları A göreviyle kaydedildi.
    final sessions = c.read(focusSessionProvider);
    expect(sessions, hasLength(1));
    expect(sessions.single.taskId, 'task-A');
    expect(sessions.single.runId, 'run-A');
    expect(sessions.single.minutes, inInclusiveRange(11, 13));
    // Eski çapa temizlendi (Home'da hayalet "devam ediyor" bandı kalmaz).
    expect(HiveBoxes.focusAnchor.get('current'), isNull);
  });

  testWidgets(
      'devam eden seansla AYNI görev açılırsa kaldığı yerden devam eder (çakışma yok)',
      (tester) async {
    await seedBasics();
    final now = DateTime.now();
    await HiveBoxes.focusAnchor.put(
      'current',
      anchor(
        runId: 'run-A',
        segStart: now.subtract(const Duration(minutes: 12)),
        lastActive: now.subtract(const Duration(minutes: 1)),
      ),
    );
    final c = await openFocus(tester, taskA);
    expect(find.text('Bitir'), findsOneWidget);
    expect(find.text('Duraklat'), findsOneWidget, reason: 'çalışıyor');
    expect(c.read(focusSessionProvider), isEmpty);
  });

  testWidgets(
      'ders silip GERİ AL: konuların olay anahtarları ve görevlerin ders/konu bağı '
      'geri gelir (yoksa aynı olay iki kez sayılır, görev bağı sessizce kaybolur)',
      (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedBasics();
    final topic = HiveBoxes.topics.get('t-b')!;
    topic.status = TopicStatus.studied;
    topic.activityKeys = ['run:x', 'task:task-A'];
    await topic.save();

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SubjectsScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.drag(find.byType(Dismissible).first, const Offset(-800, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pumpAndSettle();
    expect(container.read(topicProvider), isEmpty);
    expect(container.read(taskProvider).every((t) => t.subjectId == null), isTrue);

    await tester.tap(find.text('GERİ AL'));
    await tester.pumpAndSettle();

    final restored = container.read(topicProvider).single;
    expect(restored.status, TopicStatus.studied);
    expect(restored.activityKeys, ['run:x', 'task:task-A']);
    final tasks = container.read(taskProvider);
    expect(tasks.firstWhere((t) => t.id == 'task-A').subjectId, 's-mat');
    expect(tasks.firstWhere((t) => t.id == 'task-A').topicId, 't-b');
    expect(tasks.firstWhere((t) => t.id == 'task-B').subjectId, 's-mat');
  });

  testWidgets(
      'hiç ders yokken (onboarding atlandı) Home\'daki tek eylem "ders ekle"yi AÇAR — '
      'Koç sohbetine yönlendirip çıkmaza sokmaz', (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        dailyGoal: 0,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        lastCarryOverPromptDate: DateTime.now(),
      ),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Önce bir ders ekle, sonra plan kur.'), findsOneWidget);
    await tester.tap(find.text('Önce bir ders ekle, sonra plan kur.'));
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.byType(AddSubjectSheet), findsOneWidget);
  });
}
