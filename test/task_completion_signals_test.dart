import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';

/// Faz 3 — görev tamamlama → sonuç bağlantısının kalitesi:
/// 1) actualMinutes/estimatedMinutes oranı gerçekten planlamayı etkiler
///    (difficultTopicNamesBySubjectProvider).
/// 2) Görev tamamlama (çaba/STUDIED) sahte bir "anlaşıldı/UNDERSTOOD" ya da
///    "iyileşti/IMPROVED" sinyali ÜRETMEZ — bu yalnız GERÇEK deneme
///    sonucundan (examWeakTopicsBySubjectProvider) gelir.
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_completion_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(SubjectModelAdapter());
    Hive.registerAdapter(TaskPriorityAdapter());
    Hive.registerAdapter(TopicDifficultyAdapter());
    Hive.registerAdapter(TaskModelAdapter());
    Hive.registerAdapter(TopicStatusAdapter());
    Hive.registerAdapter(TopicModelAdapter());
    Hive.registerAdapter(DenemeSectionScoreAdapter());
    Hive.registerAdapter(DenemeEntryAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.openBox<SubjectModel>(HiveBoxes.subjectsBoxName);
    await Hive.openBox<TaskModel>(HiveBoxes.tasksBoxName);
    await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName);
    await Hive.openBox<DenemeEntry>(HiveBoxes.denemelerBoxName);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveBoxes.subjectsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.tasksBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.topicsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.denemelerBoxName);
  });

  test('actualMinutes tahminden %40+ uzunsa konu "zor çıktı" listesine girer',
      () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    c.read(taskProvider.notifier).addTask(
          title: 'Türev çalış',
          subjectId: subjectId,
          dueDate: DateTime(2026, 9, 1),
          estimatedMinutes: 30,
          topicId: topicId,
        );
    final task = c.read(taskProvider).first;
    task.actualMinutes = 60; // 2x tahmin
    task.isCompleted = true;

    // repository'yi bypass etmeden state'i tetiklemek için doğrudan provider
    // üzerinden okunan referans zaten Hive nesnesi — save() ile kalıcılaşır.
    task.save();
    // Provider'ın yeniden okuması için taskProvider'ı invalidate edip
    // tekrar okuyoruz (repository Hive box'ından okur).
    final refreshed = c.read(taskRepositoryProvider).getAllTasks();
    expect(refreshed.first.actualMinutes, 60);

    final flagged = c.read(difficultTopicNamesBySubjectProvider);
    // Not: provider taskProvider'ı watch ediyor; test container'da state
    // az önceki addTask çağrısıyla zaten güncel task nesnesini tutuyor
    // (aynı referans), actualMinutes/isCompleted mutasyonu ekstra bir
    // action olmadan da yansır.
    expect(flagged[subjectId], contains('Türev'));
  });

  test('tahminin altında/yakınında kalan süre konuyu zor listesine sokmaz',
      () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    c.read(taskProvider.notifier).addTask(
          title: 'Türev çalış',
          subjectId: subjectId,
          dueDate: DateTime(2026, 9, 1),
          estimatedMinutes: 30,
          topicId: topicId,
        );
    final task = c.read(taskProvider).first;
    task.actualMinutes = 32; // ~%7 fazla — gürültü
    task.save();

    final flagged = c.read(difficultTopicNamesBySubjectProvider);
    expect(flagged[subjectId], isNull);
  });

  test(
      'görev tamamlama konuyu "çalışıldı" yapar ama sahte bir "artık zayıf '
      'değil" sinyali ÜRETMEZ — bu yalnız gerçek denemeden gelir', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    // GERÇEK deneme kanıtı: Türev zayıf.
    c.read(denemeProvider.notifier).addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 1),
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 16, wrong: 0, weakTopicIds: [topicId]),
      ],
    );
    expect(c.read(examWeakTopicNamesBySubjectProvider)[subjectId],
        contains('Türev'));

    // Öğrenci konuyu ÇALIŞIR (effort/STUDIED) — deneme eklenmedi.
    c.read(topicProvider.notifier).setStatus(topicId, TopicStatus.studied);
    c.read(topicProvider.notifier).setStatus(topicId, TopicStatus.reviewed);
    expect(
      c.read(topicProvider).firstWhere((t) => t.id == topicId).status,
      TopicStatus.reviewed,
    );

    // examWeakTopics HÂLÂ Türev'i gösteriyor — yalnız ÇALIŞMAK (kanıt
    // olmadan) zayıflığı otomatik silmiyor, "STUDIED ≠ IMPROVED".
    expect(c.read(examWeakTopicNamesBySubjectProvider)[subjectId],
        contains('Türev'));
    // Ve hiçbir "iyileşme" sinyali yok — yalnız yeni bir DENEME bunu
    // üretebilir (bkz. resolvedWeakTopicsBySubjectProvider).
    expect(c.read(resolvedWeakTopicsBySubjectProvider)[subjectId], isNull);
  });
}
