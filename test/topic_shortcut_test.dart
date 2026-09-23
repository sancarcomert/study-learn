import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_topics_screen.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';
import 'package:study_planner/user_stats_model.dart';

import 'support/hive_memory.dart';

/// Yolculuk D — konu kısayolu: bir konuya dokunmak ÇALIŞMAYI BAŞLATMA niyetidir,
/// çalışılmış saymak değil. Durum yalnız gerçek çalışma olaylarından ilerler.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  Future<ProviderContainer> openTopics(
    WidgetTester tester, {
    List<FocusSession> sessions = const [],
  }) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await HiveBoxes.stats.put(
        'main', UserStatsModel(hasSeenExactAlarmPrompt: true));
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
    for (final s in sessions) {
      await HiveBoxes.focusSessions.put(s.id, s);
    }

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SubjectTopicsScreen(
                      subjectId: 's-mat', subjectName: 'Matematik'),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
      'konuya dokunmak Focus\'u o konuyla açar; konu durumu ve kayıtlar DEĞİŞMEZ',
      (tester) async {
    final c = await openTopics(tester);
    expect(find.text('Başlanmadı'), findsOneWidget);

    await tester.tap(find.text('Bölünebilme'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Focus açıldı, konu bağlamı hazır
    expect(find.text('ODAK SEANSI'), findsOneWidget);
    expect(find.text('Matematik · 25 dk'), findsOneWidget);

    // Niyet ≠ kanıt
    expect(c.read(topicProvider).single.status, TopicStatus.notStarted);
    expect(c.read(topicProvider).single.activityKeys, isEmpty);
    expect(c.read(focusSessionProvider), isEmpty);
  });

  testWidgets(
      'kanıtı olan konuya dokununca gerekçe (neden bu konu) Focus\'a taşınır',
      (tester) async {
    await openTopics(tester, sessions: [
      FocusSession(
        id: 'a',
        endedAt: DateTime.now().subtract(const Duration(days: 3)),
        minutes: 20,
        mode: 'serbest',
        subjectId: 's-mat',
        topicId: 't-b',
        runId: 'r1',
        feeling: FocusFeeling.hard,
      ),
      FocusSession(
        id: 'b',
        endedAt: DateTime.now().subtract(const Duration(days: 1)),
        minutes: 20,
        mode: 'serbest',
        subjectId: 's-mat',
        topicId: 't-b',
        runId: 'r2',
        feeling: FocusFeeling.hard,
      ),
    ]);
    // Liste satırında rozet: üst üste zorlanma
    expect(find.text('Üst üste zorlandın'), findsOneWidget);

    await tester.tap(find.text('Bölünebilme'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bu konuda üst üste zorlandığını söyledin.'),
        findsOneWidget);
  });

  testWidgets(
      '⋮ menüsü: elle düzeltme mümkün ama KANIT/OLAY değil (activityKeys boş kalır)',
      (tester) async {
    final c = await openTopics(tester);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Kaydı elle düzelt'), findsOneWidget);
    await tester.tap(find.text('Çalışıldı').last);
    await tester.pumpAndSettle();

    final topic = c.read(topicProvider).single;
    expect(topic.status, TopicStatus.studied);
    expect(topic.activityKeys, isEmpty,
        reason: 'elle düzeltme çalışma olayı değildir');
  });
}
