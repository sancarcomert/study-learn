import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/day_summary.dart';
import 'package:study_planner/focus_session_model.dart';
import 'package:study_planner/next_task_picker.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_time_options.dart';

TaskModel _t(
  String id, {
  DateTime? due,
  DateTime? at,
  bool done = false,
  TaskPriority priority = TaskPriority.medium,
  int? minutes,
  String? reason,
  DateTime? created,
  DateTime? completedAt,
}) =>
    TaskModel(
      id: id,
      title: id,
      dueDate: due ?? DateTime(2026, 9, 23),
      scheduledTime: at,
      isCompleted: done,
      priority: priority,
      estimatedMinutes: minutes,
      sourceReason: reason,
      createdAt: created ?? DateTime(2026, 9, 1),
      completedAt: completedAt,
    );

void main() {
  final now = DateTime(2026, 9, 23, 21, 0);

  group('NextTaskPicker — Home "şimdi ne yapmalıyım?"', () {
    test('SAATSİZ bugünkü görev artık aday (onboarding/Coach planı)', () {
      // Regresyon: eskiden yalnız saatli görevler aday olduğu için Home
      // "0/1 görev" derken "plan yok" diyordu.
      final tasks = [_t('ilk çalışma')];
      expect(NextTaskPicker.pick(tasks, now)?.id, 'ilk çalışma');
    });

    test('tamamlanmış ya da başka güne ait görev seçilmez', () {
      final tasks = [
        _t('bitti', done: true),
        _t('yarın', due: DateTime(2026, 9, 24)),
      ];
      expect(NextTaskPicker.pick(tasks, now), isNull);
    });

    test('saatli görev, saatsizden önce gelir (saat bir taahhüttür)', () {
      final tasks = [
        _t('saatsiz', priority: TaskPriority.high),
        _t('saatli', at: DateTime(2026, 9, 23, 22, 0), minutes: 30),
      ];
      expect(NextTaskPicker.pick(tasks, now)?.id, 'saatli');
    });

    test('sürüyor > yaklaşan > geciken', () {
      final tasks = [
        _t('geciken', at: DateTime(2026, 9, 23, 9, 0), minutes: 30),
        _t('yaklaşan', at: DateTime(2026, 9, 23, 22, 0), minutes: 30),
        _t('sürüyor', at: DateTime(2026, 9, 23, 20, 45), minutes: 30),
      ];
      expect(NextTaskPicker.pick(tasks, now)?.id, 'sürüyor');
      expect(
        NextTaskPicker.pick(
                tasks.where((t) => t.id != 'sürüyor').toList(), now)
            ?.id,
        'yaklaşan',
      );
    });

    test('saatsizler: yüksek öncelik, sonra gerekçeli, sonra eklenme sırası', () {
      final tasks = [
        _t('sıradan-eski', created: DateTime(2026, 9, 1)),
        _t('gerekçeli', reason: 'Son denemende burada yanlış yapmıştın'),
        _t('yüksek', priority: TaskPriority.high, created: DateTime(2026, 9, 5)),
      ];
      final order = NextTaskPicker.untimedToday(tasks, now).map((t) => t.id);
      expect(order, ['yüksek', 'gerekçeli', 'sıradan-eski']);
    });

    test('remaining: kartta gösterilen hariç, saatliler önce', () {
      final a = _t('a', at: DateTime(2026, 9, 23, 22, 0), minutes: 30);
      final b = _t('b');
      final c = _t('c', at: DateTime(2026, 9, 23, 23, 0), minutes: 30);
      final rest = NextTaskPicker.remaining([b, c, a], now, exclude: a);
      expect(rest.map((t) => t.id), ['c', 'b']);
    });
  });

  group('TaskWhen / TaskTimeOptions — gerçek saate göre "ne zaman"', () {
    test("21:02'de: Şimdi, 30 dk, 1 saat, bugün daha sonra, yarın — geçmiş saat YOK",
        () {
      final n = DateTime(2026, 9, 23, 21, 2);
      final kinds = TaskTimeOptions.available(n);
      expect(kinds, [
        WhenKind.now,
        WhenKind.in30,
        WhenKind.in60,
        WhenKind.laterToday,
        WhenKind.tomorrow,
      ]);
      // Hiçbir zamanlı seçenek geçmişte değil.
      for (final k in kinds) {
        final at = TaskWhen(k).scheduledAt(n);
        if (at != null) expect(at.isBefore(n), isFalse, reason: '$k');
      }
      expect(const TaskWhen(WhenKind.now).scheduledAt(n), DateTime(2026, 9, 23, 21, 2));
      expect(const TaskWhen(WhenKind.in30).scheduledAt(n), DateTime(2026, 9, 23, 21, 35));
      expect(const TaskWhen(WhenKind.in60).scheduledAt(n), DateTime(2026, 9, 23, 22, 5));
    });

    test('etiketler çözülmüş saati gösterir', () {
      final n = DateTime(2026, 9, 23, 21, 2);
      expect(TaskTimeOptions.label(const TaskWhen(WhenKind.now), n), 'Şimdi');
      expect(TaskTimeOptions.label(const TaskWhen(WhenKind.in30), n),
          '30 dk sonra · 21:35');
      expect(TaskTimeOptions.label(const TaskWhen(WhenKind.in60), n),
          '1 saat sonra · 22:05');
      expect(TaskTimeOptions.label(TaskWhen.laterToday, n), 'Bugün daha sonra');
    });

    test('gece yarısını aşan göreli seçenekler sunulmaz (23:40)', () {
      final n = DateTime(2026, 9, 23, 23, 40);
      final kinds = TaskTimeOptions.available(n);
      expect(kinds, contains(WhenKind.now));
      expect(kinds, isNot(contains(WhenKind.in30)));
      expect(kinds, isNot(contains(WhenKind.in60)));
      expect(kinds, contains(WhenKind.laterToday));
    });

    test('göreli seçenekler KAYDETME anındaki saate göre çözülür (ekran açık kalsa da)',
        () {
      final selectedAt = DateTime(2026, 9, 23, 21, 0);
      final savedAt = DateTime(2026, 9, 23, 21, 40);
      const w = TaskWhen(WhenKind.in30); // 21:00'de seçildi
      expect(w.scheduledAt(selectedAt), DateTime(2026, 9, 23, 21, 30));
      // 21:40'ta kaydedilince geçmişe (21:30) kalmaz.
      expect(w.scheduledAt(savedAt), DateTime(2026, 9, 23, 22, 10));
      expect(w.scheduledAt(savedAt)!.isBefore(savedAt), isFalse);
    });

    test('saatsiz görev mümkün: "bugün daha sonra" ve "yarın" saat üretmez', () {
      final n = DateTime(2026, 9, 23, 21, 2);
      expect(TaskWhen.laterToday.scheduledAt(n), isNull);
      expect(TaskWhen.laterToday.isTimed, isFalse);
      expect(TaskWhen.laterToday.dueDay(n), DateTime(2026, 9, 23));
      expect(const TaskWhen(WhenKind.tomorrow).scheduledAt(n), isNull);
      expect(const TaskWhen(WhenKind.tomorrow).dueDay(n), DateTime(2026, 9, 24));
    });

    test('Özel: tam gün + saat; saat verilmezse o güne saatsiz', () {
      final n = DateTime(2026, 9, 23, 21, 2);
      final timed = TaskWhen.custom(
          DateTime(2026, 10, 5, 13, 7), const TimeOfDay(hour: 18, minute: 30));
      expect(timed.dueDay(n), DateTime(2026, 10, 5));
      expect(timed.scheduledAt(n), DateTime(2026, 10, 5, 18, 30));
      expect(timed.isTimed, isTrue);
      expect(TaskTimeOptions.label(timed, n), '5 Eki · 18:30');

      final untimed = TaskWhen.custom(DateTime(2026, 10, 5), null);
      expect(untimed.scheduledAt(n), isNull);
      expect(untimed.isTimed, isFalse);
      expect(TaskTimeOptions.label(untimed, n), '5 Eki · saatsiz');
    });

    test('düzenlemede mevcut tarih/saat doğru seçeneğe döner', () {
      final n = DateTime(2026, 9, 23, 21, 2);
      expect(TaskWhen.fromExisting(DateTime(2026, 9, 23), null, n),
          TaskWhen.laterToday);
      expect(TaskWhen.fromExisting(DateTime(2026, 9, 24), null, n).kind,
          WhenKind.tomorrow);
      final custom = TaskWhen.fromExisting(
          DateTime(2026, 9, 23), DateTime(2026, 9, 23, 14, 0), n);
      expect(custom.kind, WhenKind.custom);
      expect(custom.customTime, const TimeOfDay(hour: 14, minute: 0));
    });
  });

  group('DaySummaries — takvim', () {
    test('plan: görev sayısı, planlanan dakika, biten', () {
      final tasks = [
        _t('a', minutes: 45, done: true),
        _t('b', minutes: 50),
        _t('c', due: DateTime(2026, 9, 24), minutes: 99),
      ];
      final p = DaySummaries.plan(tasks, DateTime(2026, 9, 23));
      expect(p.total, 2);
      expect(p.completed, 1);
      expect(p.plannedMinutes, 95);
      expect(p.allDone, isFalse);
      expect(DaySummaries.plan(tasks, DateTime(2026, 9, 25)).isEmpty, isTrue);
    });

    test('gün kaydı: plan ↔ gerçek — görevler, çalışma başına tek satır, göreve bağlı olmayanlar ayrı',
        () {
      final day = DateTime(2026, 9, 22);
      FocusSession fs(String id, int min, DateTime at,
              {String? subject, String? task, String? run, int? feeling}) =>
          FocusSession(
            id: id,
            endedAt: at,
            minutes: min,
            mode: 'serbest',
            subjectId: subject,
            taskId: task,
            runId: run,
            feeling: feeling,
          );
      final sessions = [
        // aynı çalışmanın iki dilimi → TEK satır, 45 dk
        fs('1', 25, DateTime(2026, 9, 22, 10),
            subject: 'mat', task: 'planli', run: 'r1', feeling: FocusFeeling.hard),
        fs('2', 20, DateTime(2026, 9, 22, 10, 40),
            subject: 'mat', task: 'planli', run: 'r1'),
        // göreve bağlı olmayan konu çalışması
        fs('3', 15, DateTime(2026, 9, 22, 16), subject: 'fiz', run: 'r2'),
        // başka gün
        fs('4', 99, DateTime(2026, 9, 21, 16), subject: 'fiz', run: 'r3'),
      ];
      final tasks = [
        _t('planli', due: day, minutes: 30, done: true, completedAt: DateTime(2026, 9, 22, 11)),
        _t('bekleyen', due: day, minutes: 20),
        _t('baska gun', done: true, completedAt: DateTime(2026, 9, 21)),
      ];
      final log = DaySummaries.log(day, tasks, sessions);

      // Bekleyen önce, tamamlanan sonra (yapılacak olan üstte).
      expect(log.tasks.map((t) => t.id), ['bekleyen', 'planli']);
      expect(log.completedCount, 1);
      expect(log.runs.length, 2);
      expect(log.focusMinutes, 60);
      final planliRuns = log.runsForTask('planli').toList();
      expect(planliRuns.single.minutes, 45);
      expect(planliRuns.single.feeling, FocusFeeling.hard);
      expect(log.looseRuns.single.subjectId, 'fiz');
      expect(log.isEmpty, isFalse);
      expect(DaySummaries.log(DateTime(2026, 9, 1), tasks, sessions).isEmpty,
          isTrue);
    });
  });
}
