import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_planner/plan_builder.dart';
import 'package:study_planner/subject_model.dart';
import 'package:study_planner/task_model.dart';

SubjectModel _sub(String name) => SubjectModel(
      id: 'id-$name',
      name: name,
      colorValue: 0,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  final now = DateTime(2026, 9, 10, 9);
  final subjects = [_sub('Matematik'), _sub('Fizik'), _sub('Kimya')];

  test('ders yoksa boş sonuç', () {
    final r = PlanBuilder.build(
      orderedSubjects: const [],
      hoursAvailable: 3,
      energy: 'orta',
      now: now,
    );
    expect(r.isEmpty, isTrue);
  });

  test('orta enerji → 45 dk bloklar, ders başına bir görev', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      hoursAvailable: 3,
      energy: 'orta',
      now: now,
    );
    expect(r.blocks.length, 3);
    expect(r.blocks.every((b) => b.minutes == 45), isTrue);
    expect(r.plannedMinutes, 135);
  });

  test('kapasite dolunca kalanlar unfit', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      hoursAvailable: 1, // 60 dk → yalnız 1 blok (45 dk) sığar
      energy: 'orta',
      now: now,
    );
    expect(r.blocks.length, 1);
    expect(r.unfitTitles.length, 2);
  });

  test('bloklar ardışık zaman dilimlerine yerleşir', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      hoursAvailable: 3,
      energy: 'yüksek', // 60 dk
      now: now,
    );
    expect(r.blocks[0].startTime, now);
    expect(r.blocks[1].startTime, now.add(const Duration(minutes: 60)));
    expect(r.blocks[2].startTime, now.add(const Duration(minutes: 120)));
  });

  test('sınav <= 30 gün → tüm bloklar yüksek öncelik', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      hoursAvailable: 3,
      energy: 'orta',
      examDays: 12,
      now: now,
    );
    expect(r.blocks.every((b) => b.priority == TaskPriority.high), isTrue);
    expect(r.reason, contains('Sınava 12 gün'));
  });

  test('konu listesi → görev sayısı = konu sayısı, başlık "Ders: konu"', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      topics: const ['türev', 'integral', 'limit', 'polinom'],
      hoursAvailable: 8,
      energy: 'orta',
      now: now,
    );
    expect(r.blocks.length, 4);
    expect(r.blocks[0].title, 'Matematik: türev');
    expect(r.blocks[1].title, 'Fizik: integral');
  });

  test('tek ders seçilince yalnız o kullanılır', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      explicitSubject: _sub('Fizik'),
      hoursAvailable: 2,
      energy: 'orta',
      now: now,
    );
    expect(r.blocks.length, 1);
    expect(r.blocks.first.subjectId, 'id-Fizik');
  });

  test('uncoveredTopics + fillToCapacity → başlıklar boş konulardan, süreyi doldurur',
      () {
    final r = PlanBuilder.build(
      orderedSubjects: [_sub('Matematik')],
      uncoveredTopics: {
        'id-Matematik': ['Türev', 'İntegral', 'Limit'],
      },
      fillToCapacity: true,
      hoursAvailable: 3, // 180 dk / 45 = 4 blok
      energy: 'orta',
      now: now,
    );
    expect(r.blocks.length, 4);
    expect(r.blocks[0].title, 'Matematik: Türev');
    expect(r.blocks[1].title, 'Matematik: İntegral');
    expect(r.blocks[2].title, 'Matematik: Limit');
    // Konu havuzu bitince ders adına döner.
    expect(r.blocks[3].title, 'Matematik');
  });

  test('fillToCapacity yokken görev sayısı ders sayısıyla sınırlı', () {
    final r = PlanBuilder.build(
      orderedSubjects: [_sub('Matematik')],
      uncoveredTopics: {
        'id-Matematik': ['Türev', 'İntegral'],
      },
      hoursAvailable: 3,
      energy: 'orta',
      now: now,
    );
    expect(r.blocks.length, 1);
    expect(r.blocks.first.title, 'Matematik: Türev');
  });

  test('düşük enerji → 25 dk + ters sıra', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      hoursAvailable: 3,
      energy: 'düşük',
      now: now,
    );
    expect(r.blocks.every((b) => b.minutes == 25), isTrue);
    expect(r.blocks.first.subjectId, 'id-Kimya'); // ters
    expect(r.blocks.first.priority, TaskPriority.low);
  });

  test('sınav modu shuffle deterministik (seed)', () {
    PlanResult run() => PlanBuilder.build(
          orderedSubjects: subjects,
          hoursAvailable: 8,
          energy: 'orta',
          examDays: 5,
          now: now,
          random: Random(42),
        );
    expect(run().blocks.map((b) => b.subjectId).toList(),
        run().blocks.map((b) => b.subjectId).toList());
  });
}
