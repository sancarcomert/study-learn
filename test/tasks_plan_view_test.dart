import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/tasks_screen.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// Görevler sekmesi Home'la AYNI önerilen sırayı ve gerekçeyi gösterir; gün
/// özeti planlanan ↔ gerçekleşen dakikayı ayrı söyler.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  testWidgets('bugün: önerilen sıra + gerekçe + "plan ↔ gerçek" özeti',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final n = DateTime.now();
    final day = DateTime(n.year, n.month, n.day);
    await HiveBoxes.stats.put('main', UserStatsModel(hasSeenExactAlarmPrompt: true));
    await HiveBoxes.subjects.put(
      's',
      SubjectModel(id: 's', name: 'Matematik', colorValue: 0xFF6750A4, createdAt: DateTime(2026, 1, 1)),
    );
    await HiveBoxes.topics.put(
      't-t',
      TopicModel(id: 't-t', subjectId: 's', name: 'Türev', createdAt: DateTime(2026, 9, 1)),
    );
    TaskModel task(String id, {String? topicId, int min = 30, int h = 8}) => TaskModel(
          id: id,
          title: id,
          subjectId: 's',
          topicId: topicId,
          dueDate: day,
          estimatedMinutes: min,
          createdAt: DateTime(2026, 9, 1, h),
        );
    await HiveBoxes.tasks.put('Önce eklenen', task('Önce eklenen', h: 8));
    await HiveBoxes.tasks.put('Türev çöz', task('Türev çöz', topicId: 't-t', h: 9));
    await HiveBoxes.denemeler.put(
      'd',
      DenemeEntry(
        id: 'd',
        examType: 'TYT',
        date: n.subtract(const Duration(days: 2)),
        sections: [
          DenemeSectionScore(subject: 'Matematik', correct: 20, wrong: 8, weakTopicIds: ['t-t']),
        ],
      ),
    );
    await HiveBoxes.focusSessions.put(
      'f',
      FocusSession(id: 'f', endedAt: n, minutes: 20, mode: 'serbest', subjectId: 's', runId: 'r'),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TasksScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    // Sıra: kanıtı olan (Türev) sonradan eklenmiş olsa da ÖNDE; başlık dürüst.
    expect(find.text('Önerilen sıra'), findsOneWidget);
    double y(String t) => tester.getTopLeft(find.text(t)).dy;
    expect(y('Türev çöz') < y('Önce eklenen'), isTrue);
    // Neden burada: gerçek gerekçe (yalnız kanıtı olan görevde).
    expect(find.text('Son denemende burada zorlandın.'), findsOneWidget);
    // Plan (tahmini) ↔ gerçek (ölçülmüş) AYRI etiketli.
    expect(find.text('2 görev · plan 1 sa · gerçek 20 dk · 0/2 tamam'),
        findsOneWidget);
  });

  testWidgets('sağa kaydırarak ertele: GERİ AL orijinal tarihi/erteleme '
      'sayısını geri getirir', (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final n = DateTime.now();
    final day = DateTime(n.year, n.month, n.day);
    await HiveBoxes.stats.put('main', UserStatsModel(hasSeenExactAlarmPrompt: true));
    await HiveBoxes.subjects.put(
      's',
      SubjectModel(id: 's', name: 'Matematik', colorValue: 0xFF6750A4, createdAt: DateTime(2026, 1, 1)),
    );
    await HiveBoxes.tasks.put(
      'tek-gorev',
      TaskModel(
        id: 'tek-gorev',
        title: 'Tek görev',
        subjectId: 's',
        dueDate: day,
        estimatedMinutes: 30,
        createdAt: DateTime(2026, 9, 1),
      ),
    );

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: TasksScreen()),
    ));
    await tester.pump(const Duration(milliseconds: 400));

    // Sağa kaydır (startToEnd) = ertele. Eşiği (%40) net geçen bir mesafe.
    // Dismissible sürükleme bitince kendi "forward" animasyonuyla
    // confirmDismiss'i tetikliyor — tek büyük pump() bu animasyonun
    // ticker'ını başlatmaya yetmiyor, art arda birden çok kare gerekiyor.
    await tester.drag(find.byType(Dismissible).first, const Offset(400, 0));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final postponed = container.read(taskProvider).single;
    expect(postponed.dueDate, day.add(const Duration(days: 1)),
        reason: 'ertelendi');
    expect(postponed.postponeCount, 1);
    expect(find.text('GERİ AL'), findsOneWidget,
        reason: 'ertelemede de silmedeki gibi geri alma sunulmalı');

    await tester.tap(find.text('GERİ AL'));
    await tester.pump(const Duration(milliseconds: 400));

    final restored = container.read(taskProvider).single;
    expect(restored.dueDate, day, reason: 'orijinal tarihe dönmeli');
    expect(restored.postponeCount, 0,
        reason: 'geri alınca erteleme sayacı da geri gitmeli');
  });
}
