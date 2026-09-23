import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/goal_gap_engine.dart';

void main() {
  final now = DateTime(2026, 9, 10);

  group('GoalGapEngine.compute', () {
    test('hedef yok → gap null, hasTarget false', () {
      final g = GoalGapEngine.compute(examType: 'TYT', now: now);
      expect(g.hasTarget, isFalse);
      expect(g.gap, isNull);
      expect(g.urgency, GoalUrgency.none);
    });

    test('hedef var, deneme yok → hasResult false, gap null', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        now: now,
      );
      expect(g.hasTarget, isTrue);
      expect(g.hasResult, isFalse);
      expect(g.gap, isNull);
    });

    test('hedefin altında → pozitif gap', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
        now: now,
      );
      expect(g.gap, 10);
      expect(g.reached, isFalse);
    });

    test('hedefe tam ulaşıldı → gap 0, reached true', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 70,
        now: now,
      );
      expect(g.gap, 0);
      expect(g.reached, isTrue);
    });

    test('hedefin üstünde → negatif gap, reached true', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 72,
        now: now,
      );
      expect(g.gap, -2);
      expect(g.reached, isTrue);
    });

    test('TYT hedefi ayrı hesaplanır', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 90,
        currentNet: 80,
        now: now,
      );
      expect(g.examType, 'TYT');
      expect(g.gap, 10);
    });

    test('AYT hedefi ayrı hesaplanır', () {
      final g = GoalGapEngine.compute(
        examType: 'AYT',
        target: 50,
        currentNet: 40,
        now: now,
      );
      expect(g.examType, 'AYT');
      expect(g.gap, 10);
    });

    test('sınav tarihi geçmiş → examPassed, aciliyet yok', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
        examDate: DateTime(2026, 9, 1),
        now: now,
      );
      expect(g.examDaysRemaining, lessThan(0));
      expect(g.urgency, GoalUrgency.examPassed);
      expect(g.examPassed, isTrue);
    });

    test('sınav 30 gün ya da daha yakınsa aciliyet "urgent"', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
        examDate: now.add(const Duration(days: 20)),
        now: now,
      );
      expect(g.urgency, GoalUrgency.urgent);
    });

    test('sınav 31-90 gün arasıysa aciliyet "approaching"', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
        examDate: now.add(const Duration(days: 60)),
        now: now,
      );
      expect(g.urgency, GoalUrgency.approaching);
    });

    test('sınav 90 günden uzaksa aciliyet "distant"', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
        examDate: now.add(const Duration(days: 200)),
        now: now,
      );
      expect(g.urgency, GoalUrgency.distant);
    });

    test('hedefe ulaşıldıysa sınav yakın olsa bile aciliyet yok', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 75,
        examDate: now.add(const Duration(days: 5)),
        now: now,
      );
      expect(g.urgency, GoalUrgency.none);
    });

    test('bir önceki denemeye göre gap değişimi hesaplanır (fark kapandı)',
        () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 64,
        previousNet: 61,
        now: now,
      );
      expect(g.previousGap, 9);
      expect(g.gap, 6);
      expect(g.gapChange, 3); // fark 9'dan 6'ya indi → 3 net kapandı
      expect(g.netChange, 3);
    });

    test('bir önceki denemeye göre gap değişimi hesaplanır (fark açıldı)',
        () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 58,
        previousNet: 61,
        now: now,
      );
      expect(g.gapChange, -3);
    });
  });

  group('GoalGapEngine.primary', () {
    test('ikisi de hedeflenmemişse null', () {
      final tyt = GoalGapEngine.compute(examType: 'TYT', now: now);
      final ayt = GoalGapEngine.compute(examType: 'AYT', now: now);
      expect(GoalGapEngine.primary(tyt, ayt), isNull);
    });

    test('yalnız TYT hedeflenmişse TYT döner', () {
      final tyt =
          GoalGapEngine.compute(examType: 'TYT', target: 70, now: now);
      final ayt = GoalGapEngine.compute(examType: 'AYT', now: now);
      expect(GoalGapEngine.primary(tyt, ayt)?.examType, 'TYT');
    });

    test('yalnız AYT hedeflenmişse AYT döner', () {
      final tyt = GoalGapEngine.compute(examType: 'TYT', now: now);
      final ayt =
          GoalGapEngine.compute(examType: 'AYT', target: 50, now: now);
      expect(GoalGapEngine.primary(tyt, ayt)?.examType, 'AYT');
    });

    test('ikisi de hedeflenmişse, sınav odaklı (11-12/mezun) için AYT esas',
        () {
      final tyt =
          GoalGapEngine.compute(examType: 'TYT', target: 70, now: now);
      final ayt =
          GoalGapEngine.compute(examType: 'AYT', target: 50, now: now);
      expect(
        GoalGapEngine.primary(tyt, ayt, gradeLevel: 12)?.examType,
        'AYT',
      );
    });

    test('ikisi de hedeflenmişse, sınav odaklı olmayan (9-10) için TYT esas',
        () {
      final tyt =
          GoalGapEngine.compute(examType: 'TYT', target: 70, now: now);
      final ayt =
          GoalGapEngine.compute(examType: 'AYT', target: 50, now: now);
      expect(
        GoalGapEngine.primary(tyt, ayt, gradeLevel: 9)?.examType,
        'TYT',
      );
    });
  });

  group('GoalGapEngine.priorityAmplifier', () {
    test('goalGap null → 0', () {
      expect(GoalGapEngine.priorityAmplifier(null), 0.0);
    });

    test('hedef yok → 0', () {
      final g = GoalGapEngine.compute(examType: 'TYT', now: now);
      expect(GoalGapEngine.priorityAmplifier(g), 0.0);
    });

    test('hedefe ulaşıldı → 0', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 72,
        now: now,
      );
      expect(GoalGapEngine.priorityAmplifier(g), 0.0);
    });

    test('sınav geçmiş → 0', () {
      final g = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 60,
        examDate: DateTime(2026, 9, 1),
        now: now,
      );
      expect(GoalGapEngine.priorityAmplifier(g), 0.0);
    });

    test('gap büyüdükçe ve sınav yaklaştıkça çarpan büyür', () {
      final smallGapFar = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 68,
        examDate: now.add(const Duration(days: 200)),
        now: now,
      );
      final bigGapUrgent = GoalGapEngine.compute(
        examType: 'TYT',
        target: 70,
        currentNet: 50,
        examDate: now.add(const Duration(days: 10)),
        now: now,
      );
      final a = GoalGapEngine.priorityAmplifier(smallGapFar);
      final b = GoalGapEngine.priorityAmplifier(bigGapUrgent);
      expect(a, greaterThan(0));
      expect(b, greaterThan(a));
      expect(b, lessThanOrEqualTo(1.0));
    });
  });
}
