import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/plan_builder.dart';
import 'package:study_planner/subject_model.dart';

/// PlanBuilder değişmezleri (rastgele girdilerle, sabit tohum): hiçbir
/// kombinasyonda çökmez, kapasiteyi aşmaz, geçersiz blok üretmez.
void main() {
  test('build: 2000 rastgele girdide değişmezler korunur', () {
    final rnd = Random(42);
    final energies = ['düşük', 'orta', 'yüksek'];
    for (var iter = 0; iter < 2000; iter++) {
      final subjectCount = rnd.nextInt(12); // 0..11
      final subjects = [
        for (var i = 0; i < subjectCount; i++)
          SubjectModel(
              id: 's$i',
              name: 'Ders $i',
              colorValue: 0xFF000000,
              createdAt: DateTime(2026, 1, 1)),
      ];
      final capacity = rnd.nextInt(800); // 0..799 dk
      final energy = energies[rnd.nextInt(3)];
      final uncovered = <String, List<({String name, String id})>>{
        for (final s in subjects)
          if (rnd.nextBool())
            s.id: [
              for (var t = 0; t < rnd.nextInt(6); t++)
                (name: 'Konu $t', id: '${s.id}t$t'),
            ],
      };
      final weak = <String, List<({String name, String id})>>{
        for (final s in subjects)
          if (rnd.nextInt(4) == 0)
            s.id: [(name: 'Zayıf', id: '${s.id}w')],
      };
      final result = PlanBuilder.build(
        orderedSubjects: subjects,
        capacityMinutes: capacity,
        energy: energy,
        examDays: rnd.nextBool() ? rnd.nextInt(90) : null,
        uncoveredTopics: uncovered,
        fillToCapacity: rnd.nextBool(),
        examWeakTopics: weak,
        random: Random(iter),
      );

      final total = result.blocks.fold<int>(0, (s, b) => s + b.minutes);
      final ctx = 'iter=$iter subjects=$subjectCount cap=$capacity $energy';
      expect(total, lessThanOrEqualTo(capacity), reason: 'kapasite aşıldı: $ctx');
      final ids = subjects.map((s) => s.id).toSet();
      for (final b in result.blocks) {
        expect(b.minutes, greaterThan(0), reason: ctx);
        expect(b.title.trim(), isNotEmpty, reason: ctx);
        expect(ids, contains(b.subjectId), reason: 'bilinmeyen ders: $ctx');
      }
      if (subjects.isEmpty) expect(result.blocks, isEmpty);
      // Aynı konu aynı günde iki kez önerilmez.
      final topicIds = result.blocks.map((b) => b.topicId).whereType<String>();
      expect(topicIds.toSet().length, topicIds.length,
          reason: 'aynı konu iki kez: $ctx');
    }
  });

  test('buildWeek: rastgele girdilerde çökmez, günlük süre aşılmaz', () {
    final rnd = Random(7);
    for (var iter = 0; iter < 500; iter++) {
      final subjects = [
        for (var i = 0; i < rnd.nextInt(10); i++)
          SubjectModel(
              id: 's$i',
              name: 'Ders $i',
              colorValue: 0xFF000000,
              createdAt: DateTime(2026, 1, 1)),
      ];
      final perDay = 15 + rnd.nextInt(480);
      final week = PlanBuilder.buildWeek(
        orderedSubjects: subjects,
        minutesPerDay: perDay,
        startDate: DateTime(2026, 9, 25),
        examDays: rnd.nextBool() ? rnd.nextInt(60) : null,
        uncoveredTopics: {
          for (final s in subjects)
            s.id: [for (var t = 0; t < rnd.nextInt(8); t++) (name: 'K$t', id: '${s.id}t$t')],
        },
        random: Random(iter),
      );
      for (final d in week.days) {
        final total = d.blocks.fold<int>(0, (s, b) => s + b.minutes);
        expect(total, lessThanOrEqualTo(perDay),
            reason: 'iter=$iter gün toplamı $total > $perDay');
      }
      // Hafta boyunca aynı konu birden çok kez önerilmez.
      final all = week.allBlocks.map((b) => b.topicId).whereType<String>();
      expect(all.toSet().length, all.length, reason: 'iter=$iter aynı konu tekrar');
    }
  });
}
