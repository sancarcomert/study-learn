import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/add_task_screen.dart';
import 'package:study_planner/app_theme.dart';
import 'package:study_planner/coach_screen.dart';
import 'package:study_planner/deneme_model.dart';
import 'package:study_planner/deneme_screen.dart';
import 'package:study_planner/focus_history_screen.dart';
import 'package:study_planner/focus_screen.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/hive_boxes.dart';
import 'package:study_planner/home_screen.dart';
import 'package:study_planner/konu_takip_screen.dart';
import 'package:study_planner/plan_screen.dart';
import 'package:study_planner/profile_screen.dart';
import 'package:study_planner/stats_screen.dart';
import 'package:study_planner/study_intent.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/subject_topics_screen.dart';
import 'package:study_planner/subjects_screen.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/tasks_screen.dart';
import 'package:study_planner/topic_model.dart';
import 'package:study_planner/user_stats_model.dart';

import '../support/hive_memory.dart';

/// Erişilebilirlik: her dokunulabilir öğenin ekran okuyucu etiketi olmalı
/// (Flutter labeledTapTargetGuideline). 48dp dokunma alanı kılavuzu bilerek
/// burada ZORUNLU değil: Material'ın kendi 32-40dp chip/pill'leri gibi küçük
/// pill'ler bilinen P2 olarak duruyor; <32dp olanlar düzeltildi.: her ekranı boş / minimal / yoğun +
/// aşırı uzun Türkçe adlarla, küçük telefonda ve 2x sistem yazısıyla açar;
/// taşma (RenderFlex overflow) ve build/çizim istisnası YAKALAR.
void main() {
  setUpAll(() => initializeDateFormatting('tr_TR', null));
  setUp(openMemoryBoxes);
  tearDown(closeMemoryBoxes);

  const longName =
      'Çok Uzun Bir Ders Adı — Türk Dili ve Edebiyatı Anlatım Bozuklukları';
  const longTask =
      'KarşılaştırmalıÇokUzunBirGörevBaşlığıBoşluksuzKelimeİçeren Paragraf '
      'Analizi ve Sözcükte Anlam Çalışması — 3 farklı yayının denemesi';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  Future<void> seed(String scenario) async {
    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        dailyGoal: scenario == 'heavy' ? 3 : 1,
        hasCompletedOnboarding: true,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        hasAddedFirstTask: true,
        lastCarryOverPromptDate: DateTime.now(),
        userName: scenario == 'heavy'
            ? 'Muhammed Sancar Çağlayan Uzunisimli Öğrenci'
            : null,
        examDate: scenario == 'empty' ? null : today.add(const Duration(days: 90)),
        focusMinutes: scenario == 'heavy' ? 5400 : 0,
        totalStudyMinutes: scenario == 'heavy' ? 3200 : 0,
        bonusXp: scenario == 'heavy' ? 900 : 0,
        currentStreak: scenario == 'heavy' ? 45 : 0,
        longestStreak: scenario == 'heavy' ? 60 : 0,
        targetNetTYT: scenario == 'empty' ? null : 90,
        gradeLevel: 12,
      ),
    );
    if (scenario == 'empty') return;

    final subjectCount = scenario == 'heavy' ? 9 : 1;
    for (var s = 0; s < subjectCount; s++) {
      final id = 's$s';
      await HiveBoxes.subjects.put(
        id,
        SubjectModel(
          id: id,
          name: scenario == 'heavy' ? '$longName $s' : 'Matematik',
          colorValue: 0xFF6750A4 + s * 0x00101010,
          createdAt: DateTime(2026, 1, 1),
        ),
      );
      final topicCount = scenario == 'heavy' ? 18 : 1;
      for (var t = 0; t < topicCount; t++) {
        await HiveBoxes.topics.put(
          's${s}t$t',
          TopicModel(
            id: 's${s}t$t',
            subjectId: id,
            name: scenario == 'heavy'
                ? 'Konu $t — Çok Uzun Konu Adı Örneği Türev ve Uygulamaları'
                : 'Türev',
            status: TopicStatus.values[t % 3],
            createdAt: DateTime(2026, 1, 1),
          ),
        );
      }
    }
    final taskCount = scenario == 'heavy' ? 60 : 1;
    for (var i = 0; i < taskCount; i++) {
      final id = 'task$i';
      await HiveBoxes.tasks.put(
        id,
        TaskModel(
          id: id,
          title: scenario == 'heavy' ? '$longTask $i' : 'Matematik: Türev',
          subjectId: 's${i % subjectCount}',
          topicId: 's${i % subjectCount}t${i % 2}',
          dueDate: today.add(Duration(days: (i % 9) - 3)),
          createdAt: DateTime(2026, 9, 1),
          estimatedMinutes: scenario == 'heavy' ? 25 + (i % 5) * 10 : 30,
          isCompleted: i % 4 == 0,
          completedAt: i % 4 == 0 ? DateTime.now() : null,
          scheduledTime: i % 3 == 0
              ? DateTime(now.year, now.month, now.day, 8 + (i % 12), 30)
                  .add(Duration(days: (i % 9) - 3))
              : null,
          sourceReason: i % 5 == 0
              ? '"Türev ve İntegral Uygulamaları" konusunda denemede yanlış yapmıştın'
              : null,
          priority: TaskPriority.values[i % 3],
        ),
      );
    }
    final sessionCount = scenario == 'heavy' ? 40 : 1;
    for (var i = 0; i < sessionCount; i++) {
      await HiveBoxes.focusSessions.put(
        'f$i',
        FocusSession(
          id: 'f$i',
          endedAt: DateTime.now().subtract(Duration(hours: i * 7)),
          minutes: 10 + (i % 6) * 15,
          mode: i.isEven ? 'serbest' : 'pomodoro',
          subjectId: 's${i % subjectCount}',
          topicId: 's${i % subjectCount}t${i % 3}',
          runId: 'run$i',
          feeling: i % 3,
          note: scenario == 'heavy' ? longTask : null,
        ),
      );
    }
    final denemeCount = scenario == 'heavy' ? 8 : 1;
    for (var i = 0; i < denemeCount; i++) {
      await HiveBoxes.denemeler.put(
        'd$i',
        DenemeEntry(
          id: 'd$i',
          examType: i.isEven ? 'TYT' : 'AYT',
          name: scenario == 'heavy' ? 'Çok Uzun Deneme Adı $longName' : null,
          date: today.subtract(Duration(days: i * 6)),
          sections: [
            for (var s = 0; s < (scenario == 'heavy' ? 4 : 1); s++)
              DenemeSectionScore(
                subject: scenario == 'heavy' ? '$longName $s' : 'Matematik',
                correct: 12 + i,
                wrong: 5,
                blank: 3,
                weakTopicIds: ['s${s}t0', 's${s}t1'],
              ),
          ],
        ),
      );
    }
  }

  final screens = <String, Widget Function()>{
    'Home': () => const HomeScreen(),
    'Tasks': () => const TasksScreen(),
    'Plan': () => const PlanScreen(),
    'Stats': () => const StatsScreen(),
    'Profile': () => const ProfileScreen(),
    'Subjects': () => const SubjectsScreen(),
    'SubjectTopics': () =>
        const SubjectTopicsScreen(subjectId: 's0', subjectName: 'Matematik'),
    'KonuTakip': () => const KonuTakipScreen(),
    'Deneme': () => const DenemeScreen(),
    'AddTask': () => const AddTaskScreen(),
    'Focus': () => const FocusScreen(intent: StudyIntent.free),
    'FocusHistory': () => const FocusHistoryScreen(),
    'Coach': () => const CoachScreen(),
  };

  for (final guideline in <String, AccessibilityGuideline>{
    'etiketli dokunma': labeledTapTargetGuideline,
  }.entries) {
    testWidgets('erişilebilirlik: ${guideline.key}', (tester) async {
      final handle = tester.ensureSemantics();
      final failures = <String>[];
      for (final entry in screens.entries) {
        await seed('minimal');
        tester.view.physicalSize = const Size(393, 852) * 2.0;
        tester.view.devicePixelRatio = 2.0;
        final container = ProviderContainer();
        await tester.pumpWidget(UncontrolledProviderScope(
          container: container,
          child: MaterialApp(theme: AppTheme.theme, home: entry.value()),
        ));
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 250));
        }
        final result = await guideline.value.evaluate(tester);
        if (!result.passed) {
          failures.add('${entry.key}: ${(result.reason ?? '').replaceAll(String.fromCharCode(10), ' | ')}');
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        container.dispose();
        await HiveBoxes.subjects.clear();
        await HiveBoxes.tasks.clear();
        await HiveBoxes.topics.clear();
        await HiveBoxes.focusSessions.clear();
        await HiveBoxes.denemeler.clear();
        await HiveBoxes.stats.clear();
        await HiveBoxes.focusAnchor.clear();
      }
      handle.dispose();
      expect(failures, isEmpty, reason: failures.join(String.fromCharCode(10)));
    });
  }
}
