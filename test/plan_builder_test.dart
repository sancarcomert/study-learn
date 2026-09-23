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
  final subjects = [_sub('Matematik'), _sub('Fizik'), _sub('Kimya')];

  test('ders yoksa boş sonuç', () {
    final r = PlanBuilder.build(
      orderedSubjects: const [],
      capacityMinutes: 3 * 60,
      energy: 'orta',
    );
    expect(r.isEmpty, isTrue);
  });

  test('orta enerji → 45 dk bloklar, ders başına bir görev', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 3 * 60,
      energy: 'orta',
    );
    expect(r.blocks.length, 3);
    expect(r.blocks.every((b) => b.minutes == 45), isTrue);
    expect(r.plannedMinutes, 135);
  });

  test('kapasite dolunca kalanlar unfit', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 60, // 60 dk → yalnız 1 blok (45 dk) sığar
      energy: 'orta',
    );
    expect(r.blocks.length, 1);
    expect(r.unfitTitles.length, 2);
  });

  test('bloklara saat atanmaz, sıra order ile taşınır', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 3 * 60,
      energy: 'yüksek', // 60 dk
    );
    expect(r.blocks.map((b) => b.order).toList(), [0, 1, 2]);
  });

  test('sınav <= 30 gün → tüm bloklar yüksek öncelik', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 3 * 60,
      energy: 'orta',
      examDays: 12,
    );
    expect(r.blocks.every((b) => b.priority == TaskPriority.high), isTrue);
    expect(r.reason, contains('Sınava 12 gün'));
  });

  test('konu listesi → görev sayısı = konu sayısı, başlık "Ders: konu"', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      topics: const ['türev', 'integral', 'limit', 'polinom'],
      capacityMinutes: 8 * 60,
      energy: 'orta',
    );
    expect(r.blocks.length, 4);
    expect(r.blocks[0].title, 'Matematik: türev');
    expect(r.blocks[1].title, 'Fizik: integral');
  });

  test('tek ders seçilince yalnız o kullanılır', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      explicitSubject: _sub('Fizik'),
      capacityMinutes: 2 * 60,
      energy: 'orta',
    );
    expect(r.blocks.length, 1);
    expect(r.blocks.first.subjectId, 'id-Fizik');
  });

  test('uncoveredTopics + fillToCapacity → başlıklar boş konulardan, süreyi doldurur',
      () {
    final r = PlanBuilder.build(
      orderedSubjects: [_sub('Matematik')],
      uncoveredTopics: {
        'id-Matematik': [
          (name: 'Türev', id: 'topic-turev'),
          (name: 'İntegral', id: 'topic-integral'),
          (name: 'Limit', id: 'topic-limit'),
        ],
      },
      fillToCapacity: true,
      capacityMinutes: 3 * 60, // 180 dk / 45 = 4 blok
      energy: 'orta',
    );
    expect(r.blocks.length, 4);
    expect(r.blocks[0].title, 'Matematik: Türev');
    expect(r.blocks[0].topicId, 'topic-turev');
    expect(r.blocks[1].title, 'Matematik: İntegral');
    expect(r.blocks[2].title, 'Matematik: Limit');
    // Konu havuzu bitince ders adına döner, topicId yok.
    expect(r.blocks[3].title, 'Matematik');
    expect(r.blocks[3].topicId, isNull);
  });

  test('fillToCapacity yokken görev sayısı ders sayısıyla sınırlı', () {
    final r = PlanBuilder.build(
      orderedSubjects: [_sub('Matematik')],
      uncoveredTopics: {
        'id-Matematik': [
          (name: 'Türev', id: 'topic-turev'),
          (name: 'İntegral', id: 'topic-integral'),
        ],
      },
      capacityMinutes: 3 * 60,
      energy: 'orta',
    );
    expect(r.blocks.length, 1);
    expect(r.blocks.first.title, 'Matematik: Türev');
    expect(r.blocks.first.topicId, 'topic-turev');
  });

  test('düşük enerji → 25 dk + ters sıra', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 3 * 60,
      energy: 'düşük',
    );
    expect(r.blocks.every((b) => b.minutes == 25), isTrue);
    expect(r.blocks.first.subjectId, 'id-Kimya'); // ters
    expect(r.blocks.first.priority, TaskPriority.low);
  });

  test('reducedCapacitySubjectIds → o dersin bloğu küçülür, diğerleri aynı',
      () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 3 * 60,
      energy: 'orta', // 45 dk taban
      reducedCapacitySubjectIds: {'id-Fizik'},
    );
    final fizik = r.blocks.firstWhere((b) => b.subjectId == 'id-Fizik');
    final matematik = r.blocks.firstWhere((b) => b.subjectId == 'id-Matematik');
    expect(fizik.minutes, lessThan(45));
    expect(fizik.minutes, greaterThanOrEqualTo(15));
    expect(matematik.minutes, 45); // küçültme yalnız işaretli derse uygulanır
    expect(r.reason, contains('tamamlama oranın düşüktü'));
  });

  test('subjectCompletionRates → süre orana göre kademeli küçülür', () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 3 * 60,
      energy: 'orta', // 45 dk taban
      subjectCompletionRates: {'id-Fizik': 0.0, 'id-Kimya': 0.9},
    );
    final fizik = r.blocks.firstWhere((b) => b.subjectId == 'id-Fizik');
    final kimya = r.blocks.firstWhere((b) => b.subjectId == 'id-Kimya');
    final matematik = r.blocks.firstWhere((b) => b.subjectId == 'id-Matematik');
    expect(fizik.minutes, 23); // rate 0 → factor 0.5 → 45*0.5=22.5→round 23
    expect(kimya.minutes, 43); // rate 0.9 → factor 0.95 → 45*0.95=42.75→43
    expect(matematik.minutes, 45); // orana dahil değil → değişmez
  });

  test('subjectCompletionRates verilince ikili reducedCapacitySubjectIds görmezden gelinir',
      () {
    final r = PlanBuilder.build(
      orderedSubjects: subjects,
      capacityMinutes: 3 * 60,
      energy: 'orta',
      reducedCapacitySubjectIds: {'id-Fizik'},
      subjectCompletionRates: {'id-Fizik': 1.0},
    );
    final fizik = r.blocks.firstWhere((b) => b.subjectId == 'id-Fizik');
    expect(fizik.minutes, 45); // rate 1.0 → factor 1.0, ikili bayrağı ezer
  });

  test('examWeakTopics uncoveredTopics\'ten ÖNCE gelir, başlığa "(tekrar)" ekler',
      () {
    final r = PlanBuilder.build(
      orderedSubjects: [_sub('Matematik')],
      uncoveredTopics: {
        'id-Matematik': [(name: 'Limit', id: 'topic-limit')],
      },
      examWeakTopics: {
        'id-Matematik': [(name: 'Türev', id: 'topic-turev')],
      },
      fillToCapacity: true,
      capacityMinutes: 2 * 45,
      energy: 'orta',
    );
    expect(r.blocks[0].title, 'Matematik: Türev (tekrar)');
    expect(r.blocks[0].topicId, 'topic-turev');
    expect(r.blocks[0].difficulty, TopicDifficulty.hard);
    expect(r.blocks[1].title, 'Matematik: Limit');
    expect(r.blocks[1].difficulty, TopicDifficulty.medium);
    expect(r.reason, contains('Son denemende yanlış yaptığın'));
  });

  test('examWeakTopics verilmezse eski davranış/reason aynen korunur', () {
    final r = PlanBuilder.build(
      orderedSubjects: [_sub('Matematik')],
      capacityMinutes: 45,
      energy: 'orta',
    );
    expect(r.reason, isNot(contains('Son denemende')));
  });

  test('sınav modu shuffle deterministik (seed)', () {
    PlanResult run() => PlanBuilder.build(
          orderedSubjects: subjects,
          capacityMinutes: 8 * 60,
          energy: 'orta',
          examDays: 5,
          random: Random(42),
        );
    expect(run().blocks.map((b) => b.subjectId).toList(),
        run().blocks.map((b) => b.subjectId).toList());
  });

  group('buildWeek', () {
    final start = DateTime(2026, 9, 14); // Pazartesi

    test('7 gün, her gün dolu, tarihler ardışık', () {
      final w = PlanBuilder.buildWeek(
        orderedSubjects: subjects,
        minutesPerDay: 2 * 60,
        startDate: start,
      );
      expect(w.days.length, 7);
      expect(w.days.first.date, start);
      expect(w.days.last.date, start.add(const Duration(days: 6)));
      // 2 saat / 45 dk = 2 blok/gün
      expect(w.days.every((d) => d.blocks.length == 2), isTrue);
      expect(w.totalBlocks, 14);
    });

    test('odak her gün döner — ilk blok her gün farklı derse kayar', () {
      final w = PlanBuilder.buildWeek(
        orderedSubjects: subjects,
        minutesPerDay: 60,
        startDate: start,
        days: 3,
      );
      expect(w.days[0].blocks.first.subjectId, 'id-Matematik');
      expect(w.days[1].blocks.first.subjectId, 'id-Fizik');
      expect(w.days[2].blocks.first.subjectId, 'id-Kimya');
    });

    test('işaretlenmemiş konular hafta boyunca bir kez tüketilir', () {
      final w = PlanBuilder.buildWeek(
        orderedSubjects: [_sub('Matematik')],
        uncoveredTopics: {
          'id-Matematik': [
            (name: 'Türev', id: 'topic-turev'),
            (name: 'İntegral', id: 'topic-integral'),
            (name: 'Limit', id: 'topic-limit'),
          ],
        },
        minutesPerDay: 60,
        startDate: start,
        days: 5,
      );
      final titles = w.allBlocks.map((b) => b.title).toList();
      expect(titles.take(3).toList(),
          ['Matematik: Türev', 'Matematik: İntegral', 'Matematik: Limit']);
      // Konular bitince düz ders adına düşer, tekrar etmez.
      expect(titles.where((t) => t == 'Matematik: Türev').length, 1);
      expect(titles.skip(3).every((t) => t == 'Matematik'), isTrue);
    });

    test('sınav yakınsa öncelik yüksek + gerekçe', () {
      final w = PlanBuilder.buildWeek(
        orderedSubjects: subjects,
        minutesPerDay: 2 * 60,
        startDate: start,
        examDays: 12,
      );
      expect(w.allBlocks.every((b) => b.priority == TaskPriority.high), isTrue);
      expect(w.reason.contains('12 gün'), isTrue);
    });

    test('ders yoksa boş sonuç', () {
      final w = PlanBuilder.buildWeek(
        orderedSubjects: const [],
        minutesPerDay: 3 * 60,
        startDate: start,
      );
      expect(w.isEmpty, isTrue);
    });

    test('examWeakTopics uncoveredTopics\'ten ÖNCE gelir, "(tekrar)" eklenir',
        () {
      final w = PlanBuilder.buildWeek(
        orderedSubjects: [_sub('Matematik')],
        uncoveredTopics: {
          'id-Matematik': [(name: 'Limit', id: 'topic-limit')],
        },
        examWeakTopics: {
          'id-Matematik': [(name: 'Türev', id: 'topic-turev')],
        },
        minutesPerDay: 2 * 45,
        startDate: start,
        days: 1,
      );
      expect(w.allBlocks[0].title, 'Matematik: Türev (tekrar)');
      expect(w.allBlocks[0].difficulty, TopicDifficulty.hard);
      expect(w.allBlocks[1].title, 'Matematik: Limit');
      expect(w.allBlocks[1].difficulty, TopicDifficulty.medium);
      expect(w.reason, contains('Son denemende yanlış yaptığın'));
    });
  });
}
