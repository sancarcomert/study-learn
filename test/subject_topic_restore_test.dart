import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_provider.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/topic_provider.dart';

/// Beta-öncesi QA fix — "Ders silinsin mi?" diyaloğu "kısa süreliğine geri
/// alabilirsin" diyor; bu, o dersin konularını da kapsamalı. Önceden Geri Al
/// yalnız dersi geri getiriyor, deleteForSubject'in sildiği konular kalıcı
/// olarak kayboluyordu (bkz. subjects_screen.dart'taki düzeltme notu). Bu
/// test, konuların SİLİNMEDEN ÖNCE alınan bağımsız kopyasının doğru şekilde
/// geri eklendiğini doğrular — subjects_screen.dart'ın izlediği aynı akış.
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_subject_restore_test');
    Hive.init(tempDir.path);
    Hive.registerAdapter(SubjectModelAdapter());
    Hive.registerAdapter(TopicStatusAdapter());
    Hive.registerAdapter(TopicModelAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.openBox<SubjectModel>(HiveBoxes.subjectsBoxName);
    await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveBoxes.subjectsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.topicsBoxName);
  });

  test(
      'ders silinip "geri al" yapıldığında konuları da (durumuyla birlikte) '
      'geri döner', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    c.read(subjectProvider.notifier).addSubject('Matematik', 0);
    final subjectId = c.read(subjectProvider).first.id;
    c.read(topicProvider.notifier).addTopic(subjectId, 'Türev');
    c.read(topicProvider.notifier).addTopic(subjectId, 'İntegral');
    final turevId = c
        .read(topicProvider)
        .firstWhere((t) => t.name == 'Türev')
        .id;
    // Bir konu "tekrar edildi" durumuna ilerlesin — restore sonrası bu
    // durumun da korunduğunu doğrulamak için (yalnız isim değil).
    c.read(topicProvider.notifier).setStatus(turevId, TopicStatus.studied);
    c.read(topicProvider.notifier).setStatus(turevId, TopicStatus.reviewed);

    // subjects_screen.dart'ın izlediği TAM akış: önce (silinmeden ÖNCE)
    // bağımsız bir kopya al, sonra sil.
    final topicsSnapshot = c
        .read(topicProvider)
        .where((t) => t.subjectId == subjectId)
        .map((t) => TopicModel(
              id: t.id,
              subjectId: t.subjectId,
              name: t.name,
              status: t.status,
              createdAt: t.createdAt,
              updatedAt: t.updatedAt,
            ))
        .toList();

    final deletedSubject = c.read(subjectProvider.notifier).deleteSubject(subjectId);
    c.read(topicProvider.notifier).deleteForSubject(subjectId);

    expect(deletedSubject, isNotNull);
    expect(c.read(topicProvider), isEmpty); // gerçekten silindi

    // "GERİ AL"
    c.read(subjectProvider.notifier).restoreSubject(deletedSubject!);
    for (final t in topicsSnapshot) {
      c.read(topicProvider.notifier).restoreTopic(t);
    }

    final restoredTopics = c.read(topicProvider);
    expect(restoredTopics.length, 2);
    expect(restoredTopics.map((t) => t.name), containsAll(['Türev', 'İntegral']));
    expect(
      restoredTopics.firstWhere((t) => t.name == 'Türev').status,
      TopicStatus.reviewed, // durum da korunmuş olmalı, sıfırlanmamalı
    );
  });
}
