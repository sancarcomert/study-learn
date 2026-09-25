import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/backup_service.dart';
import 'package:study_planner/daily_closeout_model.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';

import '../support/hive_memory.dart';

/// Yedekle → sil → geri yükle: HER modelin HER alanı (varsayılan olmayan
/// değerlerle) korunmalı. Önceden deneme "zayıf konu" etiketleri, bonusXp ve
/// zayıf-ders beyanı sessizce kayboluyordu (P1 veri kaybı).
void main() {
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  test('her alan yedekten geri yüklenince aynen döner', () async {
    final t0 = DateTime(2026, 9, 1, 8, 30);
    await HiveBoxes.subjects.put(
        's1',
        SubjectModel(
            id: 's1', name: 'Matematik', colorValue: 0xFF123456, createdAt: t0));
    await HiveBoxes.topics.put(
        't1',
        TopicModel(
          id: 't1',
          subjectId: 's1',
          name: 'Türev',
          status: TopicStatus.reviewed,
          createdAt: t0,
          updatedAt: t0.add(const Duration(days: 2)),
          activityKeys: const ['run:a', 'task:b'],
        ));
    await HiveBoxes.tasks.put(
        'k1',
        TaskModel(
          id: 'k1',
          title: 'Görev',
          subjectId: 's1',
          dueDate: t0,
          isCompleted: true,
          priority: TaskPriority.high,
          createdAt: t0,
          completedAt: t0.add(const Duration(hours: 5)),
          scheduledTime: t0.add(const Duration(hours: 1)),
          estimatedMinutes: 45,
          difficulty: TopicDifficulty.hard,
          recurringGroupId: 'g1',
          recurrenceRule: 'weekly',
          topicId: 't1',
          postponeCount: 3,
          actualMinutes: 52,
          systemRescheduleCount: 2,
          sourceReason: 'Denemede yanlış yapmıştın',
        ));
    await HiveBoxes.focusSessions.put(
        'f1',
        FocusSession(
          id: 'f1',
          endedAt: t0,
          minutes: 33,
          mode: 'pomodoro',
          subjectId: 's1',
          topicId: 't1',
          note: 'not',
          feeling: 2,
          taskId: 'k1',
          runId: 'r1',
        ));
    await HiveBoxes.dailyCloseouts.put(
        'c1',
        DailyCloseout(
          id: 'c1',
          date: t0,
          intent: 'yarın',
          completedTasks: 4,
          focusMinutes: 77,
          closedAt: t0.add(const Duration(hours: 12)),
        ));
    await HiveBoxes.denemeler.put(
        'd1',
        DenemeEntry(
          id: 'd1',
          examType: 'AYT',
          name: 'Deneme 3',
          date: t0,
          sections: [
            DenemeSectionScore(
              subject: 'Matematik',
              correct: 20,
              wrong: 8,
              blank: 4,
              weakTopicIds: ['t1', 't-x'],
            ),
          ],
        ));
    await HiveBoxes.stats.put(
        'main',
        UserStatsModel(
          currentStreak: 5,
          longestStreak: 9,
          lastCompletedDate: t0,
          dailyGoal: 3,
          freezesAvailable: 2,
          totalCompletedTasks: 11,
          totalStudyMinutes: 640,
          hasCompletedOnboarding: true,
          userName: 'Ada',
          hasSeenNotificationPrompt: true,
          examDate: DateTime(2027, 6, 20),
          focusMinutes: 1234,
          hasSeenTaskHints: true,
          gradeLevel: 12,
          hasSeenExactAlarmPrompt: true,
          hasAddedFirstTask: true,
          targetNetTYT: 88.5,
          targetNetAYT: 61.25,
          lastCarryOverPromptDate: t0,
          themeMode: 'dark',
          bonusXp: 480,
          selfReportedWeakSubjectName: 'Fizik',
        ));

    final json = BackupService.exportToJsonString();

    // Her şeyi sil, yedekten geri yükle.
    for (final clear in [
      HiveBoxes.subjects.clear,
      HiveBoxes.topics.clear,
      HiveBoxes.tasks.clear,
      HiveBoxes.focusSessions.clear,
      HiveBoxes.dailyCloseouts.clear,
      HiveBoxes.denemeler.clear,
      HiveBoxes.stats.clear,
    ]) {
      await clear();
    }
    final summary = await BackupService.importFromJsonString(json);
    expect(summary.subjects, 1);

    final s = HiveBoxes.subjects.get('s1')!;
    expect((s.name, s.colorValue, s.createdAt), ('Matematik', 0xFF123456, t0));

    final t = HiveBoxes.topics.get('t1')!;
    expect(t.status, TopicStatus.reviewed);
    expect(t.updatedAt, t0.add(const Duration(days: 2)));
    expect(t.activityKeys, ['run:a', 'task:b']);

    final k = HiveBoxes.tasks.get('k1')!;
    expect(k.isCompleted, isTrue);
    expect(k.priority, TaskPriority.high);
    expect(k.completedAt, t0.add(const Duration(hours: 5)));
    expect(k.scheduledTime, t0.add(const Duration(hours: 1)));
    expect(k.estimatedMinutes, 45);
    expect(k.difficulty, TopicDifficulty.hard);
    expect((k.recurringGroupId, k.recurrenceRule), ('g1', 'weekly'));
    expect(k.topicId, 't1');
    expect((k.postponeCount, k.actualMinutes, k.systemRescheduleCount),
        (3, 52, 2));
    expect(k.sourceReason, 'Denemede yanlış yapmıştın');

    final f = HiveBoxes.focusSessions.get('f1')!;
    expect((f.minutes, f.mode, f.feeling, f.taskId, f.runId, f.note),
        (33, 'pomodoro', 2, 'k1', 'r1', 'not'));
    expect((f.subjectId, f.topicId), ('s1', 't1'));

    final c = HiveBoxes.dailyCloseouts.get('c1')!;
    expect((c.intent, c.completedTasks, c.focusMinutes),
        ('yarın', 4, 77));

    final d = HiveBoxes.denemeler.get('d1')!;
    expect((d.examType, d.name), ('AYT', 'Deneme 3'));
    final sec = d.sections.single;
    expect((sec.correct, sec.wrong, sec.blank), (20, 8, 4));
    expect(sec.weakTopicIds, ['t1', 't-x'],
        reason: 'denemede zayıf işaretlenen konular kaybolmamalı');

    final st = HiveBoxes.stats.get('main')!;
    expect((st.currentStreak, st.longestStreak, st.dailyGoal), (5, 9, 3));
    expect((st.freezesAvailable, st.totalCompletedTasks), (2, 11));
    expect((st.totalStudyMinutes, st.focusMinutes), (640, 1234));
    expect(st.userName, 'Ada');
    expect(st.examDate, DateTime(2027, 6, 20));
    expect(st.gradeLevel, 12);
    expect((st.targetNetTYT, st.targetNetAYT), (88.5, 61.25));
    expect(st.themeMode, 'dark');
    expect(st.bonusXp, 480, reason: 'XP bonusu (rütbe) kaybolmamalı');
    expect(st.selfReportedWeakSubjectName, 'Fizik');
  });
}
