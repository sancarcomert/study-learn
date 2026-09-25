import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/home_screen.dart';
import 'package:study_planner/stats_provider.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// Seri kilometre taşı (7/30/100 gün, P0-3) — günlük hedef kutlamasından
/// AYRI bir an olarak, yalnız serinin kendisi bir eşiğe denk geldiğinde
/// bir kez gösterilmeli.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<void> frames(WidgetTester tester, [int n = 5]) async {
    for (var i = 0; i < n; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('seri 6→7 olunca "7 günlük seri!" kutlaması çıkar',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));

    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        dailyGoal: 1,
        currentStreak: 6,
        lastCompletedDate: yesterday,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        lastCarryOverPromptDate: DateTime.now(),
      ),
    );
    await HiveBoxes.subjects.put(
      's',
      SubjectModel(
        id: 's',
        name: 'Matematik',
        colorValue: 0xFF6750A4,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await HiveBoxes.tasks.put(
      't',
      TaskModel(
        id: 't',
        title: 'Türev tekrarı',
        subjectId: 's',
        dueDate: DateTime(today.year, today.month, today.day),
        createdAt: DateTime(2026, 9, 1),
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await frames(tester);

    // Günün tek görevini tamamla → dailyGoal (1) tutturulur → seri 6'dan
    // 7'ye çıkar → kilometre taşı tetiklenmeli.
    container.read(taskProvider.notifier).toggleTaskCompletion('t');
    await frames(tester);

    expect(find.text('7 günlük seri!'), findsOneWidget);
    expect(find.text('Bir hafta boyunca her gün geldin.'), findsOneWidget);
    // Aynı tamamlama günlük hedefi de tuttururdu — normalde AYRI bir
    // "Günlük hedef tamamlandı!" diyaloğu da açılırdı, ama kilometre taşı
    // günlerinde o bilerek bastırılıyor (bkz. home_screen.dart
    // goalReachedEventProvider listener'ı) — tek diyalog kalmalı.
    expect(find.text('Günlük hedef tamamlandı!'), findsNothing);
    expect(container.read(statsProvider).currentStreak, 7);

    // Diyaloğu kapat — açık bir konfeti diyaloğuyla widget ağacını
    // sonlandırmak "ConfettiController was used after being disposed"
    // hatası veriyor (bkz. beta_journeys_test.dart'taki aynı önlem).
    await tester.tapAt(const Offset(5, 5));
    await frames(tester);
  });

  testWidgets('seri kilometre taşı değilse (ör. 5→6) kutlama çıkmaz',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final today = DateTime.now();
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));

    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        dailyGoal: 1,
        currentStreak: 5,
        lastCompletedDate: yesterday,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        lastCarryOverPromptDate: DateTime.now(),
      ),
    );
    await HiveBoxes.subjects.put(
      's',
      SubjectModel(
        id: 's',
        name: 'Matematik',
        colorValue: 0xFF6750A4,
        createdAt: DateTime(2026, 1, 1),
      ),
    );
    await HiveBoxes.tasks.put(
      't',
      TaskModel(
        id: 't',
        title: 'Türev tekrarı',
        subjectId: 's',
        dueDate: DateTime(today.year, today.month, today.day),
        createdAt: DateTime(2026, 9, 1),
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: HomeScreen()),
    ));
    await frames(tester);

    container.read(taskProvider.notifier).toggleTaskCompletion('t');
    await frames(tester);

    expect(container.read(statsProvider).currentStreak, 6);
    expect(find.textContaining('günlük seri!'), findsNothing);

    // Milestone olmasa da günlük hedef kutlaması açılmış olabilir — kapat
    // (bkz. yukarıdaki testteki aynı not).
    if (find.text('Günlük hedef tamamlandı!').evaluate().isNotEmpty) {
      await tester.tapAt(const Offset(5, 5));
      await frames(tester);
    }
  });
}
