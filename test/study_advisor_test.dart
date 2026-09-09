import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/study_advisor.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';

SubjectModel _sub(String name, {DateTime? created}) => SubjectModel(
      id: 'id-$name',
      name: name,
      colorValue: 0,
      createdAt: created ?? DateTime(2026, 1, 1),
    );

TaskModel _task(
  String subjectId, {
  required DateTime due,
  bool completed = false,
  TaskPriority priority = TaskPriority.medium,
}) =>
    TaskModel(
      id: 'task-$subjectId-${due.millisecondsSinceEpoch}-$completed',
      title: 't',
      subjectId: subjectId,
      dueDate: due,
      isCompleted: completed,
      priority: priority,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 9, 10, 12);
  final today = DateTime(2026, 9, 10);

  test('ders yoksa boş liste', () {
    expect(
      StudyAdvisor.suggest(subjects: const [], tasks: const [], now: now),
      isEmpty,
    );
  });

  test('bugün zaten görevi olan ders önerilmez', () {
    final subjects = [_sub('Matematik')];
    final tasks = [_task('id-Matematik', due: today)];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out, isEmpty);
  });

  test('uzun süredir dokunulmayan ders üste çıkar', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 1))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 20))),
    ];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, contains('gündür dokunmadın'));
  });

  test('hiç görevi olmayan ders "henüz hiç görev" gerekçesi alır', () {
    final subjects = [_sub('Kimya', created: today.subtract(const Duration(days: 3)))];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: const [], now: now);
    expect(out, isNotEmpty);
    expect(out.first.reason, 'Henüz hiç görev eklemedin');
  });

  test('bekleyen yüksek öncelikli görev gerekçesi', () {
    final subjects = [_sub('Fizik')];
    final tasks = [
      _task('id-Fizik',
          due: today.subtract(const Duration(days: 1)),
          priority: TaskPriority.high),
    ];
    final out = StudyAdvisor.suggest(subjects: subjects, tasks: tasks, now: now);
    expect(out.first.reason, 'Bekleyen öncelikli görevin var');
  });

  test('düşük konu kapsaması olan ders öne çıkar + gerekçe', () {
    final subjects = [_sub('Matematik'), _sub('Fizik')];
    // İkisi de aynı gün dokunulmuş; fark yalnız kapsama.
    final tasks = [
      _task('id-Matematik', due: today.subtract(const Duration(days: 2))),
      _task('id-Fizik', due: today.subtract(const Duration(days: 2))),
    ];
    final out = StudyAdvisor.suggest(
      subjects: subjects,
      tasks: tasks,
      now: now,
      coveragePercent: {'id-Matematik': 0.9, 'id-Fizik': 0.1},
    );
    expect(out.first.subjectName, 'Fizik');
    expect(out.first.reason, contains('işaretli'));
  });

  test('limit uygulanır', () {
    final subjects = List.generate(
      6,
      (i) => _sub('D$i', created: today.subtract(Duration(days: 10 + i))),
    );
    final out = StudyAdvisor.suggest(
        subjects: subjects, tasks: const [], now: now, limit: 3);
    expect(out.length, 3);
  });

  test('sıralama deterministik (eşit puanda ada göre)', () {
    final subjects = [
      _sub('Zebra', created: today.subtract(const Duration(days: 10))),
      _sub('Adana', created: today.subtract(const Duration(days: 10))),
    ];
    final a = StudyAdvisor.suggest(subjects: subjects, tasks: const [], now: now);
    final b = StudyAdvisor.suggest(
        subjects: subjects.reversed.toList(), tasks: const [], now: now);
    expect(a.map((s) => s.subjectName), b.map((s) => s.subjectName));
    expect(a.first.subjectName, 'Adana');
  });
}
