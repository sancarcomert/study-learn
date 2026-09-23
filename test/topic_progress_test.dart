import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_session_provider.dart';
import 'package:study_planner/study_events.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_progress.dart';
import 'package:study_planner/topic_provider.dart';

import 'support/hive_memory.dart';

/// Konu durumunun TEK doğruluk kaynağı: olay tabanlı geçiş. Bir gerçek-dünya
/// olayı en çok BİR adım ilerletir; aynı olay iki kez sayılmaz.
void main() {
  group('TopicProgress.applyStudyActivity (saf durum makinesi)', () {
    test('yeni olay: başlanmadı → çalışıldı', () {
      final r = TopicProgress.applyStudyActivity(
        status: TopicStatus.notStarted,
        keys: const [],
        eventKey: 'run:a',
      );
      expect(r.status, TopicStatus.studied);
      expect(r.keys, ['run:a']);
      expect(r.isNewEvent, isTrue);
    });

    test('AYRI ikinci olay: çalışıldı → tekrar edildi', () {
      final r = TopicProgress.applyStudyActivity(
        status: TopicStatus.studied,
        keys: const ['run:a'],
        eventKey: 'run:b',
      );
      expect(r.status, TopicStatus.reviewed);
    });

    test('tekrar edildi geri düşmez, ilerlemez de', () {
      final r = TopicProgress.applyStudyActivity(
        status: TopicStatus.reviewed,
        keys: const ['run:a', 'run:b'],
        eventKey: 'run:c',
      );
      expect(r.status, TopicStatus.reviewed);
    });

    test('AYNI olay anahtarı ikinci kez hiçbir şeyi değiştirmez (idempotent)', () {
      final r = TopicProgress.applyStudyActivity(
        status: TopicStatus.studied,
        keys: const ['run:a'],
        eventKey: 'run:a',
      );
      expect(r.status, TopicStatus.studied);
      expect(r.isNewEvent, isFalse);
    });

    test('anahtar listesi sınırsız büyümez', () {
      var keys = <String>[];
      var status = TopicStatus.notStarted;
      for (var i = 0; i < TopicProgress.maxKeys + 20; i++) {
        final r = TopicProgress.applyStudyActivity(
            status: status, keys: keys, eventKey: 'e$i');
        status = r.status;
        keys = r.keys;
      }
      expect(keys.length, TopicProgress.maxKeys);
      expect(keys.last, 'e${TopicProgress.maxKeys + 19}');
    });
  });

  group('gerçek provider\'larla olay akışı', () {
    setUp(openMemoryBoxes);
    tearDown(closeMemoryBoxes);

    ({ProviderContainer c, String subjectId, String topicId}) setup() {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(subjectProvider.notifier).addSubject('Matematik', 0);
      final subjectId = c.read(subjectProvider).first.id;
      c.read(topicProvider.notifier).addTopic(subjectId, 'Bölünebilme');
      return (
        c: c,
        subjectId: subjectId,
        topicId: c.read(topicProvider).first.id,
      );
    }

    TopicStatus statusOf(ProviderContainer c, String id) =>
        c.read(topicProvider).firstWhere((t) => t.id == id).status;

    test(
        'REGRESYON: Focus çalışması + o çalışmayla tamamlanan görev = TEK adım '
        '("çalışıldı"), "tekrar edildi" DEĞİL', () async {
      final t = setup();
      final task = t.c.read(taskProvider.notifier).addTask(
            title: 'Bölünebilme',
            subjectId: t.subjectId,
            dueDate: DateTime.now(),
            estimatedMinutes: 25,
            topicId: t.topicId,
          );
      final events = t.c.read(studyEventsProvider);
      final runId = events.newRunId();

      // Focus'ta 15 dk ölçüldü (göreve ve konuya bağlı).
      events.recordFocusActivity(
        runId: runId,
        minutes: 15,
        mode: 'serbest',
        subjectId: t.subjectId,
        topicId: t.topicId,
        taskId: task.id,
      );
      expect(statusOf(t.c, t.topicId), TopicStatus.studied);

      // Aynı çalışmayla görev de tamamlanır (Bitir → görevi tamamla).
      await events.finishFocusRun(
        runId: runId,
        topicId: t.topicId,
        taskId: task.id,
        completeTask: true,
      );

      expect(statusOf(t.c, t.topicId), TopicStatus.studied,
          reason: 'tek gerçek çalışma tek adım ilerletir');
      final done = t.c.read(taskProvider).single;
      expect(done.isCompleted, isTrue);
      // Gerçek süre canonical kaynaktan (FocusSession), arayüz bayrağından değil.
      expect(done.actualMinutes, 15);
    });

    test('çok dilimli (Pomodoro/checkpoint) TEK çalışma konuyu bir adımdan fazla ilerletmez',
        () {
      final t = setup();
      final events = t.c.read(studyEventsProvider);
      final runId = events.newRunId();
      for (var i = 0; i < 3; i++) {
        events.recordFocusActivity(
          runId: runId,
          minutes: 25,
          mode: 'pomodoro',
          subjectId: t.subjectId,
          topicId: t.topicId,
        );
      }
      expect(t.c.read(focusSessionProvider).length, 3);
      expect(statusOf(t.c, t.topicId), TopicStatus.studied);
    });

    test('AYRI ikinci çalışma gerçekten "tekrar edildi" olur', () {
      final t = setup();
      final events = t.c.read(studyEventsProvider);
      events.recordFocusActivity(
          runId: events.newRunId(),
          minutes: 20,
          mode: 'serbest',
          subjectId: t.subjectId,
          topicId: t.topicId);
      events.recordFocusActivity(
          runId: events.newRunId(),
          minutes: 20,
          mode: 'serbest',
          subjectId: t.subjectId,
          topicId: t.topicId);
      expect(statusOf(t.c, t.topicId), TopicStatus.reviewed);
    });

    test('REGRESYON: görev tamamlamayı aç-kapa yapmak konuyu tekrar tekrar ilerletmez',
        () async {
      final t = setup();
      final task = t.c.read(taskProvider.notifier).addTask(
            title: 'Bölünebilme',
            subjectId: t.subjectId,
            dueDate: DateTime.now(),
            topicId: t.topicId,
          );
      final notifier = t.c.read(taskProvider.notifier);

      await notifier.toggleTaskCompletion(task.id); // tamam
      expect(statusOf(t.c, t.topicId), TopicStatus.studied);
      await notifier.toggleTaskCompletion(task.id); // geri al
      await notifier.toggleTaskCompletion(task.id); // yine tamam
      expect(statusOf(t.c, t.topicId), TopicStatus.studied,
          reason: 'aynı görev = aynı olay');
    });

    test('Focus\'ta zaten ölçülen görevi sonradan daireye dokunup tamamlamak ikinci olay DEĞİL',
        () async {
      final t = setup();
      final task = t.c.read(taskProvider.notifier).addTask(
            title: 'Bölünebilme',
            subjectId: t.subjectId,
            dueDate: DateTime.now(),
            topicId: t.topicId,
          );
      final events = t.c.read(studyEventsProvider);
      events.recordFocusActivity(
        runId: events.newRunId(),
        minutes: 30,
        mode: 'serbest',
        subjectId: t.subjectId,
        topicId: t.topicId,
        taskId: task.id,
      );
      // Focus'tan "Şimdilik geç" ile çıkıldı, görev sonra elle işaretlendi.
      await t.c.read(taskProvider.notifier).toggleTaskCompletion(task.id);

      expect(statusOf(t.c, t.topicId), TopicStatus.studied);
      expect(t.c.read(taskProvider).single.actualMinutes, 30);
    });

    test('bağımsız (Focus\'suz) görev tamamlama = bir çalışma beyanı: çalışıldı',
        () async {
      final t = setup();
      final task = t.c.read(taskProvider.notifier).addTask(
            title: 'Bölünebilme',
            subjectId: t.subjectId,
            dueDate: DateTime.now(),
            topicId: t.topicId,
          );
      await t.c.read(taskProvider.notifier).toggleTaskCompletion(task.id);
      expect(statusOf(t.c, t.topicId), TopicStatus.studied);
      expect(t.c.read(taskProvider).single.actualMinutes, isNull,
          reason: 'ölçülmemiş süre uydurulmaz');
    });

    test('bir konuya dokunmak/seçmek durum DEĞİŞTİRMEZ; yalnız elle düzeltme yapar '
        've olay üretmez', () {
      final t = setup();
      final notifier = t.c.read(topicProvider.notifier);
      expect(statusOf(t.c, t.topicId), TopicStatus.notStarted);

      notifier.setStatus(t.topicId, TopicStatus.studied); // elle düzeltme
      final topic = t.c.read(topicProvider).single;
      expect(topic.status, TopicStatus.studied);
      expect(topic.activityKeys, isEmpty, reason: 'elle düzeltme kanıt/olay değildir');

      // Elle "çalışıldı" denmiş konuda İLK gerçek çalışma, bir tekrardır.
      final events = t.c.read(studyEventsProvider);
      events.recordFocusActivity(
          runId: events.newRunId(),
          minutes: 10,
          mode: 'serbest',
          subjectId: t.subjectId,
          topicId: t.topicId);
      expect(statusOf(t.c, t.topicId), TopicStatus.reviewed);
    });

    test('1 dakikadan kısa çalışma ölçülmüş etkinlik değildir — konu değişmez', () {
      final t = setup();
      final events = t.c.read(studyEventsProvider);
      final id = events.recordFocusActivity(
          runId: events.newRunId(),
          minutes: 0,
          mode: 'serbest',
          subjectId: t.subjectId,
          topicId: t.topicId);
      expect(id, isNull);
      expect(statusOf(t.c, t.topicId), TopicStatus.notStarted);
    });

    test('olay anahtarları kalıcı: kutu yeniden açılınca aynı olay yine sayılmaz',
        () async {
      final t = setup();
      final events = t.c.read(studyEventsProvider);
      final runId = events.newRunId();
      events.recordFocusActivity(
          runId: runId,
          minutes: 10,
          mode: 'serbest',
          subjectId: t.subjectId,
          topicId: t.topicId);

      // Yeni bir container (uygulama yeniden açıldı) aynı kutulardan okur.
      final c2 = ProviderContainer();
      addTearDown(c2.dispose);
      expect(c2.read(topicProvider).single.activityKeys,
          [TopicProgress.focusRunKey(runId)]);
      c2.read(studyEventsProvider).recordFocusActivity(
          runId: runId, // aynı çalışmanın geç gelen dilimi
          minutes: 5,
          mode: 'serbest',
          subjectId: t.subjectId,
          topicId: t.topicId);
      expect(statusOf(c2, t.topicId), TopicStatus.studied);
    });
  });
}
