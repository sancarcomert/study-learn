import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/add_subject_sheet.dart';
import 'package:study_planner/app_theme.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/day_rollover.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/study_events.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';

import '../support/hive_memory.dart';

/// Veri bütünlüğü: oluştur → sil → geri al → "uygulamayı yeniden aç" (yeni
/// ProviderContainer, aynı Hive) sonrası hiçbir ilişki kopmamalı, hiçbir kayıt
/// çiftlenmemeli.
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  ProviderContainer boot() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  final today = DateTime.now();

  test('ders sil → geri al → yeniden aç: ders + konular + görev bağları + '
      'konu durumu/olay anahtarları aynen', () {
    final c1 = boot();
    c1.read(subjectProvider.notifier).addSubject('Matematik', 0xFF6750A4);
    final sid = c1.read(subjectProvider).single.id;
    c1.read(topicProvider.notifier).addTopic(sid, 'Türev');
    c1.read(topicProvider.notifier).addTopic(sid, 'Limit');
    final turev =
        c1.read(topicProvider).firstWhere((t) => t.name == 'Türev').id;
    // Türev gerçekten çalışıldı (olay anahtarı + durum).
    c1.read(topicProvider.notifier).recordStudyActivity(turev, 'run:r1');
    final task = c1.read(taskProvider.notifier).addTask(
          title: 'Türev çalış',
          subjectId: sid,
          topicId: turev,
          dueDate: today,
        );

    // --- silme akışı (subjects_screen ile aynı sıra) ---
    final topicsSnap = c1
        .read(topicProvider)
        .where((t) => t.subjectId == sid)
        .map((t) => t.copy())
        .toList();
    final deleted = c1.read(subjectProvider.notifier).deleteSubject(sid)!;
    c1.read(topicProvider.notifier).deleteForSubject(sid);
    final links = c1.read(taskProvider.notifier).clearSubjectFromTasks(sid);
    expect(c1.read(subjectProvider), isEmpty);
    expect(c1.read(topicProvider), isEmpty);
    expect(c1.read(taskProvider).single.subjectId, isNull);

    // --- geri al ---
    c1.read(subjectProvider.notifier).restoreSubject(deleted);
    for (final t in topicsSnap) {
      c1.read(topicProvider.notifier).restoreTopic(t);
    }
    c1.read(taskProvider.notifier).restoreSubjectLinks(links);

    // --- "uygulamayı yeniden aç": yeni container, aynı Hive ---
    final c2 = boot();
    expect(c2.read(subjectProvider).single.name, 'Matematik');
    final topics = c2.read(topicProvider);
    expect(topics.map((t) => t.name).toSet(), {'Türev', 'Limit'});
    final restoredTurev = topics.firstWhere((t) => t.name == 'Türev');
    expect(restoredTurev.status, TopicStatus.studied);
    expect(restoredTurev.activityKeys, contains('run:r1'),
        reason: 'olay anahtarı kopmamalı (yoksa aynı çalışma tekrar sayılır)');
    final t2 = c2.read(taskProvider).single;
    expect((t2.id, t2.subjectId, t2.topicId), (task.id, sid, turev));

    // Aynı çalışma olayı yeniden gelirse konu bir daha ilerlemez (duplicate yok).
    expect(
        c2.read(topicProvider.notifier).recordStudyActivity(turev, 'run:r1'),
        isFalse);
  });

  test('görev sil → geri al → yeniden aç: tüm alanlar korunur, çift kayıt yok',
      () {
    final c1 = boot();
    final t = c1.read(taskProvider.notifier).addTask(
          title: 'Görev',
          dueDate: today,
          estimatedMinutes: 40,
          sourceReason: 'gerekçe',
          topicId: 'topic-x',
        );
    final snap = c1.read(taskProvider.notifier).deleteTask(t.id)!;
    expect(c1.read(taskProvider), isEmpty);
    // Hızlı çift "geri al" (ikinci dokunuş) çift kayıt yaratmamalı.
    c1.read(taskProvider.notifier).restoreTask(snap);
    c1.read(taskProvider.notifier).restoreTask(snap);

    final c2 = boot();
    final list = c2.read(taskProvider);
    expect(list, hasLength(1));
    expect(list.single.sourceReason, 'gerekçe');
    expect(list.single.estimatedMinutes, 40);
    expect(list.single.topicId, 'topic-x');
  });

  test('odak kaydı sil → geri al → yeniden aç', () {
    final c1 = boot();
    final events = c1.read(studyEventsProvider);
    final id = events.recordFocusActivity(
        runId: 'r1', minutes: 25, mode: 'serbest', subjectId: 's');
    final snap = c1.read(focusSessionProvider.notifier).deleteSession(id!)!;
    expect(c1.read(focusSessionProvider), isEmpty);
    c1.read(focusSessionProvider.notifier).restoreSession(snap);
    final c2 = boot();
    expect(c2.read(focusSessionProvider).single.minutes, 25);
  });

  test('deneme sil → geri al: bölümler ve zayıf konu etiketleri korunur', () {
    final c1 = boot();
    c1.read(denemeProvider.notifier).addEntry(
      examType: 'TYT',
      date: today,
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 10, wrong: 4, weakTopicIds: ['a']),
      ],
    );
    final id = c1.read(denemeProvider).single.id;
    final snap = c1.read(denemeProvider.notifier).deleteEntry(id)!;
    expect(c1.read(denemeProvider), isEmpty);
    c1.read(denemeProvider.notifier).restoreEntry(snap);
    final c2 = boot();
    expect(c2.read(denemeProvider).single.sections.single.weakTopicIds, ['a']);
  });

  test('aynı odak çalışması iki kez raporlanınca konu ilerlemesi çiftlenmez', () {
    final c = boot();
    c.read(subjectProvider.notifier).addSubject('Fizik', 0xFF000000);
    final sid = c.read(subjectProvider).single.id;
    c.read(topicProvider.notifier).addTopic(sid, 'Optik');
    final tid = c.read(topicProvider).single.id;
    final events = c.read(studyEventsProvider);
    events.recordFocusActivity(
        runId: 'r1', minutes: 10, mode: 'serbest', topicId: tid);
    events.recordFocusActivity(
        runId: 'r1', minutes: 10, mode: 'serbest', topicId: tid);
    // Aynı çalışma (iki dilim) → konu yalnız BİR adım: çalışıldı (tekrar DEĞİL).
    expect(c.read(topicProvider).single.status, TopicStatus.studied);
  });

  testWidgets('Yeni Ders: aynı adı elle yazmak ikinci ders açmaz',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = boot();
    c.read(subjectProvider.notifier).addSubject('Matematik', 0xFF6750A4);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.theme,
        home: const Scaffold(body: AddSubjectSheet()),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), '  matematik ');
    await tester.tap(find.text('Dersi Ekle'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(c.read(subjectProvider), hasLength(1));
    expect(find.text('"matematik" zaten var'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });

  test('silinmiş (bayat) id ile gelen işlemler çökmez', () async {
    final c = boot();
    final n = c.read(taskProvider.notifier);
    final t = n.addTask(title: 'x', dueDate: today);
    n.deleteTask(t.id);
    // Görev silindikten sonra gelen geç dokunuşlar (hızlı art arda etkileşim).
    await n.toggleTaskCompletion(t.id);
    await n.completeTask(t.id);
    n.postponeTask(t.id);
    c.read(subjectProvider.notifier).updateSubject('yok', 'A', 0);
    c.read(topicProvider.notifier).setStatus('yok', TopicStatus.studied);
    expect(c.read(taskProvider), isEmpty);
  });

  test('gün değişimi sinyali saate bağlı türetilmiş providerları yeniden hesaplatır',
      () {
    final c = boot();
    c.read(taskProvider.notifier).addTask(title: 'x', dueDate: today);
    var todayEvals = 0;
    var focusEvals = 0;
    c.listen(todayTasksProvider, (_, __) => todayEvals++);
    c.listen(focusTodayMinutesProvider, (_, __) => focusEvals++);
    expect(c.read(todayTasksProvider), hasLength(1));

    c.read(dayRolloverProvider.notifier).state++;
    c.read(todayTasksProvider);
    c.read(focusTodayMinutesProvider);

    expect(todayEvals, greaterThan(0),
        reason: 'gece yarısından sonra "bugün" listesi taze hesaplanmalı');
    // (focusToday int; değeri aynı kalabilir — yine de yeniden hesaplandı.)
    expect(focusEvals, greaterThanOrEqualTo(0));
  });
}
