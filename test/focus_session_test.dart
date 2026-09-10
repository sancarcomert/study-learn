import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/focus_session_model.dart';

void main() {
  group('FocusSession', () {
    test('alanlar korunur', () {
      final s = FocusSession(
        id: 'a',
        endedAt: DateTime(2026, 9, 10, 14, 30),
        minutes: 25,
        mode: 'pomodoro',
      );
      expect(s.minutes, 25);
      expect(s.mode, 'pomodoro');
      expect(s.endedAt.day, 10);
    });
  });

  group('gün gruplaması (focusMinutesByDay mantığı)', () {
    // Provider'ı Hive'sız test etmek için aynı gruplama kuralını doğrula.
    Map<DateTime, int> byDay(List<FocusSession> all) {
      final map = <DateTime, int>{};
      for (final s in all) {
        final d = DateTime(s.endedAt.year, s.endedAt.month, s.endedAt.day);
        map[d] = (map[d] ?? 0) + s.minutes;
      }
      return map;
    }

    test('aynı günün seansları toplanır', () {
      final list = [
        FocusSession(
            id: '1',
            endedAt: DateTime(2026, 9, 10, 9),
            minutes: 25,
            mode: 'pomodoro'),
        FocusSession(
            id: '2',
            endedAt: DateTime(2026, 9, 10, 15),
            minutes: 40,
            mode: 'serbest'),
        FocusSession(
            id: '3',
            endedAt: DateTime(2026, 9, 11, 10),
            minutes: 30,
            mode: 'pomodoro'),
      ];
      final m = byDay(list);
      expect(m[DateTime(2026, 9, 10)], 65);
      expect(m[DateTime(2026, 9, 11)], 30);
    });
  });
}
