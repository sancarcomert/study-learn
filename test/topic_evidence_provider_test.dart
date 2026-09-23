import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_provider.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/topic_evidence.dart';
import 'package:study_planner/topic_evidence_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';

/// Bölüm 1 — rozet TEK kaynaktan (PlanBuilder/StudyAdvisor/Stats'ın da
/// okuduğu aynı deneme sinyalleri) türer ve GERÇEK Hive verisiyle otomatik
/// güncellenir; ayrı/çelişebilecek bir "rozet mantığı" yok.
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_topic_evidence_test');
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

  test('deneme yokken hiçbir konunun rozeti yok', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    expect(c.read(topicEvidenceProvider)[topicId]?.hasBadge ?? false, isFalse);
  });

  test('deneme konuyu zayıf işaretleyince rozet OTOMATİK belirir', () {
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
            subject: 'Matematik', correct: 16, wrong: 0, weakTopicIds: [topicId]),
      ],
    );

    final e = c.read(topicEvidenceProvider)[topicId];
    expect(e?.state, TopicEvidenceState.weakConfirmed);
  });

  test('SONRAKİ deneme konuyu artık zayıf göstermezse rozet OTOMATİK '
      '"düzeliyor"ya döner — manuel bir güncelleme gerekmez', () {
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
            subject: 'Matematik', correct: 16, wrong: 0, weakTopicIds: [topicId]),
      ],
    );
    expect(c.read(topicEvidenceProvider)[topicId]?.state,
        TopicEvidenceState.weakConfirmed);

    notifier.addEntry(
      examType: 'TYT',
      date: DateTime(2026, 9, 15),
      sections: [
        DenemeSectionScore(
            subject: 'Matematik', correct: 20, wrong: 0, weakTopicIds: const []),
      ],
    );

    final e = c.read(topicEvidenceProvider)[topicId];
    expect(e?.state, TopicEvidenceState.improving);
    expect(e?.label, 'Düzeliyor');
  });

  test('konu "tekrar edildi" ama 14+ gün dokunulmadıysa needsReview', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    final topicId = c.read(topicProvider).first.id;

    c.read(topicProvider.notifier).setStatus(topicId, TopicStatus.studied);
    c.read(topicProvider.notifier).setStatus(topicId, TopicStatus.reviewed);
    // updatedAt'i geçmişe zorla — gerçek akışta zaman geçmesiyle olur.
    final topic = c.read(topicProvider).firstWhere((t) => t.id == topicId);
    topic.updatedAt = DateTime.now().subtract(const Duration(days: 20));
    topic.save();

    final e = c.read(topicEvidenceProvider)[topicId];
    expect(e?.state, TopicEvidenceState.needsReview);
  });
}
