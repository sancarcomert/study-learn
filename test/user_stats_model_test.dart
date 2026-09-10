import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/user_stats_model.dart';

/// P0-1 — sınıf kişiselleştirmesi yardımcıları.
void main() {
  group('gradeLabel', () {
    test('null → belirtilmedi', () {
      expect(UserStatsModel.gradeLabel(null), 'Sınıf belirtilmedi');
    });

    test('9–12 → "N. sınıf"', () {
      expect(UserStatsModel.gradeLabel(9), '9. sınıf');
      expect(UserStatsModel.gradeLabel(12), '12. sınıf');
    });

    test('13 → Mezun', () {
      expect(UserStatsModel.gradeLabel(UserStatsModel.mezun), 'Mezun');
      expect(UserStatsModel.gradeLabel(13), 'Mezun');
    });
  });

  group('isExamFocused', () {
    test('9–10 alışkanlık odaklı (false)', () {
      expect(UserStatsModel.isExamFocused(9), isFalse);
      expect(UserStatsModel.isExamFocused(10), isFalse);
    });

    test('11–12 + mezun sınav odaklı (true)', () {
      expect(UserStatsModel.isExamFocused(11), isTrue);
      expect(UserStatsModel.isExamFocused(12), isTrue);
      expect(UserStatsModel.isExamFocused(UserStatsModel.mezun), isTrue);
    });

    test('null → false', () {
      expect(UserStatsModel.isExamFocused(null), isFalse);
    });
  });
}
