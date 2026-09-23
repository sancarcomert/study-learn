import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';

/// "İyileşme anı" (Faz 8) — bir konu önceki denemede zayıf işaretliyken son
/// denemede artık işaretli değil. Gerçek Hive verisiyle uçtan uca.
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_deneme_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(SubjectModelAdapter());
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
    await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName);
    await Hive.openBox<DenemeEntry>(HiveBoxes.denemelerBoxName);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveBoxes.subjectsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.topicsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.denemelerBoxName);
  });

  test('en az 2 deneme yoksa hiçbir ders işaretlenmez', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    c.read(denemeProvider.notifier).addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 1),
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 10, wrong: 2, weakTopicIds: [topicId]),
      ],
    );

    expect(c.read(resolvedWeakTopicsBySubjectProvider), isEmpty);
  });

  test('önceki denemede zayıf, son denemede artık değil → işaretlenir', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    final notifier = c.read(denemeProvider.notifier);
    notifier.addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 1),
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 10, wrong: 2, weakTopicIds: [topicId]),
      ],
    );
    notifier.addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 15),
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 15, wrong: 0, weakTopicIds: const []),
      ],
    );

    final resolved = c.read(resolvedWeakTopicsBySubjectProvider);
    expect(resolved[subjectId], ['Türev']);
  });

  test('son denemede de hâlâ zayıfsa işaretlenmez', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    final notifier = c.read(denemeProvider.notifier);
    notifier.addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 1),
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 10, wrong: 2, weakTopicIds: [topicId]),
      ],
    );
    notifier.addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 15),
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 11, wrong: 2, weakTopicIds: [topicId]),
      ],
    );

    expect(c.read(resolvedWeakTopicsBySubjectProvider), isEmpty);
  });
}
