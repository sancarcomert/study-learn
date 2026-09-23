import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/stats_screen.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';
import 'package:study_planner/widgets/activity_heatmap.dart';

import 'support/hive_memory.dart';

/// Yolculuk F — Çalışma Takvimi: bir güne dokununca "o gün ne planlandı, ne
/// yapıldı, gerçekte ne kadar sürdü" hemen anlaşılır; süsleme değil, cevap.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  testWidgets('bir güne dokun: plan ↔ gerçek, ders/konu, çalışma cevabı',
      (tester) async {
    tester.view.physicalSize = const Size(900, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);

    await HiveBoxes.stats.put('main', UserStatsModel(hasSeenExactAlarmPrompt: true));
    await HiveBoxes.subjects.put(
      's-mat',
      SubjectModel(id: 's-mat', name: 'Matematik', colorValue: 0xFF6750A4, createdAt: DateTime(2026, 1, 1)),
    );
    await HiveBoxes.subjects.put(
      's-fiz',
      SubjectModel(id: 's-fiz', name: 'Fizik', colorValue: 0xFF2196F3, createdAt: DateTime(2026, 1, 1)),
    );
    await HiveBoxes.topics.put(
      't-b',
      TopicModel(id: 't-b', subjectId: 's-mat', name: 'Bölünebilme', createdAt: DateTime(2026, 9, 1)),
    );
    // Planlı ve bitirilmiş görev: plan 30 dk, gerçek 25 dk (Focus'tan)
    await HiveBoxes.tasks.put(
      'done',
      TaskModel(
        id: 'done',
        title: 'Bölünebilme',
        subjectId: 's-mat',
        topicId: 't-b',
        dueDate: day,
        isCompleted: true,
        completedAt: now,
        createdAt: DateTime(2026, 9, 1),
        estimatedMinutes: 30,
        actualMinutes: 25,
      ),
    );
    // Planlı ama yapılmamış görev
    await HiveBoxes.tasks.put(
      'todo',
      TaskModel(
        id: 'todo',
        title: 'Fizik: Vektörler',
        subjectId: 's-fiz',
        dueDate: day,
        createdAt: DateTime(2026, 9, 2),
        estimatedMinutes: 40,
      ),
    );
    // Görevle bağlı çalışma (Zorlandım) + göreve bağlı olmayan ayrı çalışma
    await HiveBoxes.focusSessions.put(
      'f1',
      FocusSession(
        id: 'f1',
        endedAt: now,
        minutes: 25,
        mode: 'serbest',
        subjectId: 's-mat',
        topicId: 't-b',
        taskId: 'done',
        runId: 'r1',
        feeling: FocusFeeling.hard,
      ),
    );
    await HiveBoxes.focusSessions.put(
      'f2',
      FocusSession(
        id: 'f2',
        endedAt: now,
        minutes: 15,
        mode: 'serbest',
        subjectId: 's-fiz',
        runId: 'r2',
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: StatsScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // Bir gün seçilmeden bir ipucu
    expect(find.text('Bir güne dokun.'), findsOneWidget);

    // Bugünün karesi = ısı haritasındaki son dokunulabilir kare.
    final cells = find.descendant(
        of: find.byType(ActivityHeatmap), matching: find.byType(GestureDetector));
    await tester.ensureVisible(cells.last);
    await tester.tap(cells.last);
    await tester.pump();

    // Özet: 1/2 görev · 40 dk odak
    expect(find.text('1/2 görev · 40 dk odak'), findsOneWidget);
    // Tamamlanmamış önce, tamamlanan sonra; ders · konu
    expect(find.text('Fizik: Vektörler'), findsOneWidget);
    expect(find.text('Bölünebilme'), findsWidgets);
    expect(find.text('Matematik · Bölünebilme'), findsOneWidget);
    // Plan ↔ gerçek yan yana + çalışmanın cevabı (Zorlandım 😕)
    expect(find.text('25/30 dk 😕'), findsOneWidget);
    // Yapılmamış görevin planı
    expect(find.text('plan 40 dk'), findsOneWidget);
    // Göreve bağlı olmayan çalışma ayrı satır
    expect(find.text('Odak seansı'), findsOneWidget);
    expect(find.text('15 dk'), findsOneWidget);
  });
}
