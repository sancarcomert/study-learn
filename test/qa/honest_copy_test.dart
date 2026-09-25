import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/study_advisor.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/today_study.dart';

/// Öğrenciye söylenen cümleler ölçülen/gerçek duruma uymalı: bilinmeyen bir
/// sayıyı kesin gibi söylememeli, tamamlanmış planı "başlamadın" dememeli.
void main() {
  final now = DateTime(2026, 9, 25, 10);
  final today = DateTime(2026, 9, 25);

  TaskModel task(String id, {bool done = false, int minutes = 30}) => TaskModel(
        id: id,
        title: id,
        dueDate: today,
        createdAt: today,
        isCompleted: done,
        estimatedMinutes: minutes,
      );

  group('Home çalışma satırı', () {
    test('tüm görevler işaretlenip Odak ölçümü yoksa "henüz başlamadın" DENMEZ',
        () {
      final s = TodayStudy.compute(
        tasks: [task('a', done: true), task('b', done: true)],
        loggedMinutes: 0,
        now: now,
      );
      final line = todayStudyLine(s, hasTasksToday: true);
      expect(line, isNot(contains('henüz başlamadın')));
      expect(line, contains('tamam'));
      expect(line, contains('ölçülmedi'));
    });

    test('yarım kalmış planda eski cümle korunur', () {
      final s = TodayStudy.compute(
        tasks: [task('a', done: true), task('b')],
        loggedMinutes: 0,
        now: now,
      );
      expect(todayStudyLine(s, hasTasksToday: true),
          'Bugünkü plan 1 sa · henüz başlamadın');
    });

    test('ölçülmüş çalışma varsa o söylenir', () {
      final s = TodayStudy.compute(
        tasks: [task('a', done: true)],
        loggedMinutes: 20,
        now: now,
      );
      expect(todayStudyLine(s, hasTasksToday: true), contains('20 dk çalıştın'));
    });
  });

  group('StudyAdvisor gerekçesi', () {
    test('60 gün üst sınırdır: "60 gündür" değil "2 aydan uzun" denir', () {
      final subjects = [
        SubjectModel(
          id: 's1',
          name: 'Matematik',
          colorValue: 0xFF000000,
          createdAt: DateTime(2026, 1, 1), // ~267 gün önce
        ),
      ];
      // Yalnız YARINA görevi var (geçmişte hiç görev yok) → "dokunulmadı" sayılır.
      final future = TaskModel(
        id: 'f',
        title: 'f',
        subjectId: 's1',
        dueDate: today.add(const Duration(days: 1)),
        createdAt: today,
      );
      final out =
          StudyAdvisor.suggest(subjects: subjects, tasks: [future], now: now);
      expect(out.first.reason, isNot(contains('60 gündür')));
      expect(out.first.reason, contains('2 aydan uzun'));
    });
  });
}
