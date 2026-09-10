import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/task_model.dart';
import 'package:study_planner/task_time_status.dart';

TaskModel _task({
  required DateTime due,
  bool completed = false,
  DateTime? scheduled,
  int? est,
}) =>
    TaskModel(
      id: 't',
      title: 'x',
      dueDate: due,
      isCompleted: completed,
      createdAt: DateTime(2026, 1, 1),
      scheduledTime: scheduled,
      estimatedMinutes: est,
    );

void main() {
  final now = DateTime(2026, 9, 10, 14, 0); // Perşembe 14:00
  final today = DateTime(2026, 9, 10);
  final yesterday = DateTime(2026, 9, 9);

  group('timeStatusAt', () {
    test('saatsiz görev → none', () {
      expect(_task(due: today).timeStatusAt(now), TaskTimeStatus.none);
    });

    test('tamamlanmış → none (saatli olsa bile)', () {
      final t = _task(
        due: today,
        completed: true,
        scheduled: DateTime(2026, 9, 10, 10),
        est: 30,
      );
      expect(t.timeStatusAt(now), TaskTimeStatus.none);
    });

    test('gelecekteki saat → upcoming', () {
      final t = _task(due: today, scheduled: DateTime(2026, 9, 10, 16));
      expect(t.timeStatusAt(now), TaskTimeStatus.upcoming);
    });

    test('başlamış, bitmemiş → inProgress', () {
      final t =
          _task(due: today, scheduled: DateTime(2026, 9, 10, 13, 30), est: 60);
      expect(t.timeStatusAt(now), TaskTimeStatus.inProgress);
    });

    test('bitiş geçmiş → overdue', () {
      final t =
          _task(due: today, scheduled: DateTime(2026, 9, 10, 12), est: 30);
      expect(t.timeStatusAt(now), TaskTimeStatus.overdue);
    });
  });

  group('isPastDayIncompleteAt', () {
    test('dün, tamamlanmamış → true', () {
      expect(_task(due: yesterday).isPastDayIncompleteAt(now), isTrue);
    });

    test('dün ama tamamlanmış → false', () {
      expect(
        _task(due: yesterday, completed: true).isPastDayIncompleteAt(now),
        isFalse,
      );
    });

    test('bugün, tamamlanmamış → false', () {
      expect(_task(due: today).isPastDayIncompleteAt(now), isFalse);
    });

    test('bugünün ilerki saati bile → false (gün seviyesi)', () {
      expect(
        _task(due: DateTime(2026, 9, 10, 23, 59)).isPastDayIncompleteAt(now),
        isFalse,
      );
    });
  });
}
