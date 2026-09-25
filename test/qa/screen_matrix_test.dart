import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:study_planner/about_screen.dart';
import 'package:study_planner/add_deneme_screen.dart';
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
import 'package:study_planner/main_shell.dart';
import 'package:study_planner/onboarding_screen.dart';
import 'package:study_planner/plan_screen.dart';
import 'package:study_planner/profile_screen.dart';
import 'package:study_planner/rank_ladder_screen.dart';
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

/// Ekran × veri yoğunluğu × cihaz matrisi: her ekranı boş / minimal / yoğun +
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

  /// Var olmayan ders/konu id'lerine işaret eden kayıtlar (silinmiş ders/konu,
  /// bozuk yedek, eski veri): hiçbir ekran çökmemeli.
  Future<void> seedDangling() async {
    await HiveBoxes.stats.put(
      'main',
      UserStatsModel(
        hasCompletedOnboarding: true,
        hasSeenNotificationPrompt: true,
        hasSeenTaskHints: true,
        hasSeenExactAlarmPrompt: true,
        hasAddedFirstTask: true,
        lastCarryOverPromptDate: DateTime.now(),
        examDate: today.add(const Duration(days: 30)),
        targetNetTYT: 80,
        selfReportedWeakSubjectName: 'Olmayan Ders',
      ),
    );
    await HiveBoxes.subjects.put(
      's0',
      SubjectModel(
          id: 's0', name: 'Matematik', colorValue: 0xFF6750A4, createdAt: today),
    );
    await HiveBoxes.topics.put(
      't0',
      TopicModel(id: 't0', subjectId: 's0', name: 'Türev', createdAt: today),
    );
    // Silinmiş derse/konuya bağlı görev (bugün + geçmiş).
    for (var i = 0; i < 3; i++) {
      await HiveBoxes.tasks.put(
        'g$i',
        TaskModel(
          id: 'g$i',
          title: 'Hayalet görev $i',
          subjectId: 'ghost-subject',
          topicId: 'ghost-topic',
          dueDate: today.subtract(Duration(days: i)),
          createdAt: today,
          estimatedMinutes: 30,
          sourceReason: 'Silinmiş konu için gerekçe',
        ),
      );
    }
    await HiveBoxes.focusSessions.put(
      'gf',
      FocusSession(
        id: 'gf',
        endedAt: DateTime.now(),
        minutes: 25,
        mode: 'serbest',
        subjectId: 'ghost-subject',
        topicId: 'ghost-topic',
        taskId: 'ghost-task',
        runId: 'ghost-run',
        feeling: 0,
      ),
    );
    await HiveBoxes.denemeler.put(
      'gd',
      DenemeEntry(
        id: 'gd',
        examType: 'TYT',
        date: today,
        sections: [
          DenemeSectionScore(
              subject: 'Matematik',
              correct: 10,
              wrong: 5,
              weakTopicIds: ['ghost-topic', 't0']),
          DenemeSectionScore(
              subject: 'Silinmiş Ders',
              correct: 3,
              wrong: 30,
              weakTopicIds: ['ghost-topic']),
        ],
      ),
    );
    // Silinmiş göreve/konuya bağlı, yarım kalmış odak çapası.
    await HiveBoxes.focusAnchor.put('current', {
      'mode': 'free',
      'phase': 'work',
      'blockMin': 25,
      'pomoCycle': 1,
      'committedSec': 0,
      'loggedSec': 0,
      'segStartMs':
          DateTime.now().subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
      'subjectId': 'ghost-subject',
      'topicId': 'ghost-topic',
      'taskId': 'ghost-task',
      'runId': 'ghost-run',
      'reason': 'eski gerekçe',
      'lastActiveMs': DateTime.now().millisecondsSinceEpoch,
    });
  }

  final screens = <String, Widget Function()>{
    'Onboarding': () => const OnboardingScreen(),
    'MainShell': () => const MainShell(),
    'Home': () => const HomeScreen(),
    'Tasks': () => const TasksScreen(),
    'Plan': () => const PlanScreen(),
    'Stats': () => const StatsScreen(),
    'Profile': () => const ProfileScreen(),
    'Subjects': () => const SubjectsScreen(),
    'SubjectTopics': () => const SubjectTopicsScreen(
        subjectId: 's0', subjectName: 'Matematik'),
    'KonuTakip': () => const KonuTakipScreen(),
    'Deneme': () => const DenemeScreen(),
    'AddDeneme': () => const AddDenemeScreen(),
    'AddTask': () => const AddTaskScreen(),
    'Focus': () => const FocusScreen(intent: StudyIntent.free),
    'FocusHistory': () => const FocusHistoryScreen(),
    'Coach': () => const CoachScreen(),
    'RankLadder': () => const RankLadderScreen(),
    'About': () => const AboutScreen(),
  };

  final devices = <String, (Size, double)>{
    'küçük 320x568 x1.0': (const Size(320, 568), 1.0),
    'küçük 320x568 x2.0': (const Size(320, 568), 2.0),
    'normal 393x852 x1.3': (const Size(393, 852), 1.3),
  };

  for (final scenario in ['empty', 'minimal', 'heavy', 'dangling']) {
    for (final dev in devices.entries) {
      testWidgets('matris: $scenario · ${dev.key}', (tester) async {
        final failures = <String>[];
        final captured = <String>[];
        final oldOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          final text = details.toString();
          final loc = RegExp(r'lib/[a-z_/]+\.dart:\d+').firstMatch(text)?.group(0);
          final head = details.exceptionAsString().split('\n').first;
          captured.add('$head @ ${loc ?? '?'}');
        };
        for (final entry in screens.entries) {
          if (scenario == 'dangling') {
            await seedDangling();
          } else {
            await seed(scenario);
          }
          tester.view.physicalSize = dev.value.$1 * 2.0;
          tester.view.devicePixelRatio = 2.0;
          tester.platformDispatcher.textScaleFactorTestValue = dev.value.$2;
          final container = ProviderContainer();
          try {
            await tester.pumpWidget(UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.theme,
                home: entry.value(),
              ),
            ));
            for (var i = 0; i < 4; i++) {
              await tester.pump(const Duration(milliseconds: 250));
            }
          } catch (e) {
            failures.add('${entry.key}: EXCEPTION ${e.toString().split('\n').first}');
          }
          Object? ex;
          var guard = 0;
          while ((ex = tester.takeException()) != null && guard++ < 5) {
            // Çoklu istisna sarmalayıcısı ayrıntıyı gizler — onError ile toplanır.
            if (captured.isEmpty) {
              failures.add('${entry.key}: ${ex.toString().split('\n').first}');
            }
          }
          for (final c in captured.toSet()) {
            failures.add('${entry.key}: $c');
          }
          captured.clear();
          // Ağacı at (Focus zamanlayıcısı vb. kalmasın).
          await tester.pumpWidget(const SizedBox());
          await tester.pump();
          container.dispose();
          await tester.pump();
          // Kutuları sıfırla (her ekran aynı temiz veriyle başlasın).
          await HiveBoxes.subjects.clear();
          await HiveBoxes.tasks.clear();
          await HiveBoxes.topics.clear();
          await HiveBoxes.focusSessions.clear();
          await HiveBoxes.denemeler.clear();
          await HiveBoxes.dailyCloseouts.clear();
          await HiveBoxes.stats.clear();
          await HiveBoxes.focusAnchor.clear();
        }
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        FlutterError.onError = oldOnError;
        expect(failures, isEmpty, reason: failures.join(String.fromCharCode(10)));
      });
    }
  }
}
