import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:hive/src/binary/binary_reader_impl.dart';
import 'package:hive/src/binary/binary_writer_impl.dart';
import 'package:hive/src/registry/type_registry_impl.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/topic_model.dart';

/// Yeni alanların (Hive alanı ekleri) DİSKTEN geri okunması — elle yamalı
/// adapter'ların gerçekten serileştirdiğinin kanıtı.
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_persist_test');
    Hive.init(tempDir.path);
    Hive
      ..registerAdapter(TopicStatusAdapter())
      ..registerAdapter(TopicModelAdapter())
      ..registerAdapter(FocusSessionAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('TopicModel.activityKeys diske yazılıp geri okunur', () async {
    var box = await Hive.openBox<TopicModel>('t_persist');
    await box.put(
      'a',
      TopicModel(
        id: 'a',
        subjectId: 's',
        name: 'Türev',
        status: TopicStatus.studied,
        createdAt: DateTime(2026, 9, 1),
        activityKeys: ['run:1', 'task:2'],
      ),
    );
    await box.close();
    box = await Hive.openBox<TopicModel>('t_persist');
    expect(box.get('a')!.activityKeys, ['run:1', 'task:2']);
    expect(box.get('a')!.status, TopicStatus.studied);
  });

  test('FocusSession feeling/taskId/runId diske yazılıp geri okunur', () async {
    var box = await Hive.openBox<FocusSession>('f_persist');
    await box.put(
      'a',
      FocusSession(
        id: 'a',
        endedAt: DateTime(2026, 9, 1, 10),
        minutes: 25,
        mode: 'serbest',
        topicId: 't',
        feeling: FocusFeeling.hard,
        taskId: 'task',
        runId: 'run',
      ),
    );
    await box.close();
    box = await Hive.openBox<FocusSession>('f_persist');
    final s = box.get('a')!;
    expect(s.feeling, FocusFeeling.hard);
    expect(s.taskId, 'task');
    expect(s.runId, 'run');
    expect(s.runKey, 'run');
  });

  test('ESKİ biçimde (yeni alanlar yokken) yazılmış kayıtlar bozulmadan okunur',
      () {
    final registry = Hive as TypeRegistryImpl;

    // Eski TopicModel: yalnız 6 alan (0..5), activityKeys yok.
    final tw = BinaryWriterImpl(registry)
      ..writeByte(6)
      ..writeByte(0)
      ..write('t1')
      ..writeByte(1)
      ..write('s1')
      ..writeByte(2)
      ..write('Türev')
      ..writeByte(3)
      ..write(TopicStatus.studied)
      ..writeByte(4)
      ..write(DateTime(2026, 1, 1))
      ..writeByte(5)
      ..write(DateTime(2026, 2, 1));
    final topic = TopicModelAdapter()
        .read(BinaryReaderImpl(tw.toBytes(), registry));
    expect(topic.name, 'Türev');
    expect(topic.status, TopicStatus.studied);
    expect(topic.activityKeys, isEmpty);

    // Eski FocusSession: yalnız 7 alan (0..6), feeling/taskId/runId yok.
    final fw = BinaryWriterImpl(registry)
      ..writeByte(7)
      ..writeByte(0)
      ..write('f1')
      ..writeByte(1)
      ..write(DateTime(2026, 1, 1, 10))
      ..writeByte(2)
      ..write(25)
      ..writeByte(3)
      ..write('pomodoro')
      ..writeByte(4)
      ..write('s1')
      ..writeByte(5)
      ..write('t1')
      ..writeByte(6)
      ..write('not');
    final session = FocusSessionAdapter()
        .read(BinaryReaderImpl(fw.toBytes(), registry));
    expect(session.minutes, 25);
    expect(session.note, 'not');
    expect(session.feeling, isNull, reason: 'cevap yoktu — "iyi geçti" değil');
    expect(session.taskId, isNull);
    expect(session.runId, isNull);
    expect(session.runKey, 'f1', reason: 'eski kayıt kendi çalışması sayılır');
  });
}
