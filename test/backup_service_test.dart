import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:study_planner/backup_service.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';

/// A1 — yerel yedek. Kritik güvenlik yolu: dışa aktar → JSON → geri yükle
/// sırasında hiçbir alan kaybolmamalı, bozuk dosya reddedilmeli.
void main() {
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('pusula_backup_test');
    Hive.init(tempDir.path);
    Hive
      ..registerAdapter(SubjectModelAdapter())
      ..registerAdapter(TaskPriorityAdapter())
      ..registerAdapter(TopicDifficultyAdapter())
      ..registerAdapter(TaskModelAdapter())
      ..registerAdapter(UserStatsModelAdapter())
      ..registerAdapter(TopicStatusAdapter())
      ..registerAdapter(TopicModelAdapter())
      ..registerAdapter(FocusSessionAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.openBox<SubjectModel>(HiveBoxes.subjectsBoxName);
    await Hive.openBox<TaskModel>(HiveBoxes.tasksBoxName);
    await Hive.openBox<UserStatsModel>(HiveBoxes.statsBoxName);
    await Hive.openBox<TopicModel>(HiveBoxes.topicsBoxName);
    await Hive.openBox<FocusSession>(HiveBoxes.focusSessionsBoxName);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveBoxes.subjectsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.tasksBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.statsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.topicsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.focusSessionsBoxName);
  });

  Future<void> seed() async {
    await HiveBoxes.subjects.put(
      's1',
      SubjectModel(
        id: 's1',
        name: 'Matematik · İ ğ ü ş ö ç',
        colorValue: 0xFFA79FC9,
        createdAt: DateTime(2026, 3, 1),
      ),
    );
    await HiveBoxes.tasks.put(
      't1',
      TaskModel(
        id: 't1',
        title: 'Türev tekrar',
        subjectId: 's1',
        dueDate: DateTime(2026, 9, 12),
        isCompleted: true,
        priority: TaskPriority.high,
        createdAt: DateTime(2026, 9, 1),
        completedAt: DateTime(2026, 9, 11, 20, 30),
        scheduledTime: null,
        estimatedMinutes: 45,
        difficulty: TopicDifficulty.hard,
      ),
    );
    await HiveBoxes.tasks.put(
      't2',
      TaskModel(
        id: 't2',
        title: 'Saatsiz görev',
        dueDate: DateTime(2026, 9, 13),
        createdAt: DateTime(2026, 9, 2),
      ),
    );
    await HiveBoxes.topics.put(
      'k1',
      TopicModel(
        id: 'k1',
        subjectId: 's1',
        name: 'İntegral',
        status: TopicStatus.reviewed,
        createdAt: DateTime(2026, 3, 2),
        updatedAt: DateTime(2026, 9, 5),
      ),
    );
    await HiveBoxes.focusSessions.put(
      'f1',
      FocusSession(
        id: 'f1',
        endedAt: DateTime(2026, 9, 10, 18),
        minutes: 25,
        mode: 'pomodoro',
      ),
    );
    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        currentStreak: 4,
        longestStreak: 9,
        lastCompletedDate: DateTime(2026, 9, 10),
        dailyGoal: 2,
        freezesAvailable: 1,
        totalCompletedTasks: 30,
        totalStudyMinutes: 900,
        hasCompletedOnboarding: true,
        userName: 'Ayşe',
        examDate: DateTime(2027, 6, 20),
        focusMinutes: 125,
        hasSeenTaskHints: true,
      ),
    );
  }

  test('dışa aktar → JSON → geri yükle: tüm alanlar korunur', () async {
    await seed();

    // Gerçek yol: map -> jsonEncode -> jsonDecode -> import.
    final json = BackupService.exportToJsonString();
    final summary = await BackupService.importFromJsonString(json);

    expect(summary.subjects, 1);
    expect(summary.tasks, 2);
    expect(summary.topics, 1);
    expect(summary.focusSessions, 1);

    final subject = HiveBoxes.subjects.get('s1')!;
    expect(subject.name, 'Matematik · İ ğ ü ş ö ç');
    expect(subject.colorValue, 0xFFA79FC9);
    expect(subject.createdAt, DateTime(2026, 3, 1));

    final t1 = HiveBoxes.tasks.get('t1')!;
    expect(t1.title, 'Türev tekrar');
    expect(t1.isCompleted, true);
    expect(t1.priority, TaskPriority.high);
    expect(t1.difficulty, TopicDifficulty.hard);
    expect(t1.completedAt, DateTime(2026, 9, 11, 20, 30));
    expect(t1.estimatedMinutes, 45);

    final t2 = HiveBoxes.tasks.get('t2')!;
    expect(t2.subjectId, isNull);
    expect(t2.scheduledTime, isNull);
    expect(t2.estimatedMinutes, isNull);

    final topic = HiveBoxes.topics.get('k1')!;
    expect(topic.name, 'İntegral');
    expect(topic.status, TopicStatus.reviewed);
    expect(topic.updatedAt, DateTime(2026, 9, 5));

    final focus = HiveBoxes.focusSessions.get('f1')!;
    expect(focus.minutes, 25);
    expect(focus.mode, 'pomodoro');

    final stats = HiveBoxes.stats.get('main')!;
    expect(stats.currentStreak, 4);
    expect(stats.longestStreak, 9);
    expect(stats.dailyGoal, 2);
    expect(stats.userName, 'Ayşe');
    expect(stats.examDate, DateTime(2027, 6, 20));
    expect(stats.focusMinutes, 125);
    expect(stats.hasSeenTaskHints, true);
  });

  test('geri yükleme mevcut veriyi tamamen değiştirir', () async {
    await seed();
    final json = BackupService.exportToJsonString();

    // Farklı bir duruma geç.
    await HiveBoxes.subjects.put(
      's2',
      SubjectModel(
        id: 's2',
        name: 'Fizik',
        colorValue: 0xFF8FB39A,
        createdAt: DateTime(2026, 4, 1),
      ),
    );
    await HiveBoxes.tasks.clear();

    await BackupService.importFromJsonString(json);

    expect(HiveBoxes.subjects.keys.toSet(), {'s1'});
    expect(HiveBoxes.tasks.length, 2);
  });

  test('Pusula yedeği olmayan dosya reddedilir', () async {
    await seed();
    expect(
      () => BackupService.importFromJsonString('{"format":"baska-app"}'),
      throwsA(isA<BackupException>()),
    );
    expect(
      () => BackupService.importFromJsonString('bu json bile değil'),
      throwsA(isA<BackupException>()),
    );
  });

  test('daha yeni şema sürümü reddedilir', () async {
    final future = jsonEncode({
      'format': 'pusula-backup',
      'schemaVersion': BackupService.schemaVersion + 1,
      'subjects': [],
    });
    expect(
      () => BackupService.importFromJsonString(future),
      throwsA(isA<BackupException>()),
    );
  });

  test('eksik/boş bölümler sorunsuz geri yüklenir', () async {
    final minimal = jsonEncode({
      'format': 'pusula-backup',
      'schemaVersion': 1,
    });
    final summary = await BackupService.importFromJsonString(minimal);
    expect(summary.subjects, 0);
    expect(summary.tasks, 0);
    expect(HiveBoxes.subjects.isEmpty, true);
  });
}
